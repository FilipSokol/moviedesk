import AppIntents
import WidgetKit

/// Ustawienia widgetów z propozycjami („Edytuj widżet”).
struct DeskConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Ustawienia propozycji"
    static let description = IntentDescription("Wybierz, co ma pokazywać widget.")

    @Parameter(title: "Rodzaj", default: .all)
    var media: MediaFilter

    @Parameter(title: "Źródło", default: .all)
    var source: SourceFilter

    @Parameter(title: "Serwis", default: .all)
    var service: ServiceFilter

    init() {}

    var filter: PickFilter { PickFilter(media: media, source: source, service: service) }
}

/// „Inny” — zamienia jeden tytuł na kolejny.
struct NextPickIntent: AppIntent {
    static let title: LocalizedStringResource = "Następna propozycja"
    static var isDiscoverable: Bool { false }

    @Parameter(title: "Pas") var laneKey: String
    @Parameter(title: "Miejsce") var slot: Int
    @Parameter(title: "Tytuł") var pickID: String

    init() {}

    init(lane: DeskLane, slot: Int, pickID: String) {
        self.laneKey = lane.key
        self.slot = slot
        self.pickID = pickID
    }

    func perform() async throws -> some IntentResult {
        if let lane = DeskLane(key: laneKey) {
            DeskActions.next(lane, slot: slot, pickID: pickID)
        }
        return .result()
    }
}

/// „Pokaż kolejne” — zamienia wszystkie widoczne tytuły.
struct ShuffleLaneIntent: AppIntent {
    static let title: LocalizedStringResource = "Pokaż kolejne"
    static var isDiscoverable: Bool { false }

    @Parameter(title: "Pas") var laneKey: String

    init() {}

    init(lane: DeskLane) {
        self.laneKey = lane.key
    }

    func perform() async throws -> some IntentResult {
        if let lane = DeskLane(key: laneKey) {
            DeskActions.shuffle(lane)
        }
        return .result()
    }
}

/// Kliknięcie w tytuł z kolejki „Dalej” — przenosi go na główne miejsce.
struct JumpToPickIntent: AppIntent {
    static let title: LocalizedStringResource = "Pokaż ten tytuł"
    static var isDiscoverable: Bool { false }

    @Parameter(title: "Pas") var laneKey: String
    @Parameter(title: "Tytuł") var pickID: String

    init() {}

    init(lane: DeskLane, pickID: String) {
        self.laneKey = lane.key
        self.pickID = pickID
    }

    func perform() async throws -> some IntentResult {
        if let lane = DeskLane(key: laneKey) {
            DeskActions.jump(lane, to: pickID)
        }
        return .result()
    }
}

/// „Nie pokazuj więcej”.
struct HidePickIntent: AppIntent {
    static let title: LocalizedStringResource = "Nie pokazuj więcej"
    static var isDiscoverable: Bool { false }

    @Parameter(title: "Pas") var laneKey: String
    @Parameter(title: "Miejsce") var slot: Int
    @Parameter(title: "Tytuł") var pickID: String

    init() {}

    init(lane: DeskLane, slot: Int, pickID: String) {
        self.laneKey = lane.key
        self.slot = slot
        self.pickID = pickID
    }

    func perform() async throws -> some IntentResult {
        if let lane = DeskLane(key: laneKey) {
            DeskActions.hide(lane, slot: slot, pickID: pickID)
        }
        // Ukryty tytuł znika ze wszystkich widgetów, nie tylko z tego.
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// „Cofnij” po ukryciu.
struct UndoHideIntent: AppIntent {
    static let title: LocalizedStringResource = "Cofnij"
    static var isDiscoverable: Bool { false }

    @Parameter(title: "Pas") var laneKey: String

    init() {}

    init(lane: DeskLane) {
        self.laneKey = lane.key
    }

    func perform() async throws -> some IntentResult {
        if let lane = DeskLane(key: laneKey) {
            DeskActions.undoHide(lane)
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// „Zapisz na później” — przełącznik; system od razu pokazuje nowy stan ikony.
struct SetSavedIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Zapisz na później"
    static var isDiscoverable: Bool { false }

    @Parameter(title: "Tytuł") var pickID: String
    @Parameter(title: "Zapisane") var value: Bool

    init() {}

    init(pickID: String) {
        self.pickID = pickID
    }

    func perform() async throws -> some IntentResult {
        DeskActions.setSaved(pickID: pickID, value)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
