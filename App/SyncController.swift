import AppKit
import ServiceManagement
import SwiftUI
import WidgetKit

/// Ustawienia, nocna synchronizacja i aktualna pula propozycji.
///
/// Klucze TMDB/OMDb leżą wyłącznie w ustawieniach aplikacji na tym Macu (kontener sandboxa),
/// a sesja Filmwebu w magazynie WebKitu aplikacji — nie ma ich w repozytorium ani w widgecie.
@MainActor
final class SyncController: ObservableObject {
    @Published var tmdbCredential: String {
        didSet { defaults.set(tmdbCredential, forKey: Keys.tmdb) }
    }
    /// Opcjonalnie — tylko po oceny IMDb.
    @Published var omdbKey: String {
        didSet { defaults.set(omdbKey, forKey: Keys.omdb) }
    }

    @Published private(set) var snapshot: PicksSnapshot
    @Published private(set) var cursor: Int
    @Published private(set) var isSyncing = false
    @Published private(set) var status = ""
    @Published private(set) var lastError: String?
    @Published private(set) var lastSync: Date?
    /// Nazwa użytkownika Filmwebu albo `nil`, gdy nie jesteś zalogowany (lub jeszcze nie sprawdzono).
    @Published private(set) var filmwebUser: String?
    @Published private(set) var isCheckingFilmweb = false
    @Published private(set) var launchesAtLogin = SMAppService.mainApp.status == .enabled

    private let defaults = UserDefaults.standard
    private var midnightTask: Task<Void, Never>?
    private var wakeObserver: NSObjectProtocol?

    private enum Keys {
        static let tmdb = "tmdb.credential"
        static let omdb = "omdb.key"
    }

    init() {
        defaults.removeObject(forKey: "filmweb.cookie") // stara wersja trzymała tu wklejone ciasteczko
        tmdbCredential = defaults.string(forKey: Keys.tmdb) ?? ""
        omdbKey = defaults.string(forKey: Keys.omdb) ?? ""
        snapshot = PicksStore.load()
        cursor = PicksStore.cursor
        lastSync = Library.load().lastSync

        scheduleMidnightSync()
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            // Po wybudzeniu sieć wstaje chwilę później.
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(30))
                await self?.syncIfDue()
            }
        }
        Task {
            await checkFilmweb()
            await syncIfDue()
        }
    }

    var isConfigured: Bool {
        !tmdbCredential.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !services.isEmpty
    }

    /// Serwisy VOD rozpoznane w Twoich linkach — tylko z nich pokazujemy propozycje.
    var services: [StreamingService] {
        StreamingService.detected(in: LinkStore.load())
    }

    var currentPicks: [Pick] {
        PicksStore.page(of: snapshot, cursor: cursor)
    }

    // MARK: - Propozycje

    func showNext() {
        PicksStore.advance()
        cursor = PicksStore.cursor
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Kursor mógł się zmienić z poziomu widgetu.
    func reloadFromStore() {
        snapshot = PicksStore.load()
        cursor = PicksStore.cursor
    }

    // MARK: - Synchronizacja

    /// Synchronizuje, jeśli dziś (od północy) jeszcze tego nie robiliśmy.
    func syncIfDue() async {
        let midnight = Calendar.current.startOfDay(for: .now)
        guard isConfigured, (lastSync ?? .distantPast) < midnight else { return }
        await sync()
    }

    func sync() async {
        guard !isSyncing else { return }
        guard isConfigured else {
            lastError = "Uzupełnij klucz TMDB i dodaj link do co najmniej jednego serwisu VOD."
            return
        }
        isSyncing = true
        lastError = nil
        defer { isSyncing = false }

        let engine = RecommendationEngine(
            filmweb: FilmwebClient(),
            tmdb: TMDBClient(credential: tmdbCredential.trimmingCharacters(in: .whitespacesAndNewlines)),
            omdb: omdbKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : OMDbClient(apiKey: omdbKey.trimmingCharacters(in: .whitespacesAndNewlines)),
            services: services,
            progress: { [weak self] text in
                await MainActor.run { self?.status = text }
            }
        )

        var library = Library.load()
        do {
            let newSnapshot = try await engine.run(library: &library)
            library.lastSync = .now
            library.save()
            PicksStore.save(newSnapshot)
            snapshot = newSnapshot
            cursor = PicksStore.cursor
            lastSync = library.lastSync
            status = "Gotowe — \(newSnapshot.picks.count) propozycji."
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            library.save()
            status = ""
            lastError = error.localizedDescription
            if case FilmwebSession.SessionError.notLoggedIn = error {
                filmwebUser = nil
            }
        }
    }

    /// Sprawdza, czy sesja Filmwebu w aplikacji jest zalogowana.
    func checkFilmweb() async {
        isCheckingFilmweb = true
        defer { isCheckingFilmweb = false }
        try? await FilmwebSession.shared.refresh(force: true)
        filmwebUser = await FilmwebSession.shared.loggedUserName()
    }

    func logOutOfFilmweb() async {
        await FilmwebSession.shared.logOut()
        filmwebUser = nil
    }

    private func scheduleMidnightSync() {
        midnightTask?.cancel()
        midnightTask = Task { [weak self] in
            while !Task.isCancelled {
                let next = Calendar.current.nextDate(
                    after: .now, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime
                ) ?? .now.addingTimeInterval(24 * 3600)
                try? await Task.sleep(for: .seconds(max(60, next.timeIntervalSinceNow + 5)))
                guard !Task.isCancelled else { return }
                await self?.syncIfDue()
            }
        }
    }

    // MARK: - Start przy logowaniu

    func setLaunchesAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            lastError = "Nie udało się zmienić startu przy logowaniu: \(error.localizedDescription)"
        }
        launchesAtLogin = SMAppService.mainApp.status == .enabled
    }
}
