import SwiftUI

/// Home: pick the language you speak (**translate / recognize from**). Output language is English in this MVP.
struct HomeView: View {
    @AppStorage("translateFromLanguageId") private var selectedLanguageId = "es"
    private let columns = [GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Home")
                        .font(.largeTitle.weight(.bold))
                    Text("Choose the language you want to translate from. Speech is converted to clear English.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Text("Tip: hold Right Option (⌥) to dictate when capture is enabled (see Settings).")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Translate from")
                        .font(.headline)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(SourceLanguage.catalog) { lang in
                            languageTile(lang)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Output")
                        .font(.headline)
                    HStack {
                        Text("English (always)")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .padding(28)
            .frame(maxWidth: 720, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func languageTile(_ lang: SourceLanguage) -> some View {
        let on = selectedLanguageId == lang.id
        Button {
            selectedLanguageId = lang.id
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(lang.flag)
                    .font(.title2)
                Text(lang.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(lang.id)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(on ? Color.accentColor.opacity(0.18) : Color(nsColor: .controlBackgroundColor)),
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(on ? Color.accentColor.opacity(0.65) : Color.primary.opacity(0.08), lineWidth: on ? 2 : 1),
            )
        }
        .buttonStyle(.plain)
    }
}
