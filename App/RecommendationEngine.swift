import Foundation

enum EngineError: LocalizedError {
    case notEnoughRatings
    case nothingAvailable

    var errorDescription: String? {
        switch self {
        case .notEnoughRatings: "Za mało wysokich ocen dopasowanych do TMDB, żeby zbudować propozycje."
        case .nothingAvailable: "Żaden pasujący tytuł nie jest teraz dostępny w Twoich serwisach."
        }
    }
}

/// Cała nocna robota: Filmweb → TMDB → profil gustu → ranking → dostępność w PL → szczegóły,
/// oceny i obrazki.
///
/// Pula ma trzy źródła, przeplatane w kolejności nowy, z listy, nowy, do powtórki:
/// - **nowe** — rekomendacje TMDB dla Twoich ulubionych tytułów (20 ostatnio ocenionych
///   + 20 losowych), ułożone według: ilu ulubionych je wskazuje i jak wysoko je oceniłeś,
///   dopasowania gatunków do Twojego gustu i ogólnej jakości,
/// - **z listy „Chcę zobaczyć”** — ułożone według dopasowania gatunków,
/// - **do powtórki** — ulubione ocenione ponad 5 lat temu.
/// Zostają tylko tytuły dostępne w abonamencie serwisów, do których masz linki,
/// i których nie ukryłeś w widgecie.
struct RecommendationEngine {
    let filmweb: FilmwebClient
    let tmdb: TMDBClient
    let omdb: OMDbClient?
    /// Kolejność ma znaczenie: przy kilku serwisach link prowadzi do pierwszego pasującego.
    let services: [StreamingService]
    /// Tytuły ukryte w widgetach („Nie pokazuj więcej”, „Obejrzane”).
    let excludedIDs: Set<String>
    let progress: @Sendable (String) async -> Void

    static let poolSize = 60
    static let rewatchAfter: TimeInterval = 5 * 365 * 24 * 3600
    /// „Nie znaleziono w TMDB” sprawdzamy ponownie po 30 dniach.
    static let retryNotFoundAfter: TimeInterval = 30 * 24 * 3600

    private struct Candidate: Sendable {
        var media: MediaKind
        var title: TMDBTitle
        var kind: Pick.Kind
        var filmwebID: Int?
        var score: Double
        var reason: String?
    }

    private struct Ready: Sendable {
        var candidate: Candidate
        var service: StreamingService
        var openURL: URL
    }

