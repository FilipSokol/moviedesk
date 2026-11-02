import AppKit
import Foundation

/// Jedna propozycja filmu. Aplikacja ją przygotowuje, widget tylko wyświetla.
struct Pick: Codable, Hashable, Identifiable {
    enum Kind: String, Codable {
        /// Nowy film dopasowany do ocen.
        case discovery
        /// Film oceniony wysoko ponad 5 lat temu — do obejrzenia ponownie.
        case rewatch
    }

    /// Identyfikator filmu w TMDB.
    var id: Int
    var title: String
    var service: StreamingService
    var openURL: URL
    var kind: Kind
    /// Nazwa pliku plakatu w katalogu `Posters` kontenera App Group.
    var posterFile: String?
}

struct PicksSnapshot: Codable {
    var generatedAt: Date
    var picks: [Pick]

    static let empty = PicksSnapshot(generatedAt: .distantPast, picks: [])
}

/// Pula propozycji + kursor „która trójka jest teraz widoczna”, współdzielone przez App Group.
enum PicksStore {
    static let pageSize = 3
    private static let cursorKey = "picks.cursor"

    static var containerURL: URL? {
        AppGroup.identifier.flatMap {
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0)
        }
    }

    static var postersDirectory: URL? {
        containerURL?.appendingPathComponent("Posters", isDirectory: true)
    }

    private static var snapshotURL: URL? {
        containerURL?.appendingPathComponent("picks.json")
    }

    static func load() -> PicksSnapshot {
        guard let url = snapshotURL,
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(PicksSnapshot.self, from: data)
        else { return .empty }
        return snapshot
    }

    /// Zapisuje nową pulę i wraca do pierwszej trójki.
    static func save(_ snapshot: PicksSnapshot) {
        guard let url = snapshotURL, let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
        cursor = 0
    }

    static var cursor: Int {
        get { AppGroup.defaults.integer(forKey: cursorKey) }
        set { AppGroup.defaults.set(newValue, forKey: cursorKey) }
    }

    static func advance() {
        cursor += pageSize
    }

    /// Trzy propozycje dla danego kursora; po dojściu do końca puli zaczyna od początku.
    static func page(of snapshot: PicksSnapshot, cursor: Int) -> [Pick] {
        let picks = snapshot.picks
        guard !picks.isEmpty else { return [] }
        let start = cursor % picks.count
        return (0..<min(pageSize, picks.count)).map { picks[(start + $0) % picks.count] }
    }

    static func posterURL(for pick: Pick) -> URL? {
        guard let file = pick.posterFile else { return nil }
        return postersDirectory?.appendingPathComponent(file)
    }

    static func posterImage(for pick: Pick) -> NSImage? {
        posterURL(for: pick).flatMap(NSImage.init(contentsOf:))
    }
}
