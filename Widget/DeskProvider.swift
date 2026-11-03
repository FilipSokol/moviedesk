import SwiftUI
import WidgetKit

struct DeskEntry: TimelineEntry {
    enum Status: Equatable {
        case ok
        /// Jeszcze nie było synchronizacji.
        case noData
        /// Widget nie widzi kontenera App Group (zła konfiguracja podpisu).
        case noAppGroup
        /// Ustawienia widgetu niczego nie przepuszczają.
        case filteredEmpty
    }

    var date: Date
    var lane: DeskLane
    var status: Status
    var slots: [Pick] = []
    var upNext: [Pick] = []
    var position = 0
    var total = 0
    var canAdvance = false
    var savedIDs: Set<String> = []
    var event: LaneEvent? = nil
    var tapCounter = 0
    var links: [QuickLink] = []
    var snapshotDate: Date = .distantPast
    var scenario: Scenario = .forMe
    /// Czy przycisk scenariusza ma dokąd przełączyć.
    var canSwitchScenario = false

    var hero: Pick? { slots.first }

    /// „Ukryto · Cofnij” widać kilka sekund po ukryciu.
    var showsUndo: Bool {
        guard let event, event.kind == .hide else { return false }
        return date < event.at.addingTimeInterval(DeskActions.undoWindow)
    }

    /// Liczba dni, od kiedy pula nie była odświeżana (gdy > 1,5 doby).
    var staleDays: Int? {
        guard status == .ok, snapshotDate > .distantPast else { return nil }
        let hours = date.timeIntervalSince(snapshotDate) / 3600
        return hours > 36 ? max(2, Int(hours / 24)) : nil
    }

    func isSaved(_ pick: Pick) -> Bool { savedIDs.contains(pick.id) }
}

extension DeskEntry {
    static func make(kind: DeskKind, filter: PickFilter, date: Date) -> DeskEntry {
        let lane = DeskLane(kind: kind, filter: filter)
        var entry = DeskEntry(date: date, lane: lane, status: .ok, links: LinkStore.load())
        guard PicksStore.containerURL != nil else {
            entry.status = .noAppGroup
            return entry
        }
        let snapshot = PicksStore.load()
        let state = StateStore.load()
        entry.tapCounter = state.tapCounter
        entry.savedIDs = state.savedIDs
        entry.snapshotDate = snapshot.generatedAt

        guard !snapshot.picks.isEmpty || !state.saved.isEmpty else {
            entry.status = .noData
            return entry
        }
        let scenario = state.scenario(for: lane)
        let available = LaneResolver.availableScenarios(snapshot: snapshot, state: state, filter: filter)
        entry.scenario = scenario
        entry.canSwitchScenario = available.contains { $0 != scenario }

        let eligible = LaneResolver.eligible(snapshot: snapshot, state: state, filter: filter, scenario: scenario)
        guard !eligible.isEmpty else {
            entry.status = .filteredEmpty
            return entry
        }

        let ids = eligible.map(\.id)
        let laneState = LaneResolver.materialize(
            state.lanes[lane.trackKey(scenario)], ids: ids, snapshotID: snapshot.generatedAt, kind: kind
        )
        let byID = Dictionary(eligible.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        entry.slots = laneState.slots.compactMap { byID[$0] }
        entry.upNext = LaneResolver.upNext(laneState, ids: ids, count: kind.upNextCount).compactMap { byID[$0] }
        entry.position = min(max(laneState.seen.count, entry.slots.count), ids.count)
        entry.total = ids.count
        entry.canAdvance = LaneResolver.canAdvance(ids: ids, kind: kind)
        entry.event = laneState.event
        return entry
    }

    static func sample(kind: DeskKind) -> DeskEntry {
        DeskEntry(
            date: .now,
            lane: DeskLane(kind: kind, filter: .all),
            status: .ok,
            slots: Array(Pick.samples.prefix(kind.capacity)),
            upNext: Array(Pick.samples.dropFirst(kind.capacity).prefix(kind.upNextCount)),
            position: kind.capacity,
            total: Pick.samples.count,
            canAdvance: true,
            links: QuickLink.defaults,
            snapshotDate: .now,
            canSwitchScenario: true
        )
    }
}

/// Wspólny dostawca dla widgetów z propozycjami. Nigdy nie zapisuje stanu — tylko czyta;
/// zapisują intencje i aplikacja.
struct DeskProvider: AppIntentTimelineProvider {
    let kind: DeskKind

