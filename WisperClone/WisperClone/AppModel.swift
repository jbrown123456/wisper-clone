import AppKit
import Foundation
import os.log

private let latencyLog = Logger(subsystem: "com.wisperclone.WisperClone", category: "latency")

enum SessionPhase: String, Sendable {
    case idle
    case listening
    case processing
    case outputting
}

@MainActor
final class AppModel: ObservableObject {
    @Published var isEnabled = true
    @Published var sessionPhase: SessionPhase = .idle
    @Published var liveTranscript = ""
    @Published var liveEnglish = ""
    @Published var microphoneAuthorized = false
    @Published var speechAuthorized = false
    @Published var accessibilityTrusted = false
    @Published var lastError: String?

    let keychain = KeychainStore(service: "com.wisperclone.WisperClone")
    let settings = UserSettings()

    private let hotkey = HotkeyMonitor(defaultKeyCode: HotkeyMonitor.defaultPushToTalkKeyCode)
    private var audio: AudioCaptureService?
    private let ring = PCMRingBuffer(maxSeconds: 2.5, sampleRate: 16_000)
    private var speechTranscriber: SpeechTranscriptionService?
    private var whisperRunner: WhisperCLIParser?

    private let orchestrator = RewriteOrchestrator()
    private var llmSelfTestSession: OpenAIStreamSession?

    private var sessionBeganAt: Date?
    private var firstTranscriptAt: Date?
    private var firstTokenAt: Date?
    private var finalizeStartedAt: Date?

    init() {
        orchestrator.onPartialEnglish = { [weak self] text in
            Task { @MainActor in
                self?.onEnglishDelta(text)
            }
        }
        orchestrator.onStreamError = { [weak self] msg in
            Task { @MainActor in
                guard let self else { return }
                self.lastError = msg
                OverlayController.shared.update(
                    native: self.liveTranscript,
                    english: self.liveEnglish,
                    phase: self.sessionPhase,
                    error: msg,
                )
            }
        }
        hotkey.onSessionBegan = { [weak self] in
            Task { @MainActor in self?.handleSessionBegan() }
        }
        hotkey.onSessionFinalized = { [weak self] in
            Task { @MainActor in self?.handleSessionFinalized() }
        }

        refreshPermissions()
        if isEnabled { hotkey.start() }
        whisperRunner = WhisperCLIParser(settings: settings)
        whisperRunner?.onPartial = { [weak self] text in
            Task { @MainActor in self?.handleTranscript(text, partial: true) }
        }
        Task { await orchestrator.prepareClient(settings: settings, keychain: keychain) }
    }

