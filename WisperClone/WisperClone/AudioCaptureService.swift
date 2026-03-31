import AVFoundation
import Foundation

final class AudioCaptureService: NSObject {
    private let engine = AVAudioEngine()
    private let targetFormat: AVAudioFormat
    private var converter: AVAudioConverter?

    /// Batches ~320ms of mono Int16 @ 16 kHz (plan: 250–400ms chunks for ring / metrics).
    private var pcmChunkScratch = Data()
    private let chunkByteSize: Int

    /// Mono Int16 PCM at 16 kHz for ring + whisper (batched).
    var onMonoPCM16: ((Data) -> Void)?

    /// Buffers for Speech framework (16 kHz mono PCM).
    var onBufferForSpeech: ((AVAudioPCMBuffer) -> Void)?

    private(set) var isRunning = false

    override init() {
        self.targetFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: true)!
        let frames = Int((320.0 / 1000.0) * 16_000)
        self.chunkByteSize = frames * MemoryLayout<Int16>.size
        super.init()
    }

    func start() throws {
        let input = engine.inputNode
        let hwFormat = input.outputFormat(forBus: 0)

        guard let conv = AVAudioConverter(from: hwFormat, to: targetFormat) else {
            throw NSError(domain: "WisperClone", code: 2, userInfo: [NSLocalizedDescriptionKey: "Audio format conversion unsupported"])
        }
        converter = conv

        input.removeTap(onBus: 0)
        let bufferSize: AVAudioFrameCount = 4096
        input.installTap(onBus: 0, bufferSize: bufferSize, format: hwFormat) { [weak self] buffer, _ in
            self?.process(buffer: buffer)
        }

        engine.prepare()
        try engine.start()
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
        if !pcmChunkScratch.isEmpty {
            onMonoPCM16?(pcmChunkScratch)
            pcmChunkScratch.removeAll(keepingCapacity: true)
        }
    }

    private func process(buffer: AVAudioPCMBuffer) {
        guard let converter else { return }

        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let outFrames = AVAudioFrameCount(ceil(Double(buffer.frameLength) * ratio)) + 32
        guard let out = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outFrames) else { return }

        var error: NSError?
        var fed = false
        let status = converter.convert(to: out, error: &error) { _, outStatus in
            if fed {
                outStatus.pointee = .noDataNow
                return nil
            }
            fed = true
            outStatus.pointee = .haveData
            return buffer
        }

        if status == .error || error != nil {
            if let error { NSLog("AudioCaptureService: \(error)") }
            return
        }

        guard let ch0 = out.int16ChannelData else { return }
        let n = Int(out.frameLength)
        let byteCount = n * MemoryLayout<Int16>.size
        let data = Data(bytes: ch0[0], count: byteCount)
        emitChunkedMono(data)

        if let copy = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: out.frameCapacity) {
            copy.frameLength = out.frameLength
            memcpy(copy.int16ChannelData![0], ch0[0], byteCount)
            onBufferForSpeech?(copy)
        }
    }

    private func emitChunkedMono(_ data: Data) {
        pcmChunkScratch.append(data)
        while pcmChunkScratch.count >= chunkByteSize {
            let piece = pcmChunkScratch.prefix(chunkByteSize)
            onMonoPCM16?(Data(piece))
            pcmChunkScratch.removeSubrange(0 ..< chunkByteSize)
        }
    }
}
