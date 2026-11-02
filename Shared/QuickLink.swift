import SwiftUI

/// Jeden skrót do strony, pokazywany jako kafelek w widgecie i w menu bar.
struct QuickLink: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var address: String
    var tint: LinkTint

    /// Adres gotowy do otwarcia albo `nil`, gdy wpis nie jest poprawnym adresem http(s).
    var url: URL? { Self.webURL(from: address) }

    var monogram: String {
        name.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() } ?? "•"
    }

    /// Nazwa podpowiadana z adresu: rozpoznany serwis albo domena bez „www” i końcówki,
    /// np. „example.com” → „Example”.
    static func suggestedName(for address: String) -> String {
        guard let url = webURL(from: address), let host = url.host?.lowercased() else { return "" }
        if let service = StreamingService.detect(in: url) { return service.displayName }
        var parts = host.split(separator: ".").map(String.init)
        if parts.count > 2, ["www", "m", "play", "app"].contains(parts[0]) { parts.removeFirst() }
        let core = parts.count >= 2 ? parts[parts.count - 2] : (parts.first ?? host)
        return core.prefix(1).uppercased() + core.dropFirst()
    }

    /// Dopuszcza tylko http/https — widget nie może otwierać plików ani schematów innych aplikacji.
    /// Brakujący schemat uzupełnia jako https (np. "filmweb.pl").
    static func webURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let candidate = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard let url = URL(string: candidate),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty
        else { return nil }
        return url
    }
}

enum LinkTint: String, Codable, CaseIterable, Identifiable {
    case red, orange, yellow, green, mint, teal, cyan, blue, indigo, purple, pink, graphite

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .mint: .mint
        case .teal: .teal
        case .cyan: .cyan
        case .blue: .blue
        case .indigo: .indigo
        case .purple: .purple
        case .pink: .pink
        case .graphite: .gray
        }
    }
}

extension QuickLink {
    /// Startowy zestaw. Kolejne linki dodaje się w aplikacji (zakładka „Linki”).
    static let defaults: [QuickLink] = [
        QuickLink(name: "Netflix", address: "https://www.netflix.com", tint: .red),
        QuickLink(name: "HBO Max", address: "https://play.hbomax.com", tint: .indigo),
        QuickLink(name: "Prime Video", address: "https://www.primevideo.com", tint: .cyan),
        QuickLink(name: "Disney+", address: "https://www.disneyplus.com", tint: .blue),
    ]
}
