import AppKit
import SwiftUI

/// Zakładka „Rekomendacje”: dane dostępowe, serwisy i synchronizacja.
struct SettingsView: View {
    @EnvironmentObject private var sync: SyncController
    @EnvironmentObject private var links: LinksModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Form {
            Section {
                HStack {
                    switch sync.filmweb {
                    case .checking:
                        ProgressView().controlSize(.small)
                        Text("Sprawdzam…").foregroundStyle(.secondary)
                    case .loggedIn(let user):
                        Label("Zalogowano: \(user)", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case .loggedOut:
                        Label("Nie zalogowano", systemImage: "person.crop.circle.badge.exclamationmark")
                            .foregroundStyle(.secondary)
                    case .unknown:
                        Label("Nie da się teraz sprawdzić (brak sieci?)", systemImage: "wifi.exclamationmark")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    switch sync.filmweb {
                    case .loggedIn:
                        Button("Wyloguj") { Task { await sync.logOutOfFilmweb() } }
                    case .unknown:
                        Button("Sprawdź ponownie") { Task { await sync.checkFilmweb() } }
                    default:
                        Button("Zaloguj się…") {
                            NSApp.activate()
                            openWindow(id: FilmwebLoginView.windowID)
                        }
                        .disabled(sync.filmweb == .checking)
                    }
                }
            } header: {
                Text("Filmweb")
            } footer: {
                Text("Logujesz się raz, w okienku Filmwebu w aplikacji. Sesja trwa, dopóki Filmweb Cię nie wyloguje — wtedy zobaczysz prośbę o ponowne zalogowanie.")
            }

            Section {
                SecureField("Klucz", text: $sync.tmdbCredential, prompt: Text("klucz API lub token odczytu"))
            } header: {
                Text("TMDB")
            } footer: {
                Text("Darmowy klucz: themoviedb.org → Ustawienia → API. Z TMDB pochodzą plakaty, podobne filmy i dostępność w serwisach w Polsce (dane JustWatch).")
            }

            Section {
                SecureField("Klucz OMDb", text: $sync.omdbKey, prompt: Text("opcjonalnie"))
            } header: {
                Text("Oceny IMDb")
            } footer: {
                Text("Bez klucza nowe tytuły pokazują ocenę TMDB. Darmowy klucz: omdbapi.com → API Key. Tytuły z Twojej listy i do powtórki mają zawsze ocenę z Filmwebu.")
            }

            Section {
                ForEach(Scenario.allCases, id: \.self) { scenario in
                    Label {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(scenario.title)
                            Text(scenario.subtitle).font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: scenario.symbol)
                    }
                }
            } header: {
                Text("Scenariusze")
            } footer: {
                Text("„Randka” i „Wspólna lista” pomijają horrory i bardzo krwawe filmy, obniżają ocenę akcji i przemocy, a wyżej stawiają love story, dobre dramaty i komedie. „Na półkę” to nowości z ostatnich 2 lat, które mają już wydanie Blu-ray albo cyfrowe — linki prowadzą do Google.")
            }

            Section {
                let detected = StreamingService.detected(in: links.links)
                if detected.isEmpty {
                    Text("Brak — dodaj link do serwisu VOD w zakładce „Linki”.")
                        .foregroundStyle(.secondary)
                } else {
                    Text(detected.map(\.displayName).joined(separator: " · "))
                }
            } header: {
                Text("Twoje serwisy")
            } footer: {
                Text("Rozpoznawane po linkach: \(StreamingService.allCases.map(\.displayName).joined(separator: ", ")). Pozostałe linki są zwykłymi skrótami. Po zmianie serwisów kliknij „Synchronizuj teraz”.")
            }

            Section {
                HStack {
                    Button(sync.isSyncing ? "Synchronizuję…" : "Synchronizuj teraz") {
                        Task { await sync.sync() }
                    }
                    .disabled(sync.isSyncing)
                    if sync.isSyncing { ProgressView().controlSize(.small) }
                    Spacer()
                    if let lastSync = sync.lastSync {
                        Text("Ostatnio: \(PickFormatting.relativeDay(lastSync))")
                            .foregroundStyle(.secondary)
                    }
                }
                if !sync.status.isEmpty {
                    Text(sync.status).foregroundStyle(.secondary)
                }
                if let error = sync.lastError {
                    Text(error).foregroundStyle(.red)
                }
                Toggle("Uruchamiaj przy logowaniu", isOn: Binding(
                    get: { sync.launchesAtLogin },
                    set: { sync.setLaunchesAtLogin($0) }
                ))
                if sync.launchStatus == .requiresApproval {
                    Text("Zatwierdź MovieDesk w Ustawieniach systemowych → Ogólne → Rzeczy otwierane podczas logowania.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("Synchronizacja")
            } footer: {
                Text("Oceny pobierają się codziennie o północy (albo zaraz po wybudzeniu Maca, jeśli spał). Pierwsza synchronizacja trwa kilka minut; kolejne są szybkie, bo tytuły i dopasowania są zapamiętane. Gdy się nie uda, ponawia się po 5, 15 i 60 minutach.")
            }

            HiddenAndSavedSection()
        }
        .formStyle(.grouped)
        .onAppear { sync.refreshLaunchStatus() }
    }
}

/// Ukryte w widgetach i zapisane na później — z możliwością przywrócenia.
private struct HiddenAndSavedSection: View {
    @EnvironmentObject private var sync: SyncController

    var body: some View {
        Section {
            if sync.savedPicks.isEmpty && sync.hiddenTitles.isEmpty {
                Text("Nic tu jeszcze nie ma.").foregroundStyle(.secondary)
            }
            ForEach(sync.savedPicks) { pick in
                HStack {
                    Label(pick.title, systemImage: "bookmark.fill")
                    Spacer()
                    Text(pick.destinationName).foregroundStyle(.secondary)
                    Button("Usuń") { sync.setSaved(pick, false) }
                        .buttonStyle(.borderless)
                }
            }
            ForEach(sync.hiddenTitles, id: \.id) { item in
                HStack {
                    Label(item.title, systemImage: item.reason == .watched ? "checkmark.circle" : "eye.slash")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Przywróć") { sync.restore(item.id) }
                        .buttonStyle(.borderless)
                }
            }
        } header: {
            Text("Zapisane i ukryte")
        } footer: {
            Text("Ukryte tytuły nie wracają w propozycjach, dopóki ich nie przywrócisz.")
        }
    }
}
