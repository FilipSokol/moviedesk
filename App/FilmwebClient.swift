import Foundation

/// Ocena filmu z Filmwebu.
struct FilmwebVote: Codable, Hashable, Sendable {
    /// Identyfikator filmu na Filmwebie.
    let entity: Int
    let rate: Int?
    /// Moment wystawienia oceny, w milisekundach.
    let timestamp: Double?
    let favorite: Bool?

    var date: Date? { timestamp.map { Date(timeIntervalSince1970: $0 / 1000) } }
}

struct FilmwebTitleInfo: Codable, Hashable, Sendable {
    let title: String?
    let originalTitle: String?
    let year: Int?
}

/// Nieoficjalne API, którego używa sama strona filmweb.pl. Oceny wymagają ciasteczka
/// zalogowanej sesji (wartość nagłówka `Cookie` skopiowana z przeglądarki).
struct FilmwebClient: Sendable {
    let cookie: String

    private static let base = "https://www.filmweb.pl/api/v1/"

    /// Zwraca nazwę zalogowanego użytkownika — służy do sprawdzenia ciasteczka.
    func loggedUserName() async throws -> String {
        let data = try await get("logged/info", authorized: true)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        for key in ["name", "userName", "login", "nick"] {
            if let value = json?[key] as? String, !value.isEmpty { return value }
        }
        return "zalogowano"
    }

    /// Wszystkie oceny filmów (strona po stronie, aż do pustej).
    func votes(progress: @Sendable (Int) async -> Void) async throws -> [FilmwebVote] {
        var all: [FilmwebVote] = []
        for page in 1...500 {
            let data = try await get("logged/vote/title/film?page=\(page)", authorized: true)
            let batch = try JSONDecoder().decode([FilmwebVote].self, from: data)
            if batch.isEmpty { break }
            all += batch
            await progress(all.count)
            try await Task.sleep(for: .milliseconds(120))
        }
        return all
    }

    func titleInfo(_ id: Int) async throws -> FilmwebTitleInfo {
        let data = try await get("title/\(id)/info", authorized: false)
        return try JSONDecoder().decode(FilmwebTitleInfo.self, from: data)
    }

    private func get(_ path: String, authorized: Bool) async throws -> Data {
        var request = URLRequest(url: URL(string: Self.base + path)!)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("https://www.filmweb.pl/", forHTTPHeaderField: "Referer")
        request.setValue("pl_PL", forHTTPHeaderField: "x-locale")
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
