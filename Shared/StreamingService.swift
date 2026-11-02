import SwiftUI

/// Serwisy, na których szukamy filmów. Dostępność bierzemy z TMDB `watch/providers` (region PL).
enum StreamingService: String, Codable, CaseIterable, Identifiable {
    case netflix, hboMax, primeVideo, disneyPlus

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .netflix: "Netflix"
        case .hboMax: "HBO Max"
        case .primeVideo: "Prime Video"
        case .disneyPlus: "Disney+"
        }
    }

    var tint: Color {
        switch self {
        case .netflix: .red
        case .hboMax: .indigo
        case .primeVideo: .cyan
        case .disneyPlus: .blue
        }
    }

    /// Dopasowanie po nazwie, bo TMDB ma kilka wariantów (np. „Netflix Standard with Ads”, „Max”).
    func matches(providerName: String) -> Bool {
        let name = providerName.lowercased()
        switch self {
        case .netflix: return name.contains("netflix")
        case .hboMax: return name.contains("hbo max") || name == "max" || name.hasPrefix("max ")
        case .primeVideo: return name.contains("prime video")
        case .disneyPlus: return name.contains("disney")
        }
    }

    /// Strona wyszukiwania serwisu z tytułem filmu. TMDB nie podaje linku do konkretnego
    /// tytułu w serwisie, więc wyszukiwanie to najpewniejszy sposób, żeby trafić w film.
    func searchURL(for title: String) -> URL? {
        guard let query = title.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else { return nil }
        let string: String = switch self {
        case .netflix: "https://www.netflix.com/search?q=\(query)"
        case .hboMax: "https://play.hbomax.com/search?q=\(query)"
        case .primeVideo: "https://www.primevideo.com/search/?phrase=\(query)"
        case .disneyPlus: "https://www.disneyplus.com/search?q=\(query)"
        }
        return URL(string: string)
    }
}
