import Foundation

/// Kliknięcia w widgetach idą przez schemat `moviedesk://` do aplikacji:
/// - `moviedesk://open?url=…` — otwórz stronę w domyślnej przeglądarce,
/// - `moviedesk://sync` — zsynchronizuj teraz,
/// - `moviedesk://settings` — otwórz ustawienia.
enum DeepLink {
    static let scheme = "moviedesk"

    enum Route: Equatable {
        case open(URL)
        case sync
        case settings
    }

    static let syncURL = URL(string: "moviedesk://sync")!
    static let settingsURL = URL(string: "moviedesk://settings")!

    static func url(for link: QuickLink) -> URL? {
        link.url.flatMap(url(for:))
    }

    static func url(for target: URL) -> URL? {
        guard let encoded = target.absoluteString.addingPercentEncoding(withAllowedCharacters: .alphanumerics)
        else { return nil }
        var components = URLComponents()
        components.scheme = scheme
        components.host = "open"
        components.percentEncodedQuery = "url=" + encoded
        return components.url
    }

    static func route(from url: URL) -> Route? {
        guard url.scheme?.lowercased() == scheme else { return nil }
        switch url.host {
        case "sync":
            return .sync
        case "settings":
            return .settings
        case "open":
            guard let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "url" })?.value,
                let target = QuickLink.webURL(from: value)
            else { return nil }
            return .open(target)
        default:
            return nil
        }
    }
}

extension Notification.Name {
    /// Widget poprosił o synchronizację (`moviedesk://sync`).
    static let movieDeskSyncRequested = Notification.Name("MovieDeskSyncRequested")
    /// Widget poprosił o ustawienia (`moviedesk://settings`).
    static let movieDeskSettingsRequested = Notification.Name("MovieDeskSettingsRequested")
}
