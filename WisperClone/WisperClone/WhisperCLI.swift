import Foundation

/// Optional whisper.cpp subprocess on sliding-window WAV exports from [`PCMRingBuffer`].
final class WhisperCLIParser {
    private let settings: UserSettings
    private var timer: DispatchSourceTimer?
    private weak var ringRef: PCMRingBuffer?
    private let sampleRate: UInt32 = 16_000
    var onPartial: (String) -> Void = { _ in }

    init(settings: UserSettings) {
        self.settings = settings
    }

    func startSession(ring: PCMRingBuffer) {
        stopTimer()
        ringRef = ring
        let t = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInitiated))
        t.schedule(deadline: .now(), repeating: 0.6)
        t.setEventHandler { [weak self] in self?.tick() }
        timer = t
        t.resume()
    }

    func cancel() {
        stopTimer()
        ringRef = nil
    }

    func finalize(completion: @escaping (String) -> Void) {
        stopTimer()
        let text = runWhisperOnRing()
        ringRef = nil
        DispatchQueue.main.async {
            completion(text)
        }
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }

    private func tick() {
        let text = runWhisperOnRing()
        if !text.isEmpty {
            DispatchQueue.main.async {
                self.onPartial(text)
            }
        }
    }

    private func runWhisperOnRing() -> String {
        guard let ring = ringRef else { return "" }
        let exe = settings.whisperCLIPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = settings.whisperModelPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !exe.isEmpty, !model.isEmpty, FileManager.default.isExecutableFile(atPath: exe) else {
            return ""
        }

        let wav = ring.copyAsWAV(sampleRate: sampleRate)
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("wisper-whisper-\(UUID().uuidString).wav")
        do {
            try wav.write(to: tmp)
        } catch {
            return ""
        }
        defer { try? FileManager.default.removeItem(at: tmp) }

        let p = Process()
        p.executableURL = URL(fileURLWithPath: exe)
        let langId = UserDefaults.standard.string(forKey: "translateFromLanguageId") ?? "es"
        let whisperLang = TranscriptionLocale.whisperLanguageCode(for: langId)
        p.arguments = ["-m", model, "-f", tmp.path, "-l", whisperLang, "-nt", "-np"]
        let out = Pipe()
        let err = Pipe()
        p.standardOutput = out
        p.standardError = err
        do {
            try p.run()
            p.waitUntilExit()
        } catch {
            return ""
        }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        guard let s = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return ""
        }
        return s
    }
}
