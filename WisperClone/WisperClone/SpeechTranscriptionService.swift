import AVFoundation
import Foundation
import Speech

final class SpeechTranscriptionService {
    static let spanishLocale = Locale(identifier: "es-ES")

    static var authorizationStatus: SFSpeechRecognizerAuthorizationStatus {
        SFSpeechRecognizer.authorizationStatus()
    }

    static func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                completion(status == .authorized)
            }
        }
    }

    private let recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var lastReported = ""

    var onPartial: (String) -> Void = { _ in }

    init(locale: Locale) {
        recognizer = SFSpeechRecognizer(locale: locale)
    }

    func cancel() {
        task?.cancel()
        task = nil
        request?.endAudio()
        request = nil
        lastReported = ""
    }

    @discardableResult
    func start(with audio: AudioCaptureService) -> Bool {
        cancel()
        guard let rec = recognizer, rec.isAvailable else { return false }

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        request = req

        audio.onBufferForSpeech = { [weak self] buffer in
            self?.request?.append(buffer)
        }

        task = rec.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            if error != nil {
                return
            }
            guard let result else { return }
            let text = result.bestTranscription.formattedString
            DispatchQueue.main.async {
                if text != self.lastReported {
                    self.lastReported = text
                    self.onPartial(text)
                }
            }
        }
        return true
    }

    func stop() -> String {
        let out = lastReported
        request?.endAudio()
        request = nil
        task?.cancel()
        task = nil
        lastReported = ""
        return out
    }
}
