import SwiftUI

/// Film albo serial — tak samo na Filmwebie (`film`/`serial`) jak w TMDB (`movie`/`tv`).
enum MediaKind: String, Codable, CaseIterable, Sendable {
    case film, serial

    var tmdbPath: String { self == .film ? "movie" : "tv" }
}

/// Serwisy VOD, które aplikacja rozpoznaje po adresach Twoich linków.
/// Propozycje filtrujemy do serwisów, do których masz link; pozostałe linki
/// (dowolne strony) są po prostu skrótami i niczego nie blokują.
enum StreamingService: String, Codable, CaseIterable, Identifiable, Sendable {
    case netflix, hboMax, primeVideo, disneyPlus, skyShowtime, appleTV, canalPlus, player, polsatBoxGo

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .netflix: "Netflix"
        case .hboMax: "HBO Max"
        case .primeVideo: "Prime Video"
        case .disneyPlus: "Disney+"
        case .skyShowtime: "SkyShowtime"
        case .appleTV: "Apple TV+"
        case .canalPlus: "Canal+"
        case .player: "Player"
        case .polsatBoxGo: "Polsat Box Go"
        }
    }

    var tint: Color {
        switch self {
        case .netflix: .red
        case .hboMax: .indigo
        case .primeVideo: .cyan
        case .disneyPlus: .blue
        case .skyShowtime: .purple
        case .appleTV: .gray
        case .canalPlus: .gray
        case .player: .green
        case .polsatBoxGo: .orange
        }
    }

    /// Domeny, po których rozpoznajemy serwis w linkach.
    private var hosts: [String] {
        switch self {
        case .netflix: ["netflix.com"]
        case .hboMax: ["hbomax.com", "max.com"]
        case .primeVideo: ["primevideo.com"]
        case .disneyPlus: ["disneyplus.com"]
        case .skyShowtime: ["skyshowtime.com"]
        case .appleTV: ["tv.apple.com"]
        case .canalPlus: ["canalplus.com", "canalplus.pl"]
        case .player: ["player.pl"]
        case .polsatBoxGo: ["polsatboxgo.pl"]
        }
    }

    static func detect(in url: URL) -> StreamingService? {
        guard let host = url.host?.lowercased() else { return nil }
        return allCases.first { service in
            service.hosts.contains { host == $0 || host.hasSuffix("." + $0) }
        }
    }

    /// Serwisy, do których masz linki — w kolejności linków.
    static func detected(in links: [QuickLink]) -> [StreamingService] {
        var result: [StreamingService] = []
        for link in links {
            if let url = link.url, let service = detect(in: url), !result.contains(service) {
                result.append(service)
            }
        }
        return result
    }

    /// Dopasowanie do nazw dostawców z TMDB (`watch/providers`, region PL, abonament).
    func matches(providerName: String) -> Bool {
        let name = providerName.lowercased()
        switch self {
        case .netflix: return name.contains("netflix")
        case .hboMax: return name.contains("hbo max") || name == "max" || name.hasPrefix("max ")
        case .primeVideo: return name.contains("prime video")
        case .disneyPlus: return name.contains("disney")
        case .skyShowtime: return name.contains("skyshowtime")
        case .appleTV: return name.contains("apple tv")
        case .canalPlus: return name.contains("canal")
        case .player: return name == "player" || name.hasPrefix("player ")
        case .polsatBoxGo: return name.contains("polsat box")
        }
    }

    /// Wyszukiwanie tytułu w serwisie — tylko tam, gdzie znamy format adresu.
    /// Dla pozostałych używamy strony „gdzie obejrzeć” z TMDB.
    func searchURL(for title: String) -> URL? {
        let target: (base: String, parameter: String)? = switch self {
        case .netflix: ("https://www.netflix.com/search", "q")
        case .hboMax: ("https://play.hbomax.com/search", "q")
        case .primeVideo: ("https://www.primevideo.com/search/", "phrase")
        case .disneyPlus: ("https://www.disneyplus.com/search", "q")
        case .appleTV: ("https://tv.apple.com/pl/search", "term")
        default: nil
        }
        guard let target else { return nil }
        var components = URLComponents(string: target.base)
        components?.queryItems = [URLQueryItem(name: target.parameter, value: title)]
        return components?.url
    }
}
