import AppKit
import ServiceManagement
import SwiftUI
import WidgetKit

/// Ustawienia, nocna synchronizacja i to, co widać w panelu z paska menu.
///
/// Klucze TMDB/OMDb leżą wyłącznie w ustawieniach aplikacji na tym Macu (kontener sandboxa),
/// a sesja Filmwebu w magazynie WebKitu aplikacji — nie ma ich w repozytorium ani w widgecie.
@MainActor
final class SyncController: ObservableObject {
    enum FilmwebStatus: Equatable {
        case checking
        case loggedIn(String)
        case loggedOut
        case unknown(String)
    }

    @Published var tmdbCredential: String {
        didSet { defaults.set(tmdbCredential, forKey: Keys.tmdb) }
    }
    /// Opcjonalnie — tylko po oceny IMDb.
    @Published var omdbKey: String {
        didSet { defaults.set(omdbKey, forKey: Keys.omdb) }
    }

    @Published private(set) var snapshot: PicksSnapshot
    @Published private(set) var state: DeskState
    @Published private(set) var isSyncing = false
    @Published private(set) var status = ""
    @Published private(set) var lastError: String?
    @Published private(set) var lastSync: Date?
    @Published private(set) var filmweb: FilmwebStatus = .checking
    @Published private(set) var launchStatus = SMAppService.mainApp.status

    private let defaults = UserDefaults.standard
    private var midnightTask: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?
    private var retryAttempt = 0
    private var observers: [NSObjectProtocol] = []
    private var deskObserver: DeskObserver?

    private enum Keys {
        static let tmdb = "tmdb.credential"
        static let omdb = "omdb.key"
        static let lastSync = "sync.last"
    }

    init() {
        // Stare wersje trzymały tu wklejone ciasteczko i kursor — sprzątamy.
        defaults.removeObject(forKey: "filmweb.cookie")
        AppGroup.defaults.removeObject(forKey: "picks.cursor")

        tmdbCredential = defaults.string(forKey: Keys.tmdb) ?? ""
        omdbKey = defaults.string(forKey: Keys.omdb) ?? ""
        snapshot = PicksStore.load()
        state = StateStore.load()
        lastSync = defaults.object(forKey: Keys.lastSync) as? Date

        if PicksStore.containerURL == nil {
            lastError = "Brak dostępu do App Group — widget nie zobaczy propozycji. Wpisz Team ID w Config/Local.xcconfig i zbuduj ponownie."
        }

        scheduleMidnightSync()
        observeSystem()
        deskObserver = DeskObserver { [weak self] in self?.reloadFromStore() }

        Task {
            await refreshIcons()
            await checkFilmweb()
            await syncIfDue()
        }
    }

