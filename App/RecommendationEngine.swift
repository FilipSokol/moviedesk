import Foundation

enum EngineError: LocalizedError {
    case notEnoughRatings
    case nothingAvailable

    var errorDescription: String? {
        switch self {
        case .notEnoughRatings: "Brak ocen 8+ dopasowanych do TMDB — nie ma z czego budować propozycji."
        case .nothingAvailable: "Żaden pasujący film nie jest teraz dostępny w wybranych serwisach."
        }
    }
}

/// Cała nocna robota: Filmweb → TMDB → ranking → dostępność w PL → plakaty → pula propozycji.
///
/// Pula miesza dwa rodzaje filmów w proporcji 2:1, więc każda trójka w widgecie to zwykle
/// dwa nowe filmy i jeden do powtórki:
/// - **nowe** — rekomendacje TMDB dla losowej czterdziestki filmów ocenionych na 8+,
///   z pominięciem wszystkiego, co już oceniłeś; im wyższa Twoja ocena filmu-źródła
///   i im więcej źródeł wskazuje ten sam film, tym wyżej w rankingu,
/// - **do powtórki** — filmy ocenione na 8+ ponad 5 lat temu.
/// Do puli trafiają tylko filmy dostępne w abonamencie wybranych serwisów w Polsce.
struct RecommendationEngine {
    let filmweb: FilmwebClient
    let tmdb: TMDBClient
    /// Kolejność ma znaczenie: przy kilku serwisach link prowadzi do pierwszego pasującego.
    let services: [StreamingService]
    let progress: @Sendable (String) async -> Void

    static let poolSize = 30
    static let lovedRating = 8
    static let rewatchAfter: TimeInterval = 5 * 365 * 24 * 3600

    func run(library: inout Library) async throws -> PicksSnapshot {
        // 1. Oceny z Filmwebu
        await progress("Pobieranie ocen z Filmwebu…")
        let votes = try await filmweb.votes { count in await progress("Pobrano \(count) ocen…") }
        library.votes = votes.filter { ($0.rate ?? 0) > 0 }
        library.save()

        // 2. Tytuły — tylko dla filmów, których jeszcze nie znamy
        let missingTitles = library.votes.map(\.entity).filter { library.titles[$0] == nil }
        if !missingTitles.isEmpty {
            await progress("Pobieranie tytułów: \(missingTitles.count) nowych…")
            let client = filmweb
            let fetched = await missingTitles.concurrentCompactMap(limit: 4) { id -> (Int, FilmwebTitleInfo)? in
                guard let info = try? await client.titleInfo(id) else { return nil }
                return (id, info)
            }
            for (id, info) in fetched { library.titles[id] = info }
            library.save()
        }

        // 3. Dopasowanie do TMDB (wynik zapamiętujemy, także „nie znaleziono”)
        let unmapped: [(Int, FilmwebTitleInfo)] = library.votes.compactMap { vote in
            guard library.tmdbIDs[vote.entity] == nil, let info = library.titles[vote.entity] else { return nil }
            return (vote.entity, info)
        }
        let tmdb = self.tmdb
        if !unmapped.isEmpty {
            await progress("Dopasowywanie \(unmapped.count) filmów do TMDB…")
            let matched = await unmapped.concurrentCompactMap(limit: 6) { pair -> (Int, Int)? in
                guard let tmdbID = try? await Self.match(pair.1, tmdb: tmdb) else { return nil }
                return (pair.0, tmdbID)
            }
            for (filmwebID, tmdbID) in matched { library.tmdbIDs[filmwebID] = tmdbID }
            library.save()
        }

        let rated: [(tmdb: Int, vote: FilmwebVote)] = library.votes.compactMap { vote in
            guard let tmdbID = library.tmdbIDs[vote.entity], tmdbID > 0 else { return nil }
            return (tmdbID, vote)
        }
        let watched = Set(rated.map { $0.tmdb })
        let loved = rated.filter { ($0.vote.rate ?? 0) >= Self.lovedRating }
        guard !loved.isEmpty else { throw EngineError.notEnoughRatings }

        // 4. Nowe filmy: rekomendacje TMDB dla losowych ulubionych
        await progress("Szukanie filmów w Twoim guście…")
        let seeds = Array(loved.shuffled().prefix(40))
        let lists = await seeds.concurrentCompactMap(limit: 6) { seed -> (weight: Double, movies: [TMDBMovie])? in
            guard let movies = try? await tmdb.recommendations(for: seed.tmdb) else { return nil }
            let weight = Double((seed.vote.rate ?? Self.lovedRating) - 6) + (seed.vote.favorite == true ? 1 : 0)
            return (weight, movies)
        }

        var scores: [Int: Double] = [:]
        var movies: [Int: TMDBMovie] = [:]
        for list in lists {
            for (rank, movie) in list.movies.enumerated()
            where !watched.contains(movie.id) && (movie.voteCount ?? 0) >= 150 {
                scores[movie.id, default: 0] += list.weight * (1 - Double(rank) / 40)
                movies[movie.id] = movie
            }
        }
        let ranked: [TMDBMovie] = scores
            .map { (id: $0.key, score: $0.value + ((movies[$0.key]?.voteAverage ?? 6) - 6) * 0.5) }
            .sorted { $0.score > $1.score }
            .prefix(80)
            .compactMap { movies[$0.id] }

        await progress("Sprawdzanie dostępności w serwisach…")
        let discoveries = await availablePicks(from: ranked, kind: .discovery, limit: 20)

        // 5. Do powtórki: ulubione sprzed ponad 5 lat
        let cutoff = Date().addingTimeInterval(-Self.rewatchAfter)
        let oldFavorites = Array(loved.filter { ($0.vote.date ?? .distantFuture) < cutoff }.shuffled().prefix(40))
        let oldMovies = await oldFavorites.concurrentCompactMap(limit: 6) { item in
            try? await tmdb.movie(item.tmdb)
        }
        let rewatches = await availablePicks(from: oldMovies, kind: .rewatch, limit: 10)

        // 6. Pula: dwa nowe, jeden do powtórki, i tak dalej
        var pool: [Candidate] = []
        var newOnes = discoveries.makeIterator()
        var oldOnes = rewatches.makeIterator()
        while pool.count < Self.poolSize {
            var added = false
            for _ in 0..<2 {
                if let next = newOnes.next() { pool.append(next); added = true }
            }
            if let next = oldOnes.next() { pool.append(next); added = true }
            if !added { break }
        }
        guard !pool.isEmpty else { throw EngineError.nothingAvailable }

        await progress("Pobieranie plakatów…")
        let picks = await savePosters(for: pool)
        return PicksSnapshot(generatedAt: .now, picks: picks)
    }

