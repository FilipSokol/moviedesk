import Foundation

/// Stan wspólny dla aplikacji i wszystkich widgetów: co ukryłeś, co zapisałeś,
/// i co aktualnie pokazuje każdy „pas” (widget o danych ustawieniach).
///
/// Leży w pliku w kontenerze App Group, a każdy zapis idzie pod blokadą `flock`,
/// bo piszą do niego dwa procesy (aplikacja i rozszerzenie widgetu).
struct DeskState: Codable {
    var dismissed: [String: Dismissal] = [:]
    var saved: [String: SavedPick] = [:]
    var lanes: [String: LaneState] = [:]
    /// Licznik kliknięć „pokaż kolejne” — tylko rośnie, napędza obrót strzałki.
    var tapCounter = 0
    /// Aktywny scenariusz każdego widgetu (klucz pasa). Opcjonalne, bo starsze pliki go nie mają.
    var scenarios: [String: Scenario]? = nil

    var savedIDs: Set<String> { Set(saved.keys) }

    func scenario(for lane: DeskLane) -> Scenario {
        scenarios?[lane.key] ?? lane.filter.scenario
    }
}

struct Dismissal: Codable, Hashable {
    enum Reason: String, Codable { case notInterested, watched }
    var reason: Reason
    var at: Date
}

struct SavedPick: Codable, Hashable {
    var pick: Pick
    var at: Date
}

struct LaneEvent: Codable, Hashable {
    enum Kind: String, Codable { case next, shuffle, jump, hide, undo, scenario, back }
    var kind: Kind
    var slot: Int?
    var pickID: String?
    var at: Date
}

struct LaneState: Codable, Hashable {
    /// `generatedAt` puli, dla której pas został zbudowany; nowa pula = nowy pas.
    var snapshotID: Date
    /// Widoczne tytuły, w kolejności miejsc.
    var slots: [String]
    /// Pokazane w tej rundzie — żeby nie powtarzać, dopóki pula się nie skończy.
    var seen: [String]
    var revision: Int
    var event: LaneEvent?
    /// Poprzednie układy (do „Cofnij o krok”), najnowszy na końcu; najwyżej 20.
    var history: [[String]]? = nil
    /// Licznik obrotów każdego miejsca: +1 przy „następny”, −1 przy „wstecz”.
    /// Widget obraca kartę o 360° × licznik, więc zmiana o 1 to jeden pełny obrót
    /// (w przód albo w tył). Nie zeruje się przy nowej puli, żeby karty nie kręciły się o północy.
    var flips: [Int]? = nil

    func flip(_ slot: Int) -> Int {
        guard let flips, flips.indices.contains(slot) else { return 0 }
        return flips[slot]
    }

    var canGoBack: Bool { !(history ?? []).isEmpty }
}

enum StateStore {
    private static var url: URL? { PicksStore.containerURL?.appendingPathComponent("state-v1.json") }
    private static var lockURL: URL? { PicksStore.containerURL?.appendingPathComponent("state.lock") }

    static func load() -> DeskState {
        guard let url, let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder().decode(DeskState.self, from: data)
        else { return DeskState() }
        return state
    }

    /// Odczyt–zmiana–zapis pod blokadą międzyprocesową.
    @discardableResult
    static func mutate<T>(_ body: (inout DeskState) -> T) -> T {
        let descriptor = lockURL.map { open($0.path, O_CREAT | O_RDWR, 0o644) } ?? -1
        if descriptor >= 0 { flock(descriptor, LOCK_EX) }
        defer {
            if descriptor >= 0 {
                flock(descriptor, LOCK_UN)
                close(descriptor)
            }
        }
        var state = load()
        let result = body(&state)
        trim(&state)
        if let url, let data = try? JSONEncoder().encode(state) {
            try? data.write(to: url, options: .atomic)
        }
        return result
    }

    /// Limity, żeby plik nie rósł bez końca.
    private static func trim(_ state: inout DeskState) {
        if state.dismissed.count > 2000 {
            let oldest = state.dismissed.sorted { $0.value.at < $1.value.at }.prefix(state.dismissed.count - 2000)
            for (id, _) in oldest { state.dismissed[id] = nil }
        }
        if state.saved.count > 50 {
            let oldest = state.saved.sorted { $0.value.at < $1.value.at }.prefix(state.saved.count - 50)
            for (id, _) in oldest { state.saved[id] = nil }
        }
        if state.lanes.count > 40 {
            let oldest = state.lanes.sorted { $0.value.snapshotID < $1.value.snapshotID }.prefix(state.lanes.count - 40)
            for (key, _) in oldest { state.lanes[key] = nil }
        }
    }
}

/// Powiadomienie „stan się zmienił” między procesami (widget → panel w pasku menu).
enum DeskNotifier {
    static var name: String { (AppGroup.identifier ?? "moviedesk") + ".state" }

    static func post() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(name as CFString), nil, nil, true
        )
    }
}

/// Obserwator powiadomień `DeskNotifier`; wywołuje `handler` na głównym wątku.
final class DeskObserver {
    private let handler: () -> Void

    init(handler: @escaping () -> Void) {
        self.handler = handler
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer else { return }
                let me = Unmanaged<DeskObserver>.fromOpaque(observer).takeUnretainedValue()
                DispatchQueue.main.async { me.handler() }
            },
            DeskNotifier.name as CFString,
            nil,
            .deliverImmediately
        )
    }

    deinit {
        CFNotificationCenterRemoveEveryObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque()
        )
    }
}