    /// Wystarczy klucz TMDB — bez serwisów VOD działają scenariusze „Premiery HD”
    /// i „Wspólna lista”.
    var isConfigured: Bool {
        !tmdbCredential.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Serwisy VOD rozpoznane w Twoich linkach — tylko z nich pokazujemy propozycje.
    var services: [StreamingService] {
        StreamingService.detected(in: LinkStore.load())
    }

    var isStale: Bool {
        guard let lastSync else { return false }
        return Date().timeIntervalSince(lastSync) > 36 * 3600
    }

    // MARK: - Panel (ten sam pas co domyślna półka w widgetach)

    struct PanelView {
        var picks: [Pick] = []
        var event: LaneEvent?
        var canAdvance = false
        var scenario: Scenario = .forMe
        var available: [Scenario] = []
        var flips: [Int] = []
        var canGoBack = false
    }

    var panel: PanelView {
        let scenario = state.scenario(for: .panel)
        let eligible = LaneResolver.eligible(snapshot: snapshot, state: state, filter: DeskLane.panel.filter, scenario: scenario)
        let ids = eligible.map(\.id)
        let lane = LaneResolver.materialize(
            state.lanes[DeskLane.panel.trackKey(scenario)], ids: ids, snapshotID: snapshot.generatedAt, kind: .shelf
        )
        let byID = Dictionary(eligible.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return PanelView(
            picks: lane.slots.compactMap { byID[$0] },
            event: lane.event,
            canAdvance: LaneResolver.canAdvance(ids: ids, kind: .shelf),
            scenario: scenario,
            available: LaneResolver.availableScenarios(snapshot: snapshot, state: state, filter: DeskLane.panel.filter),
            flips: lane.flips ?? [],
            canGoBack: lane.canGoBack
        )
    }

    func setScenario(_ scenario: Scenario) { act { DeskActions.setScenario(.panel, scenario) } }

    var savedPicks: [Pick] {
        state.saved.values.sorted { $0.at > $1.at }.map(\.pick)
    }

    var hiddenTitles: [(id: String, title: String, reason: Dismissal.Reason)] {
        let known = Dictionary(
            (snapshot.picks + savedPicks).map { ($0.id, $0.title) },
            uniquingKeysWith: { first, _ in first }
        )
        return state.dismissed
            .sorted { $0.value.at > $1.value.at }
            .map { (id: $0.key, title: known[$0.key] ?? $0.key, reason: $0.value.reason) }
    }

    func shuffle() { act { DeskActions.shuffle(.panel) } }
    func back() { act { DeskActions.back(.panel) } }
    func next(slot: Int, pick: Pick) { act { DeskActions.next(.panel, slot: slot, pickID: pick.id) } }
    func hide(slot: Int, pick: Pick, reason: Dismissal.Reason) {
        act { DeskActions.hide(.panel, slot: slot, pickID: pick.id, reason: reason) }
    }
    func setSaved(_ pick: Pick, _ isSaved: Bool) { act { DeskActions.setSaved(pickID: pick.id, isSaved) } }
    func restore(_ id: String) { act { DeskActions.restore(id) } }

    func isSaved(_ pick: Pick) -> Bool { state.saved[pick.id] != nil }

    private func act(_ change: () -> Void) {
        change()
        reloadFromStore()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Stan mógł się zmienić z poziomu widgetu.
    func reloadFromStore() {
        snapshot = PicksStore.load()
        state = StateStore.load()
    }

    // MARK: - Synchronizacja

    /// Synchronizuje, jeśli dziś (od północy) jeszcze się nie udało.
    func syncIfDue() async {
        let midnight = Calendar.current.startOfDay(for: .now)
        guard isConfigured, (lastSync ?? .distantPast) < midnight else { return }
        await sync()
    }

    func sync() async {
        guard !isSyncing else { return }
        guard isConfigured else {
            lastError = "Uzupełnij klucz TMDB w ustawieniach."
            return
        }
        guard PicksStore.containerURL != nil else {
            lastError = "Brak dostępu do App Group — wpisz Team ID w Config/Local.xcconfig i zbuduj ponownie."
            return
        }
        retryTask?.cancel()
        isSyncing = true
        lastError = nil
        let activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "Synchronizacja propozycji MovieDesk"
        )
        defer {
            ProcessInfo.processInfo.endActivity(activity)
            isSyncing = false
            FilmwebSession.shared.suspend()
        }

        let omdb = omdbKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let engine = RecommendationEngine(
            filmweb: FilmwebClient(),
            tmdb: TMDBClient(credential: tmdbCredential.trimmingCharacters(in: .whitespacesAndNewlines)),
            omdb: omdb.isEmpty ? nil : OMDbClient(apiKey: omdb),
            services: services,
            excludedIDs: Set(StateStore.load().dismissed.keys),
            progress: { @MainActor [weak self] text in
                self?.status = text
            }
        )

        var library = Library.load()
        do {
            let newSnapshot = try await engine.run(library: &library)
            library.lastSync = .now
            library.save()
            PicksStore.save(newSnapshot)
            // Obrazki sprzątamy dopiero po zapisie nowej puli; zapisane tytuły zostają.
            let saved = StateStore.load().saved.values.map(\.pick)
            PicksStore.cleanUpImages(keeping: newSnapshot.picks + saved)

            lastSync = .now
            defaults.set(lastSync, forKey: Keys.lastSync)
            retryAttempt = 0
            reloadFromStore()
            status = "Gotowe — \(newSnapshot.picks.count) propozycji."
            if case .loggedIn = filmweb {} else { filmweb = .loggedIn("zalogowano") }
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            library.save()
            status = ""
            lastError = error.localizedDescription
            if case FilmwebSession.SessionError.notLoggedIn = error {
                filmweb = .loggedOut
            } else {
                scheduleRetry()
            }
        }
    }

    /// Po nieudanej synchronizacji (np. brak sieci po wybudzeniu): ponów za 5, 15, 60 minut.
    private func scheduleRetry() {
        let delays: [TimeInterval] = [5 * 60, 15 * 60, 60 * 60]
        guard retryAttempt < delays.count else { return }
        let delay = delays[retryAttempt]
        retryAttempt += 1
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await self?.syncIfDue()
        }
    }

    // MARK: - Ikony

    /// Logotypy serwisów i favikony linków — od razu, bez czekania na nocną synchronizację.
    func refreshIcons() async {
        if await IconFetcher.refreshFavicons(for: LinkStore.load()) {
            objectWillChange.send()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // MARK: - Filmweb

    func checkFilmweb() async {
        filmweb = .checking
        switch await FilmwebSession.shared.checkLogin() {
        case .loggedIn(let name): filmweb = .loggedIn(name)
        case .loggedOut: filmweb = .loggedOut
        case .unknown(let reason): filmweb = .unknown(reason)
        }
        if !isSyncing { FilmwebSession.shared.suspend() }
    }

    func logOutOfFilmweb() async {
        await FilmwebSession.shared.logOut()
        filmweb = .loggedOut
    }

    // MARK: - Harmonogram

    private func scheduleMidnightSync() {
        midnightTask?.cancel()
        midnightTask = Task { [weak self] in
            while !Task.isCancelled {
                let next = Calendar.current.nextDate(
                    after: .now, matching: DateComponents(hour: 0, minute: 1), matchingPolicy: .nextTime
                ) ?? .now.addingTimeInterval(24 * 3600)
                try? await Task.sleep(for: .seconds(max(60, next.timeIntervalSinceNow)))
                guard !Task.isCancelled else { return }
                await self?.syncIfDue()
            }
        }
    }

    private func observeSystem() {
        let workspace = NSWorkspace.shared.notificationCenter
        observers.append(workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            // Po wybudzeniu sieć wstaje chwilę później.
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(30))
                self?.scheduleMidnightSync()
                await self?.syncIfDue()
            }
        })
        // Zmiana dnia, strefy czasowej albo zegara — przelicz, kiedy jest północ.
        for name in [Notification.Name.NSCalendarDayChanged, .NSSystemTimeZoneDidChange, .NSSystemClockDidChange] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.scheduleMidnightSync()
                    await self?.syncIfDue()
                }
            })
        }
        observers.append(NotificationCenter.default.addObserver(forName: .movieDeskSyncRequested, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in await self?.sync() }
        })
    }

    // MARK: - Start przy logowaniu

    var launchesAtLogin: Bool { launchStatus == .enabled }

    func refreshLaunchStatus() {
        launchStatus = SMAppService.mainApp.status
    }

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
        refreshLaunchStatus()
        if launchStatus == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
    }
}
