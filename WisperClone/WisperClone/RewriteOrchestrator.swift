import Foundation

/// Debounced partial LLM streams while speaking; `rewriteFinal` runs one terminal stream.
final class RewriteOrchestrator: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.wisperclone.rewrite", qos: .userInitiated)
    private var debounceItem: DispatchWorkItem?
    private var active: OpenAIStreamSession?
    private var partialGen = 0

    var onPartialEnglish: (String) -> Void = { _ in }
    /// Step 14: surface non-cancel failures (debounce cancels look like errors to URLSession).
    var onStreamError: ((String) -> Void)?

    func prepareClient(settings _: UserSettings, keychain _: KeychainStore) async {}

    func cancelAll() {
        queue.async { [weak self] in
            self?.debounceItem?.cancel()
            self?.debounceItem = nil
            self?.active?.cancel()
            self?.active = nil
        }
    }

    /// Partial transcript updates while user holds push-to-talk.
    func submitPartialTranscript(_ text: String, settings: UserSettings, keychain: KeychainStore) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        queue.async { [weak self] in
            guard let self else { return }
            guard let apiKey = keychain.readAPIKey(), !apiKey.isEmpty else { return }

            debounceItem?.cancel()
            partialGen += 1
            let gen = partialGen
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                guard gen == self.partialGen else { return }
                self.launchStream(apiKey: apiKey, spanish: trimmed, partial: true, settings: settings) { _ in }
            }
            debounceItem = work
            queue.asyncAfter(deadline: .now() + .milliseconds(settings.orchestratorDebounceMs), execute: work)
        }
    }

    /// Single blocking (async) final rewrite for injection.
    func rewriteFinal(_ spanish: String, settings: UserSettings, keychain: KeychainStore) async -> String {
        let trimmed = spanish.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        return await withCheckedContinuation { cont in
            queue.async { [weak self] in
                guard let self else {
                    cont.resume(returning: "")
                    return
                }
                guard let apiKey = keychain.readAPIKey(), !apiKey.isEmpty else {
                    cont.resume(returning: "")
                    return
                }

                debounceItem?.cancel()
                debounceItem = nil
                active?.cancel()
                active = nil
                partialGen += 1

                launchStream(apiKey: apiKey, spanish: trimmed, partial: false, settings: settings) { out in
                    cont.resume(returning: out)
                }
            }
        }
    }

    private func launchStream(
        apiKey: String,
        spanish: String,
        partial: Bool,
        settings: UserSettings,
        done: @escaping (String) -> Void,
    ) {
        active?.cancel()
        active = nil

        let userMsg =
            partial
            ? "(partial transcript; output only the current best rewrite, no preamble)\n\(spanish)"
            : spanish

        var accumulated = ""

        let session = OpenAIStreamSession(
            onDelta: { delta in
                accumulated += delta
                let snap = accumulated
                DispatchQueue.main.async {
                    self.onPartialEnglish(snap)
                }
            },
            onComplete: { [weak self] result in
                self?.queue.async {
                    guard let self else { return }
                    self.active = nil
                    switch result {
                    case .success:
                        done(accumulated)
                    case let .failure(err):
                        if !self.isCancellation(err) {
                            DispatchQueue.main.async {
                                self.onStreamError?("LLM: \(err.localizedDescription)")
                            }
                        }
                        done(accumulated)
                    }
                }
            },
        )

        active = session
        session.start(
            baseURL: settings.openAIBaseURL,
            apiKey: apiKey,
            model: settings.modelName,
            userMessage: userMsg,
            systemPrompt: OpenAIStreamSession.rewriteSystemPrompt,
            maxTokens: partial ? settings.partialMaxTokens : 512,
        )
    }

    private func isCancellation(_ error: Error) -> Bool {
        if case OpenAIStreamError.cancelled = error { return true }
        let ns = error as NSError
        return ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled
    }
}
