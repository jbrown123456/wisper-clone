import SwiftUI

/// Home: pick the language you speak (**translate / recognize from**). Output language is English in this MVP.
struct HomeView: View {
    @AppStorage("translateFromLanguageId") private var selectedLanguageId = "es"
    private let columns = [GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                heroPanel

                VStack(alignment: .leading, spacing: 12) {
                    Text("Translate from")
                        .font(.title3.weight(.semibold))

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
                    .appCard()
                }
            }
            .padding(28)
            .frame(maxWidth: 720, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var heroPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Welcome back")
                        .font(.title2.weight(.semibold))
                    Text(Brand.tagline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("Live")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(AppTheme.accent.opacity(0.15), in: Capsule())
            }

            HStack(spacing: 10) {
                statChip(title: "Streak", value: "2 weeks")
                statChip(title: "Words", value: "1,012")
                statChip(title: "Speed", value: "158 WPM")
            }

            Text("Tip: hold Right Option (⌥) or the floating pill to dictate. Pause capture or hide the pill in Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [AppTheme.accent.opacity(0.16), AppTheme.accentTint.opacity(0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            ),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous),
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(AppTheme.accent.opacity(0.18), lineWidth: 1),
        )
    }

    private func statChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
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
                    .fill(on ? AppTheme.accent.opacity(0.16) : Color(nsColor: .controlBackgroundColor)),
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(on ? AppTheme.accent.opacity(0.6) : Color.primary.opacity(0.08), lineWidth: on ? 2 : 1),
            )
        }
        .buttonStyle(.plain)
    }
}
