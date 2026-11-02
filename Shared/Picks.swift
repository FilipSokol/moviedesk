import AppKit
import Foundation

struct Rating: Codable, Hashable, Sendable {
    enum Source: String, Codable, Sendable {
        case filmweb, imdb, tmdb

        var shortLabel: String {
            switch self {
            case .filmweb: "FW"
            case .imdb: "IMDb"
            case .tmdb: "TMDB"
            }
        }
    }

    var value: Double
    var source: Source

    /// „7,8” — po polsku, z przecinkiem.
    var formatted: String {
        value.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "pl_PL")))
    }
}

/// Jedna propozycja. Aplikacja ją przygotowuje, widget tylko wyświetla.
struct Pick: Codable, Hashable, Identifiable, Sendable {
    enum Kind: String, Codable, Sendable {
        /// Nowy tytuł dopasowany do Twojego gustu.
        case discovery
        /// Z Twojej listy „Chcę zobaczyć”.
        case wanted
        /// Oceniony wysoko ponad 5 lat temu — do obejrzenia ponownie.
        case rewatch

        var label: String {
            switch self {
            case .discovery: "W Twoim guście"
            case .wanted: "Z listy „Chcę zobaczyć”"
            case .rewatch: "Do powtórki"
            }
        }
    }

    var tmdbID: Int
    var media: MediaKind
    var title: String
    var overview: String?
    var rating: Rating?
    var service: StreamingService
    var openURL: URL
    var kind: Kind
    /// Nazwa pliku plakatu w katalogu `Posters` kontenera App Group.
    var posterFile: String?

    var id: String { "\(media.rawValue)-\(tmdbID)" }
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
        containerURL?.appendingPathComponent("picks-v2.json")
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

    static func posterImage(for pick: Pick) -> NSImage? {
        guard let file = pick.posterFile, let url = postersDirectory?.appendingPathComponent(file) else { return nil }
        return NSImage(contentsOf: url)
    }
}