    func run(library: inout Library) async throws -> PicksSnapshot {
        // 0. Zły klucz TMDB wychodzi od razu, a nie po kilku minutach pobierania z Filmwebu.
        await progress("Sprawdzanie klucza TMDB…")
        try await tmdb.validate()

        // 1. Filmweb: oceny filmów i seriali, lista „Chcę zobaczyć”.
        //    Gdy seriale albo lista się nie pobiorą, zostają wczorajsze dane (a nie puste).
        await progress("Pobieranie ocen filmów…")
        let films = try await filmweb.ratings(.film) { count in await progress("Pobrano \(count) ocen filmów…") }
        await progress("Pobieranie ocen seriali…")
        let series: [RatedTitle]
        do {
            series = try await filmweb.ratings(.serial) { count in await progress("Pobrano \(count) ocen seriali…") }
        } catch {
            series = library.ratings.filter { $0.media == .serial }
        }
        library.ratings = films + series

        var wanted: [WantedTitle] = []
        for media in MediaKind.allCases {
            do {
                wanted += try await filmweb.wantToSee(media)
            } catch {
                wanted += library.wantToSee.filter { $0.media == media }
            }
        }
        library.wantToSee = wanted
        library.save()

        // 2. Tytuły z Filmwebu — tylko dla nowych pozycji; zapis co 200, żeby nie tracić postępu.
        var seenKeys = Set<String>()
        let entries: [(key: String, media: MediaKind, id: Int)] =
            (library.ratings.map { (key: $0.key, media: $0.media, id: $0.filmwebID) }
                + wanted.map { (key: $0.key, media: $0.media, id: $0.filmwebID) })
            .filter { seenKeys.insert($0.key).inserted }

        let missingTitles = entries.filter { library.titles[$0.key] == nil }
        let client = filmweb
        for start in stride(from: 0, to: missingTitles.count, by: 200) {
            let chunk = Array(missingTitles[start..<min(start + 200, missingTitles.count)])
            await progress("Pobieranie tytułów: \(start + chunk.count) z \(missingTitles.count)…")
            let fetched = await chunk.concurrentCompactMap(limit: 3) { entry -> (String, FilmwebTitleInfo)? in
                do {
                    let info = try await client.titleInfo(entry.id)
                    return (entry.key, info)
                } catch HTTPError.status(404, _) {
                    // Tytuł usunięty z Filmwebu — zapamiętujemy, żeby nie pytać co noc.
                    return (entry.key, FilmwebTitleInfo(title: nil, originalTitle: nil, year: nil))
                } catch {
                    return nil
                }
            }
            for (key, info) in fetched { library.titles[key] = info }
            library.save()
        }

        // 3. Dopasowanie do TMDB; „nie znaleziono” sprawdzamy ponownie po 30 dniach.
        let retryBefore = Date().addingTimeInterval(-Self.retryNotFoundAfter)
        let unmapped: [(key: String, media: MediaKind, info: FilmwebTitleInfo)] = entries.compactMap { entry in
            guard let info = library.titles[entry.key] else { return nil }
            if let ref = library.refs[entry.key] {
                guard ref.id == 0, (ref.checkedAt ?? .distantPast) < retryBefore else { return nil }
            }
            return (entry.key, entry.media, info)
        }
        let tmdb = self.tmdb
        for start in stride(from: 0, to: unmapped.count, by: 200) {
            let chunk = Array(unmapped[start..<min(start + 200, unmapped.count)])
            await progress("Dopasowywanie do TMDB: \(start + chunk.count) z \(unmapped.count)…")
            let matched = await chunk.concurrentCompactMap(limit: 6) { item -> (String, TMDBRef)? in
                guard let ref = try? await Self.match(item.media, item.info, tmdb: tmdb) else { return nil }
                return (item.key, ref)
            }
            for (key, ref) in matched { library.refs[key] = ref }
            library.save()
        }

        // 4. Profil gustu
        let rated: [(rating: RatedTitle, ref: TMDBRef)] = library.ratings.compactMap { rating in
            guard let ref = library.refs[rating.key], ref.id > 0 else { return nil }
            return (rating, ref)
        }
        let profile = TasteProfile(ratings: rated.map { ($0.rating.rate, $0.ref.genres) })
        let excluded = Set(rated.map { Self.pickID($0.rating.media, $0.ref.id) }).union(excludedIDs)
        let loved = rated.filter { $0.rating.rate >= profile.lovedThreshold }
        guard !loved.isEmpty else { throw EngineError.notEnoughRatings }

        // 5. Nowe tytuły
        await progress("Szukanie tytułów w Twoim guście…")
        let byRecency = loved.sorted { ($0.rating.date ?? .distantPast) > ($1.rating.date ?? .distantPast) }
        let seeds: [(rating: RatedTitle, ref: TMDBRef, name: String?)] =
            (Array(byRecency.prefix(20)) + Array(byRecency.dropFirst(20).shuffled().prefix(20)))
            .map { seed in
                let info = library.titles[seed.rating.key]
                return (seed.rating, seed.ref, info?.title ?? info?.originalTitle)
            }
        let mean = profile.meanRating
        let yearAgo = Date().addingTimeInterval(-365 * 24 * 3600)
        let lists = await seeds.concurrentCompactMap(limit: 6) {
            seed -> (media: MediaKind, weight: Double, name: String?, titles: [TMDBTitle])? in
            guard let titles = try? await tmdb.recommendations(seed.rating.media, seed.ref.id) else { return nil }
            var weight = Double(seed.rating.rate) - mean + (seed.rating.favorite ? 1 : 0)
            if let date = seed.rating.date, date > yearAgo { weight *= 1.3 }
            return (seed.rating.media, max(weight, 0.5), seed.name, titles)
        }

        var votes: [String: (media: MediaKind, title: TMDBTitle, score: Double, reason: String?, reasonPoints: Double)] = [:]
        for list in lists {
            for (rank, title) in list.titles.enumerated() {
                let id = Self.pickID(list.media, title.id)
                guard !excluded.contains(id), (title.voteCount ?? 0) >= 100 else { continue }
                let points = list.weight * (1 - Double(rank) / 40)
                var vote = votes[id] ?? (media: list.media, title: title, score: 0, reason: nil, reasonPoints: 0)
                vote.score += points
                if points > vote.reasonPoints {
                    vote.reason = list.name
                    vote.reasonPoints = points
                }
                votes[id] = vote
            }
        }
        let maxVotes = max(votes.values.map { $0.score }.max() ?? 1, 0.001)
        let discoveries = votes.values
            .map { entry in
                Candidate(
                    media: entry.media, title: entry.title, kind: .discovery, filmwebID: nil,
                    score: 3 * entry.score / maxVotes
                        + 1.5 * profile.affinity(genres: entry.title.genreIDs)
                        + 0.3 * ((entry.title.voteAverage ?? 6.5) - 6.5),
                    reason: entry.reason
                )
            }
            .sorted { $0.score > $1.score }
            .prefix(120)

        // 6. Z listy „Chcę zobaczyć”
        let wantedRefs: [(item: WantedTitle, ref: TMDBRef)] = wanted.compactMap { item in
            guard let ref = library.refs[item.key], ref.id > 0,
                  !excluded.contains(Self.pickID(item.media, ref.id)) else { return nil }
            return (item, ref)
        }
        let wantedTop = wantedRefs
            .sorted { profile.affinity(genres: $0.ref.genres) > profile.affinity(genres: $1.ref.genres) }
            .prefix(60)
        let wantedCandidates = await wantedTop.concurrentCompactMap(limit: 6) { entry -> Candidate? in
            guard let title = try? await tmdb.details(entry.item.media, entry.ref.id) else { return nil }
            return Candidate(media: entry.item.media, title: title, kind: .wanted, filmwebID: entry.item.filmwebID,
                             score: profile.affinity(genres: entry.ref.genres))
        }.sorted { $0.score > $1.score }

        // 7. Do powtórki (oceniłeś je kiedyś, więc nie wykluczamy ich jako „obejrzanych”,
        //    tylko jako ukryte w widgecie)
        let cutoff = Date().addingTimeInterval(-Self.rewatchAfter)
        let oldFavorites = loved
            .filter { ($0.rating.date ?? .distantFuture) < cutoff }
            .filter { !excludedIDs.contains(Self.pickID($0.rating.media, $0.ref.id)) }
            .map { (entry: $0, order: Double($0.rating.rate) + Double.random(in: 0...1.5)) }
            .sorted { $0.order > $1.order }
            .prefix(60)
            .map { $0.entry }
        let rewatchCandidates = await oldFavorites.concurrentCompactMap(limit: 6) { entry -> Candidate? in
            guard let title = try? await tmdb.details(entry.rating.media, entry.ref.id) else { return nil }
            return Candidate(media: entry.rating.media, title: title, kind: .rewatch, filmwebID: entry.rating.filmwebID,
                             score: Double(entry.rating.rate))
        }.sorted { $0.score > $1.score }

        // 8. Dostępność w Twoich serwisach
        await progress("Sprawdzanie dostępności w serwisach…")
        let readyDiscoveries = await available(Array(discoveries), limit: 30)
        let readyWanted = await available(wantedCandidates, limit: 15)
        let readyRewatch = await available(rewatchCandidates, limit: 15)

        // 9. Przeplatanie: nowy, z listy, nowy, do powtórki…
        var buckets: [Pick.Kind: [Ready]] = [.discovery: readyDiscoveries, .wanted: readyWanted, .rewatch: readyRewatch]
        let pattern: [Pick.Kind] = [.discovery, .wanted, .discovery, .rewatch]
        var pool: [Ready] = []
        var usedIDs = Set<String>()
        var step = 0
        while pool.count < Self.poolSize, buckets.values.contains(where: { !$0.isEmpty }) {
            let preferred = pattern[step % pattern.count]
            step += 1
            let kind = buckets[preferred]?.isEmpty == false
                ? preferred
                : [Pick.Kind.discovery, .wanted, .rewatch].first { buckets[$0]?.isEmpty == false }!
            let next = buckets[kind]!.removeFirst()
            let id = Self.pickID(next.candidate.media, next.candidate.title.id)
            if usedIDs.insert(id).inserted { pool.append(next) }
        }
        guard !pool.isEmpty else { throw EngineError.nothingAvailable }

        // 10. Szczegóły, oceny i obrazki
        await progress("Pobieranie szczegółów, ocen i plakatów…")
        let picks = await finalize(pool)
        return PicksSnapshot(generatedAt: .now, picks: picks)
    }

