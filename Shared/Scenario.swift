import AppIntents
import Foundation

/// Scenariusz propozycji — przełączany przyciskami w widgecie albo w panelu.
///
/// Nazwy są krótkie, bo stoją na małych przyciskach; szczegóły mówi podtytuł.
enum Scenario: String, Codable, CaseIterable, Sendable, AppEnum {
    /// Twój gust, tylko Twoje serwisy VOD.
    case forMe
    /// Nowe filmy w Twoim guście, już wydane cyfrowo/na płytach — do kupienia (linki do Google).
    case toBuy
    /// Na wieczór we dwoje — bez horrorów i krwawych scen, na Twoich serwisach VOD.
    case together
    /// Jak wyżej, ale wszystkie filmy, niezależnie od serwisu.
    case togetherAnywhere

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Scenariusz"
    static let caseDisplayRepresentations: [Scenario: DisplayRepresentation] = [
        .forMe: DisplayRepresentation(title: "Solo", subtitle: "Twój gust, Twoje serwisy"),
        .toBuy: DisplayRepresentation(title: "Premiery HD", subtitle: "Świeże filmy już na Blu-ray i w wersji cyfrowej"),
        .together: DisplayRepresentation(title: "Randka", subtitle: "We dwoje, do włączenia od razu"),
        .togetherAnywhere: DisplayRepresentation(title: "Wspólna lista", subtitle: "We dwoje, gdziekolwiek są"),
    ]

    var title: String {
        switch self {
        case .forMe: "Solo"
        case .toBuy: "Premiery HD"
        case .together: "Randka"
        case .togetherAnywhere: "Wspólna lista"
        }
    }

    var subtitle: String {
        switch self {
        case .forMe: "Twój gust, Twoje serwisy"
        case .toBuy: "Świeże filmy już na Blu-ray i w wersji cyfrowej"
        case .together: "We dwoje, do włączenia od razu"
        case .togetherAnywhere: "We dwoje, gdziekolwiek są"
        }
    }

    var symbol: String {
        switch self {
        case .forMe: "person.fill"
        case .toBuy: "opticaldisc.fill"
        case .together: "heart.fill"
        case .togetherAnywhere: "heart.text.square.fill"
        }
    }

    var next: Scenario {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }

    /// Czy propozycje muszą być na Twoich serwisach VOD.
    var requiresVOD: Bool { self == .forMe || self == .together }
}
