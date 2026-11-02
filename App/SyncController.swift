import AppKit
import ServiceManagement
import SwiftUI
import WidgetKit

/// Ustawienia, nocna synchronizacja i aktualna pula propozycji.
///
/// Dane dostępowe (ciasteczko Filmwebu, klucz TMDB) leżą wyłącznie w ustawieniach aplikacji
/// na tym Macu (kontener sandboxa) — nie ma ich w repozytorium ani w kontenerze widgetu.
@MainActor
final class SyncController: ObservableObject {
    @Published var filmwebCookie: String {
        didSet { defaults.set(filmwebCookie, forKey: Keys.cookie) }
    }
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
    @Published private(set) var launchesAtLogin = SMAppService.mainApp.status == .enabled

    private let defaults = UserDefaults.standard
    private var midnightTask: Task<Void, Never>?
    private var wakeObserver: NSObjectProtocol?

    private enum Keys {
        static let cookie = "filmweb.cookie"
        static let tmdb = "tmdb.credential"
        static let omdb = "omdb.key"
    }

    init() {
        filmwebCookie = defaults.string(forKey: Keys.cookie) ?? ""
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
        Task { await syncIfDue() }
    }

    var isConfigured: Bool {
        !filmwebCookie.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !tmdbCredential.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
            lastError = "Uzupełnij ciasteczko Filmwebu i klucz TMDB oraz dodaj link do co najmniej jednego serwisu VOD."
            return
        }
        isSyncing = true
        lastError = nil
        defer { isSyncing = false }

        let engine = RecommendationEngine(
            filmweb: FilmwebClient(cookie: filmwebCookie.trimmingCharacters(in: .whitespacesAndNewlines)),
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
        }
    }

    /// Sprawdza ciasteczko Filmwebu; zwraca nazwę użytkownika albo opis błędu.
    func checkFilmweb() async -> String {
        do {
            let name = try await FilmwebClient(cookie: filmwebCookie.trimmingCharacters(in: .whitespacesAndNewlines))
                .loggedUserName()
            return "Połączono: \(name)"
        } catch {
            return error.localizedDescription
        }
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
