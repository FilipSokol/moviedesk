import AppKit
import SwiftUI

/// Popover z ikony w pasku menu: trzy filmy na dziś, małe skróty i przyciski.
struct MenuBarPanel: View {
    @EnvironmentObject private var links: LinksModel
    @EnvironmentObject private var sync: SyncController
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Na dziś")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Spacer()
                if sync.isSyncing {
                    ProgressView().controlSize(.small)
                }
                Button {
                    sync.showNext()
                } label: {
                    ShuffleGlyph(cursor: sync.cursor, size: 28)
                }
                .buttonStyle(.plain)
                .disabled(sync.snapshot.picks.isEmpty)
                .help("Pokaż kolejne filmy")
            }

            if sync.snapshot.picks.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(sync.isConfigured ? "Propozycje pojawią się po pierwszej synchronizacji." : "Uzupełnij Filmweb i TMDB w ustawieniach.")
                    if let error = sync.lastError {
                        Text(error).foregroundStyle(.red)
                    } else if !sync.status.isEmpty {
                        Text(sync.status).foregroundStyle(.secondary)
                    }
                }
                .font(.callout)
                .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
            } else {
                PicksRow(
                    picks: sync.currentPicks,
                    cursor: sync.cursor,
                    destination: { $0.openURL },
                    titleSize: 11,
                    showsDetailsOnHover: true
                )
            }

            GlassEffectContainer(spacing: 8) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 34), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(links.links) { link in
                        Button {
                            if let url = link.url { NSWorkspace.shared.open(url) }
                        } label: {
                            LinkGlyph(link: link, size: 26)
                                .padding(4)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: Circle())
                        .disabled(link.url == nil)
                        .help(link.name)
                    }
                }
            }

            HStack {
                Button("Ustawienia", systemImage: "gearshape") {
                    // Najpierw aktywacja — inaczej okno aplikacji z paska menu nie dostaje klawiatury.
                    NSApp.activate()
                    openWindow(id: MainWindow.id)
                }
                Spacer()
                Button("Zakończ", systemImage: "power") {
                    NSApp.terminate(nil)
                }
            }
            .buttonStyle(.glass)
            .controlSize(.small)
        }
        .padding(16)
        .frame(width: 340)
        .onAppear { sync.reloadFromStore() }
    }
}
