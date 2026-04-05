import Foundation

/// User-facing product identity. Change values here to rebrand without hunting the codebase.
enum Brand {
    static let displayName = "Klari"
    static let tagline = "Think in your language. Ship in English."
    /// Shown next to the sidebar logo (edition / tier label).
    static let editionLabel = "Solo"

    static var microphoneUsageDescription: String {
        "\(displayName) captures your voice to transcribe and rewrite it in English."
    }

    static var speechRecognitionUsageDescription: String {
        "\(displayName) uses speech recognition for live Spanish transcription when whisper.cpp is not enabled."
    }
}
