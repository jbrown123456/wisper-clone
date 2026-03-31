import SwiftUI

struct MenuRootView: View {
    @ObservedObject var model: AppModel
    @State private var showSettings = false
    @State private var apiKeyDraft = ""

    var body: some View {
        Group {
            Button(model.isEnabled ? "Disable capture" : "Enable capture") {
                model.setEnabled(!model.isEnabled)
            }

            Divider()

            Label("Microphone", systemImage: model.microphoneAuthorized ? "checkmark.circle.fill" : "mic.slash")
            if !model.microphoneAuthorized {
                Button("Allow microphone…") { model.requestMicrophone() }
                Button("Open Microphone privacy") { model.openMicrophoneSettings() }
            }

            if !model.settings.useWhisperCLI {
                Label("Speech (Spanish)", systemImage: model.speechAuthorized ? "checkmark.circle.fill" : "text.bubble")
                if !model.speechAuthorized {
                    Button("Allow speech recognition…") { model.requestSpeech() }
                }
            }

            Label("Accessibility", systemImage: model.accessibilityTrusted ? "checkmark.circle.fill" : "hand.raised")

            if !model.accessibilityTrusted {
                Button("Open Accessibility settings") { model.openAccessibilitySettings() }
            }

        Button("Test paste at caret") { model.runInjectionSelfTest() }

        Button("Test streaming LLM…") { model.runLLMSelfTest() }

        Divider()

            Button("Settings…") { showSettings = true }

            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q", modifiers: .command)
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(model: model, apiKeyDraft: $apiKeyDraft)
        }
        .onAppear {
            apiKeyDraft = model.keychain.readAPIKey() ?? ""
            model.refreshPermissions()
        }
    }
}

struct SettingsSheet: View {
    @ObservedObject var model: AppModel
    @Binding var apiKeyDraft: String
    @Environment(\.dismiss) private var dismiss

    @State private var baseURL = ""
    @State private var openaiModel = ""
    @State private var debounceMs = ""
    @State private var whisperPath = ""
    @State private var whisperModel = ""
    @State private var useWhisper = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings").font(.title2.bold())

            Toggle("Use whisper.cpp CLI (otherwise Apple Speech, Spanish)", isOn: $useWhisper)

            TextField("OpenAI API base URL", text: $baseURL)
            TextField("Model", text: $openaiModel)
            SecureField("API key (stored in Keychain)", text: $apiKeyDraft)
            TextField("Orchestrator debounce (ms)", text: $debounceMs)

            TextField("Whisper CLI path", text: $whisperPath)
            TextField("Whisper GGML model path", text: $whisperModel)

            HStack {
                Button("Save") { save() }
                Button("Cancel") { dismiss() }
            }
        }
        .padding(20)
        .frame(minWidth: 420)
        .onAppear {
            baseURL = model.settings.openAIBaseURL
            openaiModel = model.settings.modelName
            debounceMs = String(model.settings.orchestratorDebounceMs)
            whisperPath = model.settings.whisperCLIPath
            whisperModel = model.settings.whisperModelPath
            useWhisper = model.settings.useWhisperCLI
        }
    }

    private func save() {
        model.settings.openAIBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        model.settings.modelName = openaiModel.trimmingCharacters(in: .whitespacesAndNewlines)
        if let d = Int(debounceMs.trimmingCharacters(in: .whitespacesAndNewlines)), d > 0 {
            model.settings.orchestratorDebounceMs = d
        }
        model.settings.whisperCLIPath = whisperPath.trimmingCharacters(in: .whitespacesAndNewlines)
        model.settings.whisperModelPath = whisperModel.trimmingCharacters(in: .whitespacesAndNewlines)
        model.settings.useWhisperCLI = useWhisper
        let key = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty {
            try? model.keychain.saveAPIKey(key)
        }
        dismiss()
    }
}