    // MARK: - Kroki pomocnicze

    private struct Candidate: Sendable {
        var pick: Pick
        var posterPath: String?
    }

    /// Szuka po tytule oryginalnym, potem polskim; akceptuje wynik z rokiem ±1.
    /// Zwraca 0, gdy nic nie pasuje (rzuca tylko przy błędzie sieci).
    private static func match(_ info: FilmwebTitleInfo, tmdb: TMDBClient) async throws -> Int {
        var seen = Set<String>()
        let queries = [info.originalTitle, info.title]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }

        for query in queries {
            let results = try await tmdb.searchMovie(query)
            let best = results.first { movie in
                guard let year = info.year, let movieYear = movie.year else { return true }
                return abs(year - movieYear) <= 1
            }
            if let best { return best.id }
        }
        return 0
    }

    /// Zostawia filmy dostępne w abonamencie wybranych serwisów, z zachowaniem kolejności.
    private func availablePicks(from candidates: [TMDBMovie], kind: Pick.Kind, limit: Int) async -> [Candidate] {
        let tmdb = self.tmdb
        let services = self.services
        let indexed = candidates.enumerated().map { (index: $0.offset, movie: $0.element) }

        let found = await indexed.concurrentCompactMap(limit: 6) { item -> (index: Int, candidate: Candidate)? in
            guard let names = try? await tmdb.providersPL(for: item.movie.id),
                  let service = services.first(where: { service in names.contains(where: service.matches(providerName:)) }),
                  let url = service.searchURL(for: item.movie.title)
            else { return nil }
            let pick = Pick(id: item.movie.id, title: item.movie.title, service: service, openURL: url, kind: kind)
            return (item.index, Candidate(pick: pick, posterPath: item.movie.posterPath))
        }
        return found.sorted { $0.index < $1.index }.prefix(limit).map { $0.candidate }
    }

    /// Pobiera plakaty do kontenera App Group (widget nie ma dostępu do sieci) i usuwa stare.
    private func savePosters(for pool: [Candidate]) async -> [Pick] {
        guard let directory = PicksStore.postersDirectory else { return pool.map(\.pick) }
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let tmdb = self.tmdb
        let savedIDs = await pool.concurrentCompactMap(limit: 6) { candidate -> Int? in
            let file = directory.appendingPathComponent("\(candidate.pick.id).jpg")
            if FileManager.default.fileExists(atPath: file.path) { return candidate.pick.id }
            guard let path = candidate.posterPath, let data = try? await tmdb.poster(path) else { return nil }
            return (try? data.write(to: file, options: .atomic)) != nil ? candidate.pick.id : nil
        }
        let saved = Set(savedIDs)

        let keep = Set(saved.map { "\($0).jpg" })
        for name in (try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? [] where !keep.contains(name) {
            try? fileManager.removeItem(at: directory.appendingPathComponent(name))
        }

        return pool.map { candidate in
            var pick = candidate.pick
            pick.posterFile = saved.contains(pick.id) ? "\(pick.id).jpg" : nil
            return pick
        }
    }
}
