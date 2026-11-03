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

    /// Kolor marki (do tła przycisku „▶ Netflix” i zastępczej ikony bez logo).
    var tint: Color {
        switch self {
        case .netflix: Color(red: 0.898, green: 0.035, blue: 0.078)      // #E50914
        case .hboMax: Color(red: 0.239, green: 0.137, blue: 0.839)       // #3D23D6
        case .primeVideo: Color(red: 0.0, green: 0.659, blue: 0.882)     // #00A8E1
        case .disneyPlus: Color(red: 0.059, green: 0.231, blue: 0.769)   // #0F3BC4
        case .skyShowtime: Color(red: 0.553, green: 0.204, blue: 0.851)  // #8D34D9
        case .appleTV: Color(red: 0.15, green: 0.15, blue: 0.17)
        case .canalPlus: Color(red: 0.10, green: 0.10, blue: 0.10)
        case .player: Color(red: 0.961, green: 0.718, blue: 0.0)         // #F5B700
        case .polsatBoxGo: Color(red: 1.0, green: 0.42, blue: 0.0)       // #FF6B00
        }
    }

    /// Kolor tekstu na tle marki.
    var onTint: Color { self == .player ? .black : .white }

    /// Logo serwisu (pobrane z TMDB podczas synchronizacji), jeśli już jest na dysku.
    func logo(maxPixel: CGFloat) -> CGImage? {
        ImageStore.image(logoFileName, in: PicksStore.logosDirectory, maxPixel: maxPixel)
    }

    var logoFileName: String { rawValue + ".img" }

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
