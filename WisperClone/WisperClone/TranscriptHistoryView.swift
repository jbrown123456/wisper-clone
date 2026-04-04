import AppKit
import SwiftUI

struct TranscriptHistoryView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("This session")
                    .font(.largeTitle.weight(.bold))
                Text("Everything you dictated appears here until you quit the app. Nothing is saved to disk.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if appModel.transcriptItems.isEmpty {
                    emptyState
                } else {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(appModel.transcriptItems) { item in
                            transcriptRow(item)
                        }
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 720, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "text.bubble")
                .font(.system(size: 36))
                .foregroundStyle(AppTheme.accent.opacity(0.6))
            Text("No dictations yet")
                .font(.title3.weight(.semibold))
            Text("Hold Right Option (⌥) or press and hold on the floating control, then speak. Finished turns show up here.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private func transcriptRow(_ item: TranscriptItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(languageLabel(item.sourceLanguageId))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if !item.injectionOK {
                    Label("Paste failed", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
            if !item.nativeText.isEmpty {
                Text(item.nativeText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            if !item.englishText.isEmpty {
                Text(item.englishText)
                    .font(.body)
                    .textSelection(.enabled)
            }
            if let err = item.errorMessage, !err.isEmpty {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            HStack(spacing: 10) {
                Button("Copy English") {
                    copyToPasteboard(item.englishText)
                }
                .disabled(item.englishText.isEmpty)
                Button("Copy both") {
                    let both = [item.nativeText, item.englishText].filter { !$0.isEmpty }.joined(separator: "\n\n")
                    copyToPasteboard(both)
                }
                .disabled(item.nativeText.isEmpty && item.englishText.isEmpty)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private func languageLabel(_ id: String) -> String {
        SourceLanguage.catalog.first { $0.id == id }?.name ?? id
    }

    private func copyToPasteboard(_ s: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
        NSSound.beep()
    }
}
