import SwiftUI

struct DesktopRootView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var section: SidebarSection = .home
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $section) {
                Section {
                    navItem(.home)
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
            .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } detail: {
            detailContent
                .frame(minWidth: 480, minHeight: 400)
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch section {
        case .home:
            HomeView()
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
