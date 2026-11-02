import SwiftUI

/// Zakładka „Rekomendacje”: dane dostępowe, serwisy i synchronizacja.
struct SettingsView: View {
    @EnvironmentObject private var sync: SyncController
    @EnvironmentObject private var links: LinksModel
    @State private var filmwebCheck: String?
    @State private var isChecking = false

    var body: some View {
        Form {
            Section {
                SecureField("Ciasteczko", text: $sync.filmwebCookie, prompt: Text("wklej wartość nagłówka Cookie"))
                HStack {
                    Button("Sprawdź połączenie") {
                        isChecking = true
                        Task {
                            filmwebCheck = await sync.checkFilmweb()
                            isChecking = false
                        }
                    }
                    .disabled(sync.filmwebCookie.isEmpty || isChecking)
                    if isChecking { ProgressView().controlSize(.small) }
                    if let filmwebCheck {
                        Text(filmwebCheck).foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Filmweb")
            } footer: {
                Text("Zaloguj się na filmweb.pl w przeglądarce, otwórz narzędzia deweloperskie (⌥⌘I) → Sieć, odśwież stronę, kliknij dowolne żądanie do filmweb.pl i skopiuj całą wartość nagłówka „Cookie”. Gdy sesja wygaśnie, wklej ją ponownie.")
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
                        Text("Ostatnio: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
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
            } header: {
                Text("Synchronizacja")
            } footer: {
                Text("Oceny pobierają się codziennie o północy (albo zaraz po wybudzeniu Maca, jeśli spał). Pierwsza synchronizacja trwa dłużej — kolejne pobierają tylko nowe oceny.")
            }
        }
        .formStyle(.grouped)
    }
}
