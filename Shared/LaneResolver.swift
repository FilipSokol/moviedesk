import Foundation

/// Czysta logika „co pokazuje pas”. Bez plików i bez sieci — ten sam wynik w widgecie,
/// w intencji i w aplikacji, więc wszyscy widzą to samo.
enum LaneResolver {
    /// Tytuły, które pas może pokazać w danym scenariuszu: pula + zapisane spoza puli,
    /// bez ukrytych, po filtrze, bez powtórzeń (ten sam film bywa w kilku scenariuszach).
    static func eligible(snapshot: PicksSnapshot, state: DeskState, filter: PickFilter, scenario: Scenario) -> [Pick] {
        var pool = snapshot.picks
        let inPool = Set(pool.map(\.id))
        pool += state.saved.values
            .sorted { $0.at > $1.at }
            .map(\.pick)
            .filter { !inPool.contains($0.id) }
        let savedIDs = state.savedIDs
        var seen = Set<String>()
        return pool.filter {
            state.dismissed[$0.id] == nil
                && filter.matches($0, savedIDs: savedIDs, scenario: scenario)
                && seen.insert($0.id).inserted
        }
    }

    /// Scenariusze, w których ten pas ma cokolwiek do pokazania.
    static func availableScenarios(snapshot: PicksSnapshot, state: DeskState, filter: PickFilter) -> [Scenario] {
        Scenario.allCases.filter { !eligible(snapshot: snapshot, state: state, filter: filter, scenario: $0).isEmpty }
    }

    /// Doprowadza zapisany stan pasa do zgodności z aktualną pulą. Nowa pula → pas od nowa
    /// (z przesunięciem zależnym od rodzaju widgetu); ta sama pula → niedostępne miejsca
    /// uzupełniane kolejnymi tytułami.
    static func materialize(_ stored: LaneState?, ids: [String], snapshotID: Date, kind: DeskKind) -> LaneState {
        guard var lane = stored, lane.snapshotID == snapshotID else {
            let offset = ids.isEmpty ? 0 : kind.defaultOffset % ids.count
            let rotated = Array(ids[offset...] + ids[..<offset])
            let slots = Array(rotated.prefix(kind.capacity))
            return LaneState(snapshotID: snapshotID, slots: slots, seen: slots, revision: stored?.revision ?? 0, event: nil)
        }
        let available = Set(ids)
        var slots: [String] = []
        for id in lane.slots {
            if available.contains(id), !slots.contains(id) {
                slots.append(id)
            } else if case let exclude = slots + lane.slots, let next = takeNext(&lane, ids: ids, excluding: exclude) {
                slots.append(next)
            }
        }
        while slots.count < kind.capacity, let next = takeNext(&lane, ids: ids, excluding: slots) {
            slots.append(next)
        }
        lane.slots = slots
        return lane
    }

    /// Następne w kolejce (jeszcze nie widziane); gdy pula się skończy — od początku.
    private static func takeNext(_ lane: inout LaneState, ids: [String], excluding current: [String]) -> String? {
        if let id = ids.first(where: { !lane.seen.contains($0) && !current.contains($0) }) {
            lane.seen.append(id)
            return id
        }
        guard let id = ids.first(where: { !current.contains($0) }) else { return nil }
        lane.seen = current + [id]
        return id
    }

    /// Kolejka „Dalej” bez zmieniania stanu.
    static func upNext(_ lane: LaneState, ids: [String], count: Int) -> [String] {
        guard count > 0 else { return [] }
        let unseen = ids.filter { !lane.seen.contains($0) && !lane.slots.contains($0) }
        let rest = ids.filter { !lane.slots.contains($0) && !unseen.contains($0) }
        return Array((unseen + rest).prefix(count))
    }

    /// Czy jest co przewijać (więcej tytułów niż miejsc).
    static func canAdvance(ids: [String], kind: DeskKind) -> Bool {
        ids.count > kind.capacity
    }

    // MARK: - Akcje

    /// Zamienia jeden tytuł. `expected` chroni przed podwójnym kliknięciem w nieodświeżony widget.
    static func next(_ lane: inout LaneState, ids: [String], slot: Int, expected: String) {
        let current = lane.slots
        guard current.indices.contains(slot), current[slot] == expected,
              let replacement = takeNext(&lane, ids: ids, excluding: current)
        else { return }
        lane.slots[slot] = replacement
        lane.event = LaneEvent(kind: .next, slot: slot, pickID: replacement, at: .now)
    }

    /// Zamienia wszystkie widoczne tytuły.
    static func shuffle(_ lane: inout LaneState, ids: [String], kind: DeskKind) {
        guard canAdvance(ids: ids, kind: kind) else { return }
        let old = lane.slots
        var fresh: [String] = []
        for _ in 0..<max(old.count, min(kind.capacity, ids.count)) {
            guard let next = takeNext(&lane, ids: ids, excluding: old + fresh) else { break }
            fresh.append(next)
        }
        guard !fresh.isEmpty else { return }
        lane.slots = fresh
        lane.event = LaneEvent(kind: .shuffle, slot: nil, pickID: nil, at: .now)
    }

    /// Przenosi wybrany tytuł z kolejki na główne miejsce.
    static func jump(_ lane: inout LaneState, ids: [String], to pickID: String) {
        guard ids.contains(pickID), lane.slots.first != pickID else { return }
        if !lane.seen.contains(pickID) { lane.seen.append(pickID) }
        if let existing = lane.slots.firstIndex(of: pickID) {
            lane.slots.swapAt(0, existing)
        } else if lane.slots.isEmpty {
            lane.slots = [pickID]
        } else {
            lane.slots[0] = pickID
        }
        lane.event = LaneEvent(kind: .jump, slot: 0, pickID: pickID, at: .now)
    }
}