    // MARK: - Kroki pomocnicze

    private static func pickID(_ media: MediaKind, _ tmdbID: Int) -> String {
        "\(media.rawValue)-\(tmdbID)"
    }

    /// Szuka po tytule oryginalnym, potem polskim, z rokiem z Filmwebu. Woli wynik z tym
    /// samym rokiem, potem ±1; wynik bez roku tylko wtedy, gdy Filmweb też roku nie zna.
    /// Zwraca `id == 0`, gdy nic nie pasuje (rzuca tylko przy błędzie sieci).
    private static func match(_ media: MediaKind, _ info: FilmwebTitleInfo, tmdb: TMDBClient) async throws -> TMDBRef {
        var seen = Set<String>()
        let queries = [info.originalTitle, info.title]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }

        for query in queries {
            var results = try await tmdb.search(media, query, year: info.year)
            if results.isEmpty, info.year != nil {
                results = try await tmdb.search(media, query)
            }
            let best = results.first { $0.year != nil && $0.year == info.year }
                ?? results.first { title in
                    guard let year = info.year else { return true }
                    guard let titleYear = title.year else { return false }
                    return abs(year - titleYear) <= 1
                }
            if let best { return TMDBRef(id: best.id, genres: best.genreIDs, checkedAt: .now) }
        }
        return TMDBRef(id: 0, genres: [], checkedAt: .now)
    }

    /// Zostawia tytuły dostępne w abonamencie Twoich serwisów, z zachowaniem kolejności.
    private func available(_ candidates: [Candidate], limit: Int) async -> [Ready] {
        let tmdb = self.tmdb
        let services = self.services
        let indexed = candidates.enumerated().map { (index: $0.offset, candidate: $0.element) }

        let found = await indexed.concurrentCompactMap(limit: 6) { item -> (index: Int, ready: Ready)? in
            let candidate = item.candidate
            guard let providers = try? await tmdb.providersPL(candidate.media, candidate.title.id),
                  let service = services.first(where: { service in
                      providers.names.contains(where: service.matches(providerName:))
                  }),
                  let url = service.searchURL(for: candidate.title.displayTitle) ?? providers.link
            else { return nil }
            return (item.index, Ready(candidate: candidate, service: service, openURL: url))
        }
        return found.sorted { $0.index < $1.index }.prefix(limit).map { $0.ready }
    }

    /// Szczegóły (rok, gatunki, długość, sezony, kadr), ocena (Filmweb → IMDb → TMDB),
    /// plakat i kadr dla każdej propozycji. Obrazki trafiają do kontenera App Group,
    /// bo widget nie ma dostępu do sieci. Sprzątanie starych obrazków robi aplikacja
    /// dopiero po zapisaniu nowej puli.
    private func finalize(_ pool: [Ready]) async -> [Pick] {
        let posters = PicksStore.postersDirectory
        let backdrops = PicksStore.backdropsDirectory
        for directory in [posters, backdrops].compactMap({ $0 }) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let tmdb = self.tmdb
        let filmweb = self.filmweb
        let omdb = self.omdb

        let indexed = pool.enumerated().map { (index: $0.offset, ready: $0.element) }
        let built = await indexed.concurrentCompactMap(limit: 6) { item -> (index: Int, pick: Pick)? in
            let candidate = item.ready.candidate
            // Szczegóły — dla nowych to pierwsze takie zapytanie; przy błędzie zostaje to, co mamy.
            let title = (try? await tmdb.details(candidate.media, candidate.title.id)) ?? candidate.title

            var pick = Pick(
                tmdbID: title.id,
                media: candidate.media,
                title: title.displayTitle.isEmpty ? candidate.title.displayTitle : title.displayTitle,
                overview: (title.overview?.isEmpty == false ? title.overview : candidate.title.overview),
                rating: nil,
                service: item.ready.service,
                openURL: item.ready.openURL,
                kind: candidate.kind,
                posterFile: nil,
                year: title.year,
                genres: Array(title.genreNames.prefix(2)),
                runtimeMinutes: title.runtimeMinutes,
                seasons: candidate.media == .serial ? title.numberOfSeasons : nil,
                tagline: title.tagline?.isEmpty == false ? title.tagline : nil,
                backdropFile: nil,
                reason: candidate.reason
            )

            // Ocena
            if let filmwebID = candidate.filmwebID,
               let value = try? await filmweb.communityRating(candidate.media, filmwebID), value > 0 {
                pick.rating = Rating(value: value, source: .filmweb)
            } else if let omdb,
                      let imdbID = title.externalIds?.imdbId, !imdbID.isEmpty,
                      let value = try? await omdb.imdbRating(imdbID) {
                pick.rating = Rating(value: value, source: .imdb)
            } else if let value = title.voteAverage ?? candidate.title.voteAverage, value > 0 {
                pick.rating = Rating(value: value, source: .tmdb)
            }

            // Obrazki
            let fileName = "\(pick.id).jpg"
            if let posters, let path = title.posterPath ?? candidate.title.posterPath,
               await Self.download(tmdb, path, size: "w342", to: posters.appendingPathComponent(fileName)) {
                pick.posterFile = fileName
            }
            if let backdrops, let path = title.backdropPath,
               await Self.download(tmdb, path, size: "w780", to: backdrops.appendingPathComponent(fileName)) {
                pick.backdropFile = fileName
            }
            return (item.index, pick)
        }
        return built.sorted { $0.index < $1.index }.map { $0.pick }
    }

    /// Pobiera obrazek, jeśli jeszcze go nie ma. `true`, gdy plik jest na miejscu.
    private static func download(_ tmdb: TMDBClient, _ path: String, size: String, to file: URL) async -> Bool {
        if FileManager.default.fileExists(atPath: file.path) { return true }
        guard let data = try? await tmdb.image(path, size: size) else { return false }
        return (try? data.write(to: file, options: .atomic)) != nil
    }
}
