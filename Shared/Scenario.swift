import AppIntents
import Foundation

/// Scenariusz propozycji — przełączany przyciskiem w widgecie albo w panelu.
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
        .forMe: "Dla mnie",
        .toBuy: "Do kupienia",
        .together: "We dwoje · VOD",
        .togetherAnywhere: "We dwoje · wszystkie",
    ]

    var symbol: String {
        switch self {
        case .forMe: "person.fill"
        case .toBuy: "opticaldisc"
        case .together: "heart.fill"
        case .togetherAnywhere: "heart.circle"
        }
    }

    /// Pełna nazwa; zamiast „We dwoje” może być „Z Asią” (imię z ustawień).
    var title: String {
        switch self {
        case .forMe: "Dla mnie"
        case .toBuy: "Do kupienia"
        case .together: "\(Self.couplePhrase) · VOD"
        case .togetherAnywhere: "\(Self.couplePhrase) · wszystkie"
        }
    }

    /// Krótka nazwa do małych przycisków.
    var shortTitle: String {
        switch self {
        case .forMe: "Dla mnie"
        case .toBuy: "Do kupienia"
        case .together: Self.couplePhrase
        case .togetherAnywhere: "\(Self.couplePhrase) +"
        }
    }

    var next: Scenario {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }

    /// Czy propozycje muszą być na Twoich serwisach VOD.
    var requiresVOD: Bool { self == .forMe || self == .together }

    // MARK: - Imię partnerki (opcjonalne, tylko lokalnie)

    private static let partnerKey = "partner.name"

    static var partnerName: String {
        get { AppGroup.defaults.string(forKey: partnerKey) ?? "" }
        set { AppGroup.defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: partnerKey) }
    }

    private static var couplePhrase: String {
        let name = partnerName
        return name.isEmpty ? "We dwoje" : "Z \(name)"
    }
}
