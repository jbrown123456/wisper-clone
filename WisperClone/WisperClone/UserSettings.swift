import Foundation

/// `UserDefaults` keys (no secrets). API key lives in Keychain only.
final class UserSettings {
    private let defaults = UserDefaults.standard

    var openAIBaseURL: String {
        get { defaults.string(forKey: "openai_base_url") ?? "https://api.openai.com/v1" }
        set { defaults.set(newValue, forKey: "openai_base_url") }
    }

    var modelName: String {
        get { defaults.string(forKey: "openai_model") ?? "gpt-4o-mini" }
        set { defaults.set(newValue, forKey: "openai_model") }
    }

    /// Full path to whisper.cpp-compatible binary (optional).
    var whisperCLIPath: String {
        get { defaults.string(forKey: "whisper_cli_path") ?? "" }
        set { defaults.set(newValue, forKey: "whisper_cli_path") }
    }

    /// Path to GGML model file.
    var whisperModelPath: String {
        get { defaults.string(forKey: "whisper_model_path") ?? "" }
        set { defaults.set(newValue, forKey: "whisper_model_path") }
    }

    var useWhisperCLI: Bool {
        get { defaults.bool(forKey: "use_whisper_cli") }
        set { defaults.set(newValue, forKey: "use_whisper_cli") }
    }

    /// Latency / UX tuning (milliseconds).
    var orchestratorDebounceMs: Int {
        get {
            let v = defaults.integer(forKey: "orch_debounce_ms")
            return v > 0 ? v : 150
        }
        set { defaults.set(newValue, forKey: "orch_debounce_ms") }
    }

    var partialMaxTokens: Int {
        get {
            let v = defaults.integer(forKey: "partial_max_tokens")
            return v > 0 ? v : 128
        }
        set { defaults.set(newValue, forKey: "partial_max_tokens") }
    }

    /// Floating on-screen dictation control (hold-to-talk pill).
    var showFloatingControl: Bool {
        get {
            if defaults.object(forKey: "show_floating_control") == nil { return true }
            return defaults.bool(forKey: "show_floating_control")
        }
        set { defaults.set(newValue, forKey: "show_floating_control") }
    }
}
