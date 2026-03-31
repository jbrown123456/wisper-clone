import AppKit
import SwiftUI

// MARK: - Placeholder sections (trimmed scope)

struct DictionaryView: View {
    var body: some View {
        PlaceholderPage(
            title: "Dictionary",
            subtitle: "Save and reuse word definitions. Coming in a future build.",
            icon: "book.fill",
        )
    }
}

struct SnippetsView: View {
    var body: some View {
        PlaceholderPage(
            title: "Snippets",
            subtitle: "Short text snippets you can paste anywhere. Not wired up yet.",
            icon: "text.badge.plus",
        )
    }
}

struct ScratchPadView: View {
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Scratch Pad")
                .font(.largeTitle.weight(.bold))
            Text("A simple scratch area. Not synced.")
                .foregroundStyle(.secondary)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .textBackgroundColor))
                if text.isEmpty {
                    Text("Jot notes here…")
                        .foregroundStyle(.tertiary)
                        .padding(14)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .font(.body)
                    .focused($focused)
                    .frame(minHeight: 220)
                    .padding(4)
                    .scrollContentBackground(.hidden)
            }
            Spacer(minLength: 0)
        }
        .onAppear { focused = true }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct InviteTeamView: View {
    var body: some View {
        PlaceholderPage(
            title: "Invite your team",
            subtitle: "Share seats with teammates. This build is local-only — no accounts yet.",
            icon: "person.3.fill",
            primaryActionTitle: "Copy placeholder link",
        ) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(
                "https://example.com/invite",
                forType: NSPasteboard.PasteboardType.string,
            )
            NSSound.beep()
        }
    }
}

struct PromoMonthFreeView: View {
    var body: some View {
        PlaceholderPage(
            title: "Get a month free",
            subtitle: "Referral and trial flows go here. Placeholder for now.",
            icon: "gift.fill",
            primaryActionTitle: "Notify me",
        ) {
            NSSound.beep()
        }
    }
}

struct HelpView: View {
    var body: some View {
        PlaceholderPage(
            title: "Help",
            subtitle: "Documentation and support will live here. For now: use Home to set your source language; Settings for API and voice options.",
            icon: "questionmark.circle.fill",
        )
    }
}

struct PlaceholderPage: View {
    let title: String
    let subtitle: String
    let icon: String
    var primaryActionTitle: String?
    var primaryAction: (() -> Void)?

    init(
        title: String,
        subtitle: String,
        icon: String,
        primaryActionTitle: String? = nil,
        primaryAction: (() -> Void)? = nil,
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.primaryActionTitle = primaryActionTitle
        self.primaryAction = primaryAction
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.largeTitle.weight(.bold))
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let primaryActionTitle, let primaryAction {
                Button(primaryActionTitle) {
                    primaryAction()
                }
                .buttonStyle(.borderedProminent)
            }
            Spacer(minLength: 0)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Settings (desktop layout)

struct DesktopSettingsView: View {
    @ObservedObject var model: AppModel
    @State private var apiKeyDraft = ""

    @State private var baseURL = ""
    @State private var openaiModel = ""
    @State private var debounceMs = ""
    @State private var whisperPath = ""
    @State private var whisperModel = ""
    @State private var useWhisper = false
    @State private var saveBanner = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Settings")
                    .font(.largeTitle.weight(.bold))

                Text("Voice, API, and advanced transcription options from the earlier Wisper build.")
                    .foregroundStyle(.secondary)

                if !saveBanner.isEmpty {
                    Text(saveBanner)
                        .font(.callout)
                        .foregroundStyle(.green)
                }

                GroupBox("OpenAI rewrite") {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("API base URL", text: $baseURL)
                        TextField("Model", text: $openaiModel)
                        SecureField("API key (Keychain)", text: $apiKeyDraft)
                        TextField("Orchestrator debounce (ms)", text: $debounceMs)
                    }
                    .padding(.vertical, 6)
                }

                GroupBox("Local transcription") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Use whisper.cpp CLI (otherwise on-device Speech)", isOn: $useWhisper)
                        TextField("Whisper CLI path", text: $whisperPath)
                        TextField("Whisper GGML model path", text: $whisperModel)
                    }
                    .padding(.vertical, 6)
                }

                GroupBox("Permissions & tests") {
                    VStack(alignment: .leading, spacing: 8) {
                        Button("Refresh permission status") { model.refreshPermissions() }
                        Button("Open Accessibility…") { model.openAccessibilitySettings() }
                        Button("Open Microphone…") { model.openMicrophoneSettings() }
                        Button("Test paste at caret") { model.runInjectionSelfTest() }
                        Button("Test streaming LLM…") { model.runLLMSelfTest() }
                    }
                    .padding(.vertical, 6)
                }

                Button("Save") {
                    save()
                }
                .buttonStyle(.borderedProminent)

                Spacer(minLength: 24)
            }
            .padding(28)
            .frame(maxWidth: 560, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            apiKeyDraft = model.keychain.readAPIKey() ?? ""
            baseURL = model.settings.openAIBaseURL
            openaiModel = model.settings.modelName
            debounceMs = String(model.settings.orchestratorDebounceMs)
            whisperPath = model.settings.whisperCLIPath
            whisperModel = model.settings.whisperModelPath
            useWhisper = model.settings.useWhisperCLI
            model.refreshPermissions()
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
        saveBanner = "Settings saved."
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            saveBanner = ""
        }
    }
}
