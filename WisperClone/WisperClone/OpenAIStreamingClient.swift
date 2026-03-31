import Foundation

enum OpenAIStreamError: Error, Equatable {
    case missingAPIKey
    case badStatus(Int)
    case cancelled
}

/// OpenAI Chat Completions with `stream: true` (SSE).
final class OpenAIStreamSession: NSObject, URLSessionDataDelegate {
    static let rewriteSystemPrompt =
        "Rewrite input into concise, professional English. If technical intent is detected, structure it as an engineering task or prompt."

    private let onDelta: (String) -> Void
    private let onComplete: (Result<Void, Error>) -> Void
    private var remainder = ""
    private var completed = false
    private lazy var urlSession: URLSession = {
        URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }()

    private var dataTask: URLSessionDataTask?

    init(onDelta: @escaping (String) -> Void, onComplete: @escaping (Result<Void, Error>) -> Void) {
        self.onDelta = onDelta
        self.onComplete = onComplete
        super.init()
    }

    func start(
        baseURL: String,
        apiKey: String,
        model: String,
        userMessage: String,
        systemPrompt: String,
        maxTokens: Int?,
    ) {
        let urlBase = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: urlBase + "/chat/completions") else {
            finish(.failure(OpenAIStreamError.badStatus(0)))
            return
        }

        var body: [String: Any] = [
            "model": model,
            "stream": true,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userMessage],
            ],
        ]
        if let maxTokens {
            body["max_tokens"] = maxTokens
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let t = urlSession.dataTask(with: req)
        dataTask = t
        t.resume()
    }

    func cancel() {
        dataTask?.cancel()
    }

    private func finish(_ r: Result<Void, Error>) {
        if completed { return }
        completed = true
        dataTask = nil
        urlSession.finishTasksAndInvalidate()
        onComplete(r)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if let http = response as? HTTPURLResponse {
            if http.statusCode >= 400 {
                finish(.failure(OpenAIStreamError.badStatus(http.statusCode)))
                completionHandler(.cancel)
                return
            }
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if completed { return }
        guard let chunk = String(data: data, encoding: .utf8) else { return }
        remainder += chunk
        while let range = remainder.range(of: "\n") {
            let raw = String(remainder[..<range.lowerBound])
            remainder.removeSubrange(..<range.upperBound)
            let line = raw.trimmingCharacters(in: .whitespaces)
            parseSSE(line)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if completed { return }
        if let error {
            let ns = error as NSError
            if ns.domain == NSURLErrorDomain, ns.code == NSURLErrorCancelled {
                finish(.failure(OpenAIStreamError.cancelled))
            } else {
                finish(.failure(error))
            }
            return
        }
        finish(.success(()))
    }

    private func parseSSE(_ line: String) {
        guard line.hasPrefix("data: ") else { return }
        let payload = String(line.dropFirst(6))
        if payload == "[DONE]" { return }
        guard let d = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let delta = first["delta"] as? [String: Any],
              let content = delta["content"] as? String,
              !content.isEmpty
        else { return }
        onDelta(content)
    }
}
