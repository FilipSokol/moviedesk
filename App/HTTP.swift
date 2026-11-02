import Foundation

enum HTTPError: LocalizedError {
    case status(Int, URL)
    case unauthorized(service: String)

    var errorDescription: String? {
        switch self {
        case .status(let code, let url): "Błąd \(code) dla \(url.host ?? url.absoluteString)"
        case .unauthorized(let service): "\(service): brak dostępu — sprawdź dane w ustawieniach."
        }
    }
}

enum HTTP {
    static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()

    /// GET z jednym ponowieniem po 429 (limit zapytań).
    static func get(_ request: URLRequest, service: String) async throws -> Data {
        for attempt in 0..<2 {
            let (data, response) = try await session.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            switch code {
            case 200..<300:
                return data
            case 401, 403:
                throw HTTPError.unauthorized(service: service)
            case 429 where attempt == 0:
                let wait = (response as? HTTPURLResponse)?
                    .value(forHTTPHeaderField: "Retry-After").flatMap(Double.init) ?? 2
                try await Task.sleep(for: .seconds(min(wait, 10)))
            default:
                throw HTTPError.status(code, request.url!)
            }
        }
        throw HTTPError.status(429, request.url!)
    }
}

extension Sequence where Element: Sendable {
    /// Równoległe mapowanie z limitem jednoczesnych zadań. Kolejność wyników nie jest zachowana.
    func concurrentCompactMap<T: Sendable>(
        limit: Int,
        _ transform: @escaping @Sendable (Element) async -> T?
    ) async -> [T] {
        var results: [T] = []
        var iterator = makeIterator()
        await withTaskGroup(of: T?.self) { group in
            var running = 0
            while running < limit, let element = iterator.next() {
                group.addTask { await transform(element) }
                running += 1
            }
            while let result = await group.next() {
                if let result { results.append(result) }
                if let element = iterator.next() {
                    group.addTask { await transform(element) }
                }
            }
        }
        return results
    }
}
