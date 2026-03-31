import Foundation

/// Keeps the last N seconds of mono Int16 PCM at a fixed sample rate.
final class PCMRingBuffer {
    private let maxSamples: Int
    private let queue = DispatchQueue(label: "com.wisperclone.ring")
    private var storage: [Int16]

    init(maxSeconds: Double, sampleRate: Double) {
        self.maxSamples = max(1, Int(maxSeconds * sampleRate))
        self.storage = []
        self.storage.reserveCapacity(maxSamples)
    }

    func appendMonoPCM16(_ data: Data) {
        queue.sync {
            let count = data.count / MemoryLayout<Int16>.stride
            data.withUnsafeBytes { raw in
                guard let base = raw.bindMemory(to: Int16.self).baseAddress else { return }
                for i in 0 ..< count {
                    let s = Int16(littleEndian: base[i])
                    if storage.count >= maxSamples {
                        storage.removeFirst()
                    }
                    storage.append(s)
                }
            }
        }
    }

    /// Copies current window to WAV (PCM s16le mono).
    func copyAsWAV(sampleRate: UInt32) -> Data {
        queue.sync {
            var d = Data()
            d.reserveCapacity(44 + storage.count * 2)
            let byteCount = UInt32(storage.count * 2)
            let channels: UInt16 = 1
            let bits: UInt16 = 16

            func appendU32LE(_ v: UInt32) {
                var v = v.littleEndian
                withUnsafeBytes(of: &v) { d.append(contentsOf: $0) }
            }
            func appendU16LE(_ v: UInt16) {
                var v = v.littleEndian
                withUnsafeBytes(of: &v) { d.append(contentsOf: $0) }
            }

            d.append(contentsOf: "RIFF".utf8)
            appendU32LE(36 + byteCount)
            d.append(contentsOf: "WAVE".utf8)
            d.append(contentsOf: "fmt ".utf8)
            appendU32LE(16)
            appendU16LE(1)
            appendU16LE(channels)
            appendU32LE(sampleRate)
            appendU32LE(sampleRate * UInt32(channels) * UInt32(bits) / 8)
            appendU16LE(channels * bits / 8)
            appendU16LE(bits)
            d.append(contentsOf: "data".utf8)
            appendU32LE(byteCount)
            storage.withUnsafeBufferPointer { buf in
                for s in buf {
                    var s = s.littleEndian
                    withUnsafeBytes(of: &s) { d.append(contentsOf: $0) }
                }
            }
            return d
        }
    }

    func clear() {
        queue.sync { storage.removeAll(keepingCapacity: true) }
    }
}
