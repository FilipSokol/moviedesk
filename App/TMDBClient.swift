import Foundation

struct TMDBMovie: Decodable, Hashable, Sendable {
    let id: Int
    let title: String
    let originalTitle: String?
    let releaseDate: String?
    let posterPath: String?
    let voteAverage: Double?
    let voteCount: Int?

    var year: Int? { releaseDate.flatMap { Int($0.prefix(4)) } }
}

/// Klient TMDB. Przyjmuje klucz API (v3) albo token odczytu (v4) — rozpoznaje po długości.
struct TMDBClient: Sendable {
    let credential: String

    private static let base = "https://api.themoviedb.org/3/"
    private var usesBearer: Bool { credential.count > 40 }

    func searchMovie(_ query: String) async throws -> [TMDBMovie] {
        try await page("search/movie", ["query": query])
    }

    func movie(_ id: Int) async throws -> TMDBMovie {
        try await get("movie/\(id)", [:])
    }

    func recommendations(for id: Int) async throws -> [TMDBMovie] {
        try await page("movie/\(id)/recommendations", [:])
    }

    /// Nazwy serwisów abonamentowych (flatrate), na których film jest dostępny w Polsce.
    func providersPL(for id: Int) async throws -> [String] {
        struct Response: Decodable {
            struct Region: Decodable {
                struct Provider: Decodable { let providerName: String }
                let flatrate: [Provider]?
            }
            let results: [String: Region]
        }
        let response: Response = try await get("movie/\(id)/watch/providers", [:])
        return response.results["PL"]?.flatrate?.map(\.providerName) ?? []
    }

    func poster(_ path: String) async throws -> Data {
        let request = URLRequest(url: URL(string: "https://image.tmdb.org/t/p/w342" + path)!)
        return try await HTTP.get(request, service: "TMDB")
    }

    // MARK: - Plumbing

    private struct Page: Decodable { let results: [TMDBMovie] }

    private func page(_ path: String, _ query: [String: String]) async throws -> [TMDBMovie] {
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
