import Foundation

/// Kliknięcie w widget otwiera `moviedesk://open?url=…`; aplikacja przekazuje adres
/// do domyślnej przeglądarki. Dzięki temu zachowanie nie zależy od tego,
/// jak system traktuje linki http(s) w widgetach.
enum DeepLink {
    static let scheme = "moviedesk"
    private static let host = "open"

    static func url(for link: QuickLink) -> URL? {
        link.url.flatMap(url(for:))
    }

    static func url(for target: URL) -> URL? {
        guard let encoded = target.absoluteString.addingPercentEncoding(withAllowedCharacters: .alphanumerics)
        else { return nil }
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.percentEncodedQuery = "url=" + encoded
        return components.url
    }

    /// Zwraca docelowy adres http(s) albo `nil` dla czegokolwiek innego.
    static func target(from url: URL) -> URL? {
        guard url.scheme?.lowercased() == scheme, url.host == host,
              let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                  .queryItems?.first(where: { $0.name == "url" })?.value
        else { return nil }
        return QuickLink.webURL(from: value)
    }
}
