import Foundation

/// Twoja ocena tytułu na Filmwebie.
struct RatedTitle: Codable, Hashable, Sendable {
    let filmwebID: Int
    let media: MediaKind
    let rate: Int
    let date: Date?
    let favorite: Bool

    var key: String { FilmwebKey.make(media, filmwebID) }
}

/// Tytuł z listy „Chcę zobaczyć”.
struct WantedTitle: Codable, Hashable, Sendable {
    let filmwebID: Int
    let media: MediaKind

    var key: String { FilmwebKey.make(media, filmwebID) }
}

struct FilmwebTitleInfo: Codable, Hashable, Sendable {
    let title: String?
    let originalTitle: String?
    let year: Int?
}

enum FilmwebKey {
    static func make(_ media: MediaKind, _ id: Int) -> String { "\(media.rawValue):\(id)" }
}

/// Nieoficjalne API, którego używa sama strona filmweb.pl. Oceny i lista „Chcę zobaczyć”
/// wymagają ciasteczka zalogowanej sesji (wartość nagłówka `Cookie` skopiowana z przeglądarki).
struct FilmwebClient: Sendable {
    let cookie: String

    private static let base = "https://www.filmweb.pl/api/v1/"

    /// Zwraca nazwę zalogowanego użytkownika — służy do sprawdzenia ciasteczka.
    func loggedUserName() async throws -> String {
        let json = try await getJSON("logged/info", authorized: true) as? [String: Any]
        for key in ["name", "userName", "login", "nick"] {
            if let value = json?[key] as? String, !value.isEmpty { return value }
        }
        return "zalogowano"
    }

    /// Wszystkie Twoje oceny filmów albo seriali (strona po stronie, aż do pustej).
    func ratings(_ media: MediaKind, progress: @Sendable (Int) async -> Void) async throws -> [RatedTitle] {
        struct Vote: Decodable {
            let entity: Int
            let rate: Int?
            let timestamp: Double?
            let favorite: Bool?
        }
        var all: [RatedTitle] = []
        for page in 1...500 {
            let data = try await get("logged/vote/title/\(media.rawValue)?page=\(page)", authorized: true)
            let batch = try JSONDecoder().decode([Vote].self, from: data)
            if batch.isEmpty { break }
            all += batch.compactMap { vote in
                guard let rate = vote.rate, rate > 0 else { return nil }
                return RatedTitle(
                    filmwebID: vote.entity,
                    media: media,
                    rate: rate,
                    date: vote.timestamp.map { Date(timeIntervalSince1970: $0 / 1000) },
                    favorite: vote.favorite ?? false
                )
            }
            await progress(all.count)
            try await Task.sleep(for: .milliseconds(120))
        }
        return all
    }

    /// Lista „Chcę zobaczyć”. API zwraca pary `[id, poziom]`; poziom 0 oznacza „nie interesuje mnie”.
    func wantToSee(_ media: MediaKind) async throws -> [WantedTitle] {
        let json = try await getJSON("logged/want2see?entityName=\(media.rawValue)", authorized: true)
        guard let entries = json as? [[Any]] else { return [] }
        return entries.compactMap { entry in
            guard let id = (entry.first as? NSNumber)?.intValue else { return nil }
            let level = entry.count > 1 ? (entry[1] as? NSNumber)?.intValue ?? 1 : 1
            return level > 0 ? WantedTitle(filmwebID: id, media: media) : nil
        }
    }

    func titleInfo(_ id: Int) async throws -> FilmwebTitleInfo {
        let data = try await get("title/\(id)/info", authorized: false)
        return try JSONDecoder().decode(FilmwebTitleInfo.self, from: data)
    }

    /// Średnia ocena społeczności Filmwebu.
    func communityRating(_ media: MediaKind, _ id: Int) async throws -> Double? {
        struct Response: Decodable { let rate: Double? }
        let data = try await get("\(media.rawValue)/\(id)/rating", authorized: false)
        return try JSONDecoder().decode(Response.self, from: data).rate
    }

    // MARK: - Plumbing

    private func getJSON(_ path: String, authorized: Bool) async throws -> Any {
        let data = try await get(path, authorized: authorized)
        return try JSONSerialization.jsonObject(with: data)
    }

    private func get(_ path: String, authorized: Bool) async throws -> Data {
        var request = URLRequest(url: URL(string: Self.base + path)!)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("https://www.filmweb.pl/", forHTTPHeaderField: "Referer")
        request.setValue("pl", forHTTPHeaderField: "X-Locale")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        if authorized {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }
        return try await HTTP.get(request, service: "Filmweb")
    }
}
