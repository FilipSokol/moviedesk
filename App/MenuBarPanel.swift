import AppKit
import SwiftUI

/// Popover z ikony w pasku menu: trzy tytuły na dziś (ten sam pas co domyślny widget
/// „Na dziś”), zapisane, skróty i przyciski. Prawy klik na plakacie — więcej akcji.
struct MenuBarPanel: View {
    @EnvironmentObject private var links: LinksModel
    @EnvironmentObject private var sync: SyncController
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let panel = sync.panel
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("Na dziś")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                if sync.isStale || sync.lastError != nil {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.orange)
                        .help(sync.lastError ?? "Propozycje są sprzed ponad doby — synchronizacja się nie udała.")
                }
                Spacer()
                if sync.isSyncing {
                    ProgressView().controlSize(.small)
                        .help(sync.status)
                }
                Button {
                    withAnimation { sync.shuffle() }
                } label: {
                    ShuffleGlyph(tapCounter: sync.state.tapCounter, size: 28)
                }
                .buttonStyle(.plain)
                .disabled(!panel.canAdvance)
                .help("Pokaż kolejne")
            }

            if panel.picks.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(emptyMessage)
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
                    picks: panel.picks,
                    event: panel.event,
                    destination: { $0.openURL },
                    titleSize: 11,
                    posterPixels: 300,
                    showsDetailsOnHover: true,
                    menu: menu(slot:pick:)
                )
            }

            if !sync.savedPicks.isEmpty {
                SavedStrip(picks: sync.savedPicks)
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
                        .accessibilityLabel(link.name)
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

    private var emptyMessage: String {
        if !sync.isConfigured { return "Uzupełnij klucz TMDB i dodaj link do serwisu VOD w ustawieniach." }
        if case .loggedOut = sync.filmweb { return "Zaloguj się do Filmwebu w ustawieniach." }
        return "Propozycje pojawią się po pierwszej synchronizacji."
    }

    private func menu(slot: Int, pick: Pick) -> [PickMenuAction] {
        let saved = sync.isSaved(pick)
        return [
            PickMenuAction(title: "Inny tytuł", systemImage: "forward") {
                withAnimation { sync.next(slot: slot, pick: pick) }
            },
            PickMenuAction(
                title: saved ? "Usuń z zapisanych" : "Zapisz na później",
                systemImage: saved ? "bookmark.slash" : "bookmark"
            ) {
                sync.setSaved(pick, !saved)
            },
            PickMenuAction(title: "Już obejrzane", systemImage: "checkmark.circle") {
                withAnimation { sync.hide(slot: slot, pick: pick, reason: .watched) }
            },
            PickMenuAction(title: "Nie pokazuj więcej", systemImage: "eye.slash", role: .destructive) {
                withAnimation { sync.hide(slot: slot, pick: pick, reason: .notInterested) }
            },
        ]
    }
}

/// Pasek zapisanych tytułów (z widgetu albo z menu plakatu).
private struct SavedStrip: View {
    let picks: [Pick]
    @EnvironmentObject private var sync: SyncController

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Zapisane")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(picks) { pick in
                        Link(destination: pick.openURL) {
                            PickPoster(pick: pick, cornerRadius: 6, maxPixel: 120, showsBadges: false)
                                .frame(width: 34)
                        }
                        .help("\(pick.title) · \(pick.service.displayName)")
                        .contextMenu {
                            Button("Usuń z zapisanych", systemImage: "bookmark.slash") {
                                sync.setSaved(pick, false)
                            }
                        }
                    }
                }
            }
        }
    }
}