    func refreshPermissions() {
        microphoneAuthorized = MicPermission.status == .authorized
        speechAuthorized = SpeechTranscriptionService.authorizationStatus == .authorized
        accessibilityTrusted = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary,
        )
    }

    func setEnabled(_ on: Bool) {
        isEnabled = on
        if on {
            hotkey.start()
        } else {
            hotkey.stop()
            if sessionPhase != .idle {
                Task { await abortSession() }
            }
        }
    }

    private func handleSessionBegan() {
        guard isEnabled else { return }
        guard sessionPhase == .idle else { return }
        guard microphoneAuthorized else {
            lastError = "Microphone not authorized"
            return
        }

        sessionBeganAt = Date()
        firstTranscriptAt = nil
        firstTokenAt = nil
        liveTranscript = ""
        liveEnglish = ""
        lastError = nil
        sessionPhase = .listening
        OverlayController.shared.show()
        OverlayController.shared.update(native: "", english: "", phase: sessionPhase, error: nil)

        ring.clear()

        let engine = AudioCaptureService()
        audio = engine
        engine.onMonoPCM16 = { [weak self] data in
            self?.ring.appendMonoPCM16(data)
        }

        do {
            try engine.start()
        } catch {
            lastError = error.localizedDescription
            sessionPhase = .idle
            OverlayController.shared.hide()
            return
        }

        if settings.useWhisperCLI,
           !settings.whisperCLIPath.isEmpty,
           !settings.whisperModelPath.isEmpty
        {
            speechTranscriber = nil
            whisperRunner?.startSession(ring: ring)
        } else {
            let langId = UserDefaults.standard.string(forKey: "translateFromLanguageId") ?? "es"
            let speech = SpeechTranscriptionService(locale: TranscriptionLocale.speechLocale(for: langId))
            speechTranscriber = speech
            speech.onPartial = { [weak self] text in
                Task { @MainActor in self?.handleTranscript(text, partial: true) }
            }
            if !speech.start(with: engine) {
                lastError = "Speech recognition is not available for “\(langId)”. Try another language or enable whisper.cpp in Settings."
                speechTranscriber = nil
                engine.stop()
                audio = nil
                sessionPhase = .idle
                OverlayController.shared.hide()
            }
        }
    }

    private func handleTranscript(_ text: String, partial: Bool) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if firstTranscriptAt == nil { firstTranscriptAt = Date() }
        liveTranscript = trimmed
        OverlayController.shared.update(native: trimmed, english: liveEnglish, phase: sessionPhase, error: nil)
        sessionPhase = partial ? .listening : .outputting
        orchestrator.submitPartialTranscript(trimmed, settings: settings, keychain: keychain)
    }

    private func onEnglishDelta(_ fullText: String) {
        if firstTokenAt == nil, !fullText.isEmpty { firstTokenAt = Date() }
        liveEnglish = fullText
        sessionPhase = .outputting
        OverlayController.shared.update(native: liveTranscript, english: fullText, phase: .outputting, error: nil)

        if let t0 = firstTranscriptAt, let t1 = firstTokenAt {
            latencyLog.info("first_token_ms=\(Int(t1.timeIntervalSince(t0) * 1000))")
        }
    }

    private func handleSessionFinalized() {
        guard sessionPhase != .idle || audio != nil else { return }
        finalizeStartedAt = Date()

        audio?.stop()
        audio = nil

        Task { await finalizePipeline() }
    }

    private func finalizePipeline() async {
        let spanish: String
        if let speech = speechTranscriber {
            spanish = speech.stop().trimmingCharacters(in: .whitespacesAndNewlines)
            speechTranscriber = nil
        } else if settings.useWhisperCLI {
            spanish = await withCheckedContinuation { (cont: CheckedContinuation<String, Never>) in
                guard let whisperRunner else {
                    cont.resume(returning: "")
                    return
                }
                whisperRunner.finalize { text in
                    cont.resume(returning: text.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        } else {
            spanish = ""
        }

        if !spanish.isEmpty {
            liveTranscript = spanish
            OverlayController.shared.update(native: spanish, english: liveEnglish, phase: .processing, error: nil)
        }

        orchestrator.cancelAll()

        let english: String
        if spanish.isEmpty {
            english = liveEnglish.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            english = await orchestrator.rewriteFinal(spanish, settings: settings, keychain: keychain)
            if !english.isEmpty {
                liveEnglish = english
                OverlayController.shared.update(native: spanish, english: english, phase: .outputting, error: nil)
            }
        }

        finishInjection(english: english)
    }

    private func finishInjection(english: String) {
        let toInsert = english.trimmingCharacters(in: .whitespacesAndNewlines)
        if !toInsert.isEmpty {
            let ok = TextInjector.insertAtFocusedElement(toInsert)
            if !ok {
                let err = "Could not insert text — enable Accessibility for WisperClone"
                lastError = err
                OverlayController.shared.update(
                    native: liveTranscript,
                    english: liveEnglish,
                    phase: .outputting,
                    error: err,
                )
            }
        }
        if let t0 = finalizeStartedAt {
            latencyLog.info("finalize_to_inject_ms=\(Int(Date().timeIntervalSince(t0) * 1000))")
        }

        sessionPhase = .idle
        liveTranscript = ""
        liveEnglish = ""
        OverlayController.shared.update(native: "", english: "", phase: .idle, error: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            OverlayController.shared.hide()
        }
    }

    private func abortSession() async {
        audio?.stop()
        audio = nil
        speechTranscriber?.cancel()
        speechTranscriber = nil
        whisperRunner?.cancel()
        orchestrator.cancelAll()
        sessionPhase = .idle
        OverlayController.shared.hide()
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    func requestMicrophone() {
        MicPermission.request { [weak self] granted in
            Task { @MainActor in
                self?.microphoneAuthorized = granted
            }
        }
    }

    func requestSpeech() {
        SpeechTranscriptionService.requestAuthorization { [weak self] ok in
            Task { @MainActor in
                self?.speechAuthorized = ok
            }
        }
    }

    func runInjectionSelfTest() {
        let ok = TextInjector.insertAtFocusedElement("[Wisper test injection]\n")
        lastError = ok ? nil : "Injection failed — enable Accessibility for WisperClone"
    }

    /// Step 9: isolated streaming client check (fixed Spanish prompt → English rewrite in overlay).
    func runLLMSelfTest() {
        guard let key = keychain.readAPIKey(), !key.isEmpty else {
            lastError = "Set API key in Settings"
            return
        }
        llmSelfTestSession?.cancel()
        OverlayController.shared.show()
        OverlayController.shared.update(
            native: "Self-test: Spanish sample",
            english: "",
            phase: .processing,
            error: nil,
        )
        var acc = ""
        let session = OpenAIStreamSession(
            onDelta: { delta in
                acc += delta
                let snap = acc
                Task { @MainActor in
                    OverlayController.shared.update(
                        native: "hola esto es una prueba técnica",
                        english: snap,
                        phase: .outputting,
                        error: nil,
                    )
                }
            },
            onComplete: { [weak self] result in
                Task { @MainActor in
                    self?.llmSelfTestSession = nil
                    if case let .failure(err) = result {
                        if err as? OpenAIStreamError == .cancelled { return }
                        let ns = err as NSError
                        if ns.domain == NSURLErrorDomain, ns.code == NSURLErrorCancelled { return }
                        let msg = "LLM self-test: \(err.localizedDescription)"
                        self?.lastError = msg
                        OverlayController.shared.update(
                            native: "hola esto es una prueba técnica",
                            english: acc,
                            phase: .outputting,
                            error: msg,
                        )
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        OverlayController.shared.hide()
                    }
                }
            },
        )
        llmSelfTestSession = session
        session.start(
            baseURL: settings.openAIBaseURL,
            apiKey: key,
            model: settings.modelName,
            userMessage: "hola esto es una prueba técnica",
            systemPrompt: OpenAIStreamSession.rewriteSystemPrompt,
            maxTokens: 128,
        )
    }
}