/// Zapis akcji do wspólnego stanu (pod blokadą) + powiadomienie panelu.
/// Wołane z intencji widgetów i z aplikacji.
enum DeskActions {
    static let undoWindow: TimeInterval = 8

    private static func update(_ lane: DeskLane, _ change: (inout LaneState, [String], inout DeskState, PicksSnapshot) -> Void) {
        let snapshot = PicksStore.load()
        StateStore.mutate { state in
            let scenario = state.scenario(for: lane)
            let ids = LaneResolver.eligible(snapshot: snapshot, state: state, filter: lane.filter, scenario: scenario).map(\.id)
            var laneState = LaneResolver.materialize(
                state.lanes[lane.trackKey(scenario)], ids: ids, snapshotID: snapshot.generatedAt, kind: lane.kind
            )
            change(&laneState, ids, &state, snapshot)
            laneState.revision += 1
            state.lanes[lane.trackKey(scenario)] = laneState
        }
        DeskNotifier.post()
    }

    /// Przełącza na następny scenariusz, w którym jest coś do pokazania.
    static func cycleScenario(_ lane: DeskLane) {
        let snapshot = PicksStore.load()
        StateStore.mutate { state in
            let current = state.scenario(for: lane)
            let available = LaneResolver.availableScenarios(snapshot: snapshot, state: state, filter: lane.filter)
            var candidate = current.next
            for _ in 0..<Scenario.allCases.count {
                if available.contains(candidate) || available.isEmpty { break }
                candidate = candidate.next
            }
            switchScenario(&state, lane: lane, to: candidate, snapshot: snapshot)
        }
        DeskNotifier.post()
    }

    static func setScenario(_ lane: DeskLane, _ scenario: Scenario) {
        let snapshot = PicksStore.load()
        StateStore.mutate { state in
            switchScenario(&state, lane: lane, to: scenario, snapshot: snapshot)
        }
        DeskNotifier.post()
    }

    private static func switchScenario(_ state: inout DeskState, lane: DeskLane, to scenario: Scenario, snapshot: PicksSnapshot) {
        var scenarios = state.scenarios ?? [:]
        scenarios[lane.key] = scenario
        state.scenarios = scenarios
        // Zdarzenie w pasie nowego scenariusza — plakaty wejdą z rozmyciem zamiast przesunięcia.
        let ids = LaneResolver.eligible(snapshot: snapshot, state: state, filter: lane.filter, scenario: scenario).map(\.id)
        var laneState = LaneResolver.materialize(
            state.lanes[lane.trackKey(scenario)], ids: ids, snapshotID: snapshot.generatedAt, kind: lane.kind
        )
        laneState.event = LaneEvent(kind: .scenario, slot: nil, pickID: nil, at: .now)
        laneState.revision += 1
        state.lanes[lane.trackKey(scenario)] = laneState
    }

    static func next(_ lane: DeskLane, slot: Int, pickID: String) {
        update(lane) { laneState, ids, _, _ in
            LaneResolver.next(&laneState, ids: ids, slot: slot, expected: pickID)
        }
    }

    static func shuffle(_ lane: DeskLane) {
        update(lane) { laneState, ids, state, _ in
            LaneResolver.shuffle(&laneState, ids: ids, kind: lane.kind)
            state.tapCounter += 1
        }
    }

    static func jump(_ lane: DeskLane, to pickID: String) {
        update(lane) { laneState, ids, _, _ in
            LaneResolver.jump(&laneState, ids: ids, to: pickID)
        }
    }

    /// Ukrywa tytuł na stałe (albo jako obejrzany) i od razu wstawia następny w to samo miejsce.
    static func hide(_ lane: DeskLane, slot: Int, pickID: String, reason: Dismissal.Reason = .notInterested) {
        update(lane) { laneState, _, state, snapshot in
            state.dismissed[pickID] = Dismissal(reason: reason, at: .now)
            state.saved[pickID] = nil
            let scenario = state.scenario(for: lane)
            let ids = LaneResolver.eligible(snapshot: snapshot, state: state, filter: lane.filter, scenario: scenario).map(\.id)
            laneState = LaneResolver.materialize(laneState, ids: ids, snapshotID: snapshot.generatedAt, kind: lane.kind)
            laneState.event = LaneEvent(kind: .hide, slot: slot, pickID: pickID, at: .now)
        }
    }

    /// Cofa ostatnie ukrycie w tym pasie (przez kilka sekund po kliknięciu).
    static func undoHide(_ lane: DeskLane) {
        update(lane) { laneState, _, state, _ in
            guard let event = laneState.event, event.kind == .hide,
                  let pickID = event.pickID, let slot = event.slot,
                  Date().timeIntervalSince(event.at) < 60
            else { return }
            state.dismissed[pickID] = nil
            if laneState.slots.indices.contains(slot) {
                let filler = laneState.slots[slot]
                laneState.seen.removeAll { $0 == filler }
                laneState.slots[slot] = pickID
            } else {
                laneState.slots.append(pickID)
            }
            laneState.event = LaneEvent(kind: .undo, slot: slot, pickID: pickID, at: .now)
        }
    }

    static func setSaved(pickID: String, _ isSaved: Bool) {
        let snapshot = PicksStore.load()
        StateStore.mutate { state in
            if isSaved {
                guard let pick = state.saved[pickID]?.pick ?? snapshot.picks.first(where: { $0.id == pickID }) else { return }
                state.saved[pickID] = SavedPick(pick: pick, at: .now)
            } else {
                state.saved[pickID] = nil
            }
        }
        DeskNotifier.post()
    }

    static func restore(_ pickID: String) {
        StateStore.mutate { state in state.dismissed[pickID] = nil }
        DeskNotifier.post()
    }
}
