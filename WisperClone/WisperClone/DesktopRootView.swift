import SwiftUI

struct DesktopRootView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var section: SidebarSection = .home
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppTheme.accentTint.opacity(0.8),
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .windowBackgroundColor),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )
            .ignoresSafeArea()

            NavigationSplitView(columnVisibility: $columnVisibility) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.accent, AppTheme.accentSoft],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing,
                                ),
                            )
                            .frame(width: 28, height: 28)
                            .overlay(Image(systemName: "waveform").font(.system(size: 13, weight: .bold)).foregroundStyle(.white))
                        Text("Flow")
                            .font(.title3.weight(.semibold))
                        Spacer()
                        Text("Basic")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AppTheme.accent.opacity(0.12), in: Capsule())
                    }
                    .padding(.top, 6)

                    List(selection: $section) {
                        Section {
                            navItem(.home)
                            navItem(.thisSession)
                            navItem(.dictionary)
                            navItem(.snippets)
                            navItem(.scratchPad)
                        }
                        Section("Team & billing") {
                            navItem(.inviteTeam)
                            navItem(.promoMonthFree)
                        }
                        Section {
                            navItem(.settings)
                            navItem(.help)
                        }
                    }
                    .listStyle(.sidebar)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Try Flow Pro")
                            .font(.subheadline.weight(.semibold))
                        Text("Unlimited words, smarter formatting, and team features.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Upgrade") {}
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.accent)
                    }
                    .padding(12)
                    .appCard()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
            } detail: {
                detailContent
                    .frame(minWidth: 480, minHeight: 400)
            }
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch section {
        case .home:
            HomeView()
        case .thisSession:
            TranscriptHistoryView()
        case .dictionary:
            DictionaryView()
        case .snippets:
            SnippetsView()
        case .scratchPad:
            ScratchPadView()
        case .inviteTeam:
            InviteTeamView()
        case .promoMonthFree:
            PromoMonthFreeView()
        case .settings:
            DesktopSettingsView(model: appModel)
        case .help:
            HelpView()
        }
    }

    private func navItem(_ item: SidebarSection) -> some View {
        Label(item.title, systemImage: item.icon)
            .tag(item)
    }
}
