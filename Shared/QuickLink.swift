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
    /// Startowy zestaw — kolejność ma znaczenie: mały widget pokazuje pierwsze 4.
    static let defaults: [QuickLink] = [
        QuickLink(name: "Filmweb", address: "https://www.filmweb.pl", tint: .yellow),
        QuickLink(name: "Netflix", address: "https://www.netflix.com", tint: .red),
        QuickLink(name: "HBO Max", address: "https://www.hbomax.com", tint: .indigo),
        QuickLink(name: "Disney+", address: "https://www.disneyplus.com", tint: .blue),
        QuickLink(name: "Prime Video", address: "https://www.primevideo.com", tint: .cyan),
        QuickLink(name: "SkyShowtime", address: "https://www.skyshowtime.com", tint: .purple),
        QuickLink(name: "Player", address: "https://player.pl", tint: .green),
        QuickLink(name: "YouTube", address: "https://www.youtube.com", tint: .orange),
    ]
}
