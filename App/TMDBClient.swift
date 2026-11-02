import Foundation

/// Film albo serial z TMDB (pola filmów i seriali mają różne nazwy).
struct TMDBTitle: Decodable, Hashable, Sendable {
    struct Genre: Decodable, Hashable, Sendable { let id: Int }

    let id: Int
    let title: String?
    let name: String?
    let releaseDate: String?
    let firstAirDate: String?
    let posterPath: String?
    let overview: String?
    let voteAverage: Double?
    let voteCount: Int?
    /// W wynikach list…
    let genreIds: [Int]?
    /// …a w szczegółach.
    let genres: [Genre]?

    var displayTitle: String { title ?? name ?? "" }
    var year: Int? { (releaseDate ?? firstAirDate).flatMap { Int($0.prefix(4)) } }
    var genreIDs: [Int] { genreIds ?? genres?.map(\.id) ?? [] }
}

struct WatchProviders: Sendable {
    /// Nazwy serwisów abonamentowych w Polsce.
    let names: [String]
    /// Strona TMDB „gdzie obejrzeć” (dane JustWatch) — zapasowy link.
    let link: URL?
}

/// Klient TMDB. Przyjmuje klucz API (v3) albo token odczytu (v4) — rozpoznaje po długości.
struct TMDBClient: Sendable {
    let credential: String

    private static let base = "https://api.themoviedb.org/3/"
    private var usesBearer: Bool { credential.count > 40 }

    func search(_ media: MediaKind, _ query: String) async throws -> [TMDBTitle] {
        try await results("search/\(media.tmdbPath)", ["query": query])
    }

    func details(_ media: MediaKind, _ id: Int) async throws -> TMDBTitle {
        try await get("\(media.tmdbPath)/\(id)", [:])
    }

    func recommendations(_ media: MediaKind, _ id: Int) async throws -> [TMDBTitle] {
        try await results("\(media.tmdbPath)/\(id)/recommendations", [:])
    }

    func providersPL(_ media: MediaKind, _ id: Int) async throws -> WatchProviders {
        struct Response: Decodable {
            struct Region: Decodable {
                struct Provider: Decodable { let providerName: String }
                let link: String?
                let flatrate: [Provider]?
            }
            let results: [String: Region]
        }
        let response: Response = try await get("\(media.tmdbPath)/\(id)/watch/providers", [:])
        let region = response.results["PL"]
        return WatchProviders(
            names: region?.flatrate?.map(\.providerName) ?? [],
            link: region?.link.flatMap(URL.init(string:))
        )
    }

    func imdbID(_ media: MediaKind, _ id: Int) async throws -> String? {
        struct Response: Decodable { let imdbId: String? }
        let response: Response = try await get("\(media.tmdbPath)/\(id)/external_ids", [:])
        return response.imdbId
    }

    func poster(_ path: String) async throws -> Data {
        let request = URLRequest(url: URL(string: "https://image.tmdb.org/t/p/w342" + path)!)
        return try await HTTP.get(request, service: "TMDB")
    }

    // MARK: - Plumbing

    private struct Page: Decodable { let results: [TMDBTitle] }

    private func results(_ path: String, _ query: [String: String]) async throws -> [TMDBTitle] {
        let page: Page = try await get(path, query)
        return page.results
    }

    private func get<T: Decodable>(_ path: String, _ query: [String: String]) async throws -> T {
        var components = URLComponents(string: Self.base + path)!
        var items = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        items.append(URLQueryItem(name: "language", value: "pl-PL"))
        if !usesBearer { items.append(URLQueryItem(name: "api_key", value: credential)) }
        components.queryItems = items

        var request = URLRequest(url: components.url!)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if usesBearer { request.setValue("Bearer \(credential)", forHTTPHeaderField: "Authorization") }

        let data = try await HTTP.get(request, service: "TMDB")
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }
}

/// OMDb — opcjonalnie, tylko po ocenę IMDb (darmowy klucz: 1000 zapytań dziennie).
struct OMDbClient: Sendable {
    let apiKey: String

    func imdbRating(_ imdbID: String) async throws -> Double? {
        struct Response: Decodable {
            let imdbRating: String?
        }
        var components = URLComponents(string: "https://www.omdbapi.com/")!
        components.queryItems = [URLQueryItem(name: "i", value: imdbID), URLQueryItem(name: "apikey", value: apiKey)]
        let data = try await HTTP.get(URLRequest(url: components.url!), service: "OMDb")
        return try JSONDecoder().decode(Response.self, from: data).imdbRating.flatMap(Double.init)
    }
}
