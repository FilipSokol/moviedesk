import Foundation

/// Kontener App Group współdzielony przez aplikację i widget.
enum AppGroup {
    /// Wstrzykiwane z build settings (APP_GROUP_ID) do Info.plist obu targetów.
    static let identifier: String? = Bundle.main.object(forInfoDictionaryKey: "MDAppGroupID") as? String

    static var defaults: UserDefaults {
        identifier.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }
}

/// Zapis listy linków. Aplikacja pisze, widget tylko czyta.
enum LinkStore {
    private static let key = "quickLinks.v2"

    static func load() -> [QuickLink] {
        guard let data = AppGroup.defaults.data(forKey: key),
              let links = try? JSONDecoder().decode([QuickLink].self, from: data)
        else { return QuickLink.defaults }
        return links
    }

    static func save(_ links: [QuickLink]) {
        guard let data = try? JSONEncoder().encode(links) else { return }
        AppGroup.defaults.set(data, forKey: key)
    }
}