    func placeholder(in context: Context) -> DeskEntry {
        .sample(kind: kind)
    }

    func snapshot(for configuration: DeskConfigurationIntent, in context: Context) async -> DeskEntry {
        let entry = DeskEntry.make(kind: kind, filter: configuration.filter, date: .now)
        return context.isPreview && entry.status != .ok ? .sample(kind: kind) : entry
    }

    func timeline(for configuration: DeskConfigurationIntent, in context: Context) async -> Timeline<DeskEntry> {
        let now = Date()
        let first = DeskEntry.make(kind: kind, filter: configuration.filter, date: now)

        var dates: [Date] = [now]
        // Wpis, w którym znika „Cofnij”.
        if first.showsUndo, let at = first.event?.at {
            dates.append(at.addingTimeInterval(DeskActions.undoWindow + 0.5))
        }
        // „Skończysz ok. …” — co kwadrans przez 2 godziny (pojedynczy tytuł widać w hero i tablicy).
        if kind != .shelf, first.status == .ok {
            dates += (1...8).map { now.addingTimeInterval(Double($0) * 900) }
        }
        let entries = dates.sorted().map { date -> DeskEntry in
            var entry = first
            entry.date = date
            return entry
        }

        let afterMidnight = Calendar.current.nextDate(
            after: now, matching: DateComponents(hour: 0, minute: 30), matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(24 * 3600)
        let refresh = min(afterMidnight, (entries.last?.date ?? now).addingTimeInterval(900))
        return Timeline(entries: entries, policy: .after(refresh))
    }
}

extension Pick {
    /// Przykładowe dane do galerii widżetów (bez prawdziwych plakatów).
    static let samples: [Pick] = [
        Pick(tmdbID: 1, media: .film, title: "Diuna: Część druga",
             overview: "Paul Atryda jednoczy się z Fremenami, by pomścić zagładę swojej rodziny.",
             rating: Rating(value: 8.1, source: .imdb), service: .hboMax,
             openURL: URL(string: "https://play.hbomax.com")!, kind: .discovery, posterFile: nil,
             year: 2024, genres: ["Sci-Fi"], runtimeMinutes: 166, reason: "Interstellar"),
        Pick(tmdbID: 2, media: .film, title: "Incepcja",
             overview: "Złodziej kradnący sekrety ze snów dostaje zadanie odwrotne: zaszczepić ideę.",
             rating: Rating(value: 8.3, source: .filmweb), service: .netflix,
             openURL: URL(string: "https://www.netflix.com")!, kind: .rewatch, posterFile: nil,
             year: 2010, genres: ["Thriller"], runtimeMinutes: 148),
        Pick(tmdbID: 3, media: .serial, title: "Rozdzielenie",
             overview: "Pracownicy korporacji chirurgicznie oddzielają wspomnienia z pracy od życia prywatnego.",
             rating: Rating(value: 8.7, source: .imdb), service: .appleTV,
             openURL: URL(string: "https://tv.apple.com")!, kind: .wanted, posterFile: nil,
             year: 2022, genres: ["Dramat"], runtimeMinutes: 50, seasons: 2),
        Pick(tmdbID: 4, media: .film, title: "Arrival",
             rating: Rating(value: 7.9, source: .imdb), service: .primeVideo,
             openURL: URL(string: "https://www.primevideo.com")!, kind: .discovery, posterFile: nil,
             year: 2016, genres: ["Sci-Fi"], runtimeMinutes: 116, reason: "Interstellar"),
        Pick(tmdbID: 5, media: .serial, title: "The Bear",
             rating: Rating(value: 8.5, source: .imdb), service: .disneyPlus,
             openURL: URL(string: "https://www.disneyplus.com")!, kind: .discovery, posterFile: nil,
             year: 2022, genres: ["Komedia"], runtimeMinutes: 30, seasons: 4, reason: "Whiplash"),
        Pick(tmdbID: 6, media: .film, title: "Whiplash",
             rating: Rating(value: 8.4, source: .filmweb), service: .netflix,
             openURL: URL(string: "https://www.netflix.com")!, kind: .rewatch, posterFile: nil,
             year: 2014, genres: ["Dramat"], runtimeMinutes: 106),
        Pick(tmdbID: 7, media: .film, title: "Drive",
             rating: Rating(value: 7.8, source: .imdb), service: .hboMax,
             openURL: URL(string: "https://play.hbomax.com")!, kind: .wanted, posterFile: nil,
             year: 2011, genres: ["Kryminał"], runtimeMinutes: 100),
    ]
}
