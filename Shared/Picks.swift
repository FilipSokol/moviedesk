import SwiftUI

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

        var fullLabel: String {
            switch self {
            case .filmweb: "Filmweb"
            case .imdb: "IMDb"
            case .tmdb: "TMDB"
            }
        }
    }

    var value: Double
    var source: Source

    /// „7,8” — po polsku, z przecinkiem.
    var formatted: String {
        value.formatted(.number.precision(.fractionLength(1)).locale(PickFormatting.polish))
    }
}

/// Jedna propozycja. Aplikacja ją przygotowuje, widget tylko wyświetla.
/// Nowe pola są opcjonalne, więc starsze pliki z pulą nadal się wczytują.
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
    /// Serwis VOD, w którym jest tytuł; `nil` — link prowadzi do wyszukiwarki Google
    /// (scenariusze „Premiery HD” i „Wspólna lista”).
    var service: StreamingService?
    var openURL: URL
    var kind: Kind
    /// Nazwa pliku plakatu w katalogu `Posters` kontenera App Group.
    var posterFile: String?

    var year: Int? = nil
    var genres: [String]? = nil
    /// Film: długość; serial: typowa długość odcinka.
    var runtimeMinutes: Int? = nil
    var seasons: Int? = nil
    var tagline: String? = nil
    /// Nazwa pliku tła w katalogu `Backdrops` kontenera App Group.
    var backdropFile: String? = nil
    /// Tytuł, przez który trafiła ta propozycja („bo lubisz …”) — tylko dla nowych.
    var reason: String? = nil
    /// Scenariusz, do którego należy (starsze pule: „Solo”).
    var scenario: Scenario? = nil
    /// Krótka informacja zamiast „bo lubisz …”, np. „Na Blu-ray/DVD od marca 2025”.
    var note: String? = nil

    var id: String { "\(media.rawValue)-\(tmdbID)" }
    var resolvedScenario: Scenario { scenario ?? .forMe }
    var tint: Color { service?.tint ?? .gray }
    /// „Netflix” albo „Google”.
    var destinationName: String { service?.displayName ?? "Google" }
}

struct PicksSnapshot: Codable {
    var generatedAt: Date
    var picks: [Pick]

    static let empty = PicksSnapshot(generatedAt: .distantPast, picks: [])
}

/// Pula propozycji i obrazki w kontenerze App Group.
enum PicksStore {
    static var containerURL: URL? {
        AppGroup.identifier.flatMap {
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0)
        }
    }

    static var postersDirectory: URL? {
        containerURL?.appendingPathComponent("Posters", isDirectory: true)
    }

    static var iconsDirectory: URL? {
        containerURL?.appendingPathComponent("Icons", isDirectory: true)
    }

    static var logosDirectory: URL? {
        containerURL?.appendingPathComponent("Logos", isDirectory: true)
    }

    static var backdropsDirectory: URL? {
        containerURL?.appendingPathComponent("Backdrops", isDirectory: true)
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

    static func save(_ snapshot: PicksSnapshot) {
        guard let url = snapshotURL, let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Usuwa plakaty i tła, których nie używa ani pula, ani zapisane tytuły.
    /// Wołać dopiero *po* zapisaniu nowej puli, żeby widget nie trafił na brakujące pliki.
    static func cleanUpImages(keeping picks: [Pick]) {
        let posters = Set(picks.compactMap(\.posterFile))
        let backdrops = Set(picks.compactMap(\.backdropFile))
        for (directory, keep) in [(postersDirectory, posters), (backdropsDirectory, backdrops)] {
            guard let directory else { continue }
            let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
            for name in names where !keep.contains(name) {
                try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
            }
        }
    }
}
