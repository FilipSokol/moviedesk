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
                    withAnimation { sync.back() }
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!panel.canGoBack)
                .opacity(panel.canGoBack ? 1 : 0.35)
                .help("Cofnij o krok (⌘Z)")
                .keyboardShortcut("z", modifiers: .command)

                Button {
                    withAnimation { sync.shuffle() }
                } label: {
                    ShuffleGlyph(tapCounter: sync.state.tapCounter, size: 28)
                }
                .buttonStyle(.plain)
                .disabled(!panel.canAdvance)
                .help("Pokaż kolejne")
            }

            ScenarioPicker(selection: panel.scenario, available: panel.available) { scenario in
                withAnimation(.snappy) { sync.setScenario(scenario) }
            }

            if panel.picks.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(emptyMessage(for: panel.scenario))
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
                    menu: menu(slot:pick:),
                    flips: panel.flips
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

    private func emptyMessage(for scenario: Scenario) -> String {
        if !sync.isConfigured { return "Uzupełnij klucz TMDB w ustawieniach." }
        if case .loggedOut = sync.filmweb { return "Zaloguj się do Filmwebu w ustawieniach." }
        if sync.lastSync == nil { return "Propozycje pojawią się po pierwszej synchronizacji." }
        if scenario.requiresVOD && sync.services.isEmpty {
            return "Ten scenariusz pokazuje filmy z Twoich serwisów VOD — dodaj link do serwisu w ustawieniach."
        }
        return "Brak propozycji w scenariuszu „\(scenario.title)”. Wybierz inny albo zsynchronizuj ponownie."
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

/// Cztery scenariusze jako szklane kapsułki; puste są przygaszone.
private struct ScenarioPicker: View {
    let selection: Scenario
    let available: [Scenario]
    let onSelect: (Scenario) -> Void

    var body: some View {
        GlassEffectContainer(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(Scenario.allCases, id: \.self) { scenario in
                    Button {
                        onSelect(scenario)
                    } label: {
                        Label(scenario.title, systemImage: scenario.symbol)
                            .labelStyle(scenario == selection ? AnyLabelStyle(.titleAndIcon) : AnyLabelStyle(.iconOnly))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(
                        scenario == selection ? .regular.tint(.accentColor.opacity(0.35)).interactive() : .regular.interactive(),
                        in: Capsule()
                    )
                    .opacity(available.contains(scenario) || scenario == selection ? 1 : 0.45)
                    .help("\(scenario.title) — \(scenario.subtitle)")
                    .accessibilityLabel(scenario.title)
                }
            }
        }
    }
}

/// Pozwala przełączać styl etykiety warunkowo.
private struct AnyLabelStyle: LabelStyle {
    private let make: (Configuration) -> AnyView

    init<S: LabelStyle>(_ style: S) {
        make = { AnyView(style.makeBody(configuration: $0)) }
    }

    func makeBody(configuration: Configuration) -> some View {
        make(configuration)
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
                        Button {
                            NSWorkspace.shared.open(pick.openURL)
                        } label: {
                            PickPoster(pick: pick, cornerRadius: 6, maxPixel: 120, showsBadges: false)
                                .frame(width: 34, height: 51)
                        }
                        .buttonStyle(.plain)
                        .help("\(pick.title) · \(pick.destinationName)")
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
