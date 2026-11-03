import AppIntents
import Foundation

enum MediaFilter: String, AppEnum, Codable {
    case all, films, series

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Rodzaj"
    static let caseDisplayRepresentations: [MediaFilter: DisplayRepresentation] = [
        .all: "Wszystko",
        .films: "Filmy",
        .series: "Seriale",
    ]
}

enum SourceFilter: String, AppEnum, Codable {
    case all, discovery, wanted, rewatch, saved

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Źródło"
    static let caseDisplayRepresentations: [SourceFilter: DisplayRepresentation] = [
        .all: "Wszystko",
        .discovery: "W Twoim guście",
        .wanted: "Z listy „Chcę zobaczyć”",
        .rewatch: "Do powtórki",
        .saved: "Zapisane",
    ]
}

enum ServiceFilter: String, AppEnum, Codable {
    case all, netflix, hboMax, primeVideo, disneyPlus, skyShowtime, appleTV, canalPlus, player, polsatBoxGo

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Serwis"
    static let caseDisplayRepresentations: [ServiceFilter: DisplayRepresentation] = [
        .all: "Wszystkie",
        .netflix: "Netflix",
        .hboMax: "HBO Max",
        .primeVideo: "Prime Video",
        .disneyPlus: "Disney+",
        .skyShowtime: "SkyShowtime",
        .appleTV: "Apple TV+",
        .canalPlus: "Canal+",
        .player: "Player",
        .polsatBoxGo: "Polsat Box Go",
    ]

    var service: StreamingService? { StreamingService(rawValue: rawValue) }
}

struct PickFilter: Hashable {
    var media: MediaFilter = .all
    var source: SourceFilter = .all
    var service: ServiceFilter = .all

    static let all = PickFilter()

    func matches(_ pick: Pick, savedIDs: Set<String>) -> Bool {
        switch media {
        case .all: break
        case .films: guard pick.media == .film else { return false }
        case .series: guard pick.media == .serial else { return false }
        }
        switch source {
        case .all: break
        case .discovery: guard pick.kind == .discovery else { return false }
        case .wanted: guard pick.kind == .wanted else { return false }
        case .rewatch: guard pick.kind == .rewatch else { return false }
        case .saved: guard savedIDs.contains(pick.id) else { return false }
        }
        if let service = service.service, pick.service != service { return false }
        return true
    }

    /// Krótki opis dla nagłówka, np. „Seriale · Netflix”; `nil` dla ustawień domyślnych.
    var summary: String? {
        var parts: [String] = []
        if media != .all { parts.append(media == .films ? "Filmy" : "Seriale") }
        switch source {
        case .all: break
        case .discovery: parts.append("W Twoim guście")
        case .wanted: parts.append("Chcę zobaczyć")
        case .rewatch: parts.append("Do powtórki")
        case .saved: parts.append("Zapisane")
        }
        if let service = service.service { parts.append(service.displayName) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// Rodzaj widgetu — ile tytułów pokazuje naraz i od którego miejsca puli zaczyna,
/// żeby kilka widgetów z domyślnymi ustawieniami nie pokazywało tego samego.
enum DeskKind: String, Codable {
    case hero, shelf, board

    var capacity: Int { self == .shelf ? 3 : 1 }
    var upNextCount: Int {
        switch self {
        case .hero: 3
        case .shelf: 0
        case .board: 4
        }
    }
    var defaultOffset: Int {
        switch self {
        case .shelf: 0
        case .hero: 3
        case .board: 6
        }
    }
}

/// „Pas” = rodzaj widgetu + ustawienia. Widgety o tych samych ustawieniach przewijają się razem.
struct DeskLane: Hashable {
    var kind: DeskKind
    var filter: PickFilter

    /// Pas panelu w pasku menu — ten sam co domyślna półka.
    static let panel = DeskLane(kind: .shelf, filter: .all)

    var key: String {
        [kind.rawValue, filter.media.rawValue, filter.source.rawValue, filter.service.rawValue].joined(separator: "|")
    }

    init(kind: DeskKind, filter: PickFilter) {
        self.kind = kind
        self.filter = filter
    }

    init?(key: String) {
        let parts = key.split(separator: "|").map(String.init)
        guard parts.count == 4,
              let kind = DeskKind(rawValue: parts[0]),
              let media = MediaFilter(rawValue: parts[1]),
              let source = SourceFilter(rawValue: parts[2]),
              let service = ServiceFilter(rawValue: parts[3])
        else { return nil }
        self.init(kind: kind, filter: PickFilter(media: media, source: source, service: service))
    }
}
