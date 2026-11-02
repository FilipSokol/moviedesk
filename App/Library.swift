import Foundation

/// Dopasowanie tytułu z Filmwebu do TMDB. `id == 0` — nie znaleziono (nie szukamy ponownie).
struct TMDBRef: Codable, Hashable, Sendable {
    let id: Int
    let genres: [Int]
}

/// Lokalna pamięć podręczna aplikacji (Application Support w kontenerze aplikacji).
/// Dzięki niej nocna synchronizacja pobiera z Filmwebu i TMDB tylko to, co nowe.
struct Library: Codable {
    var ratings: [RatedTitle] = []
    var wantToSee: [WantedTitle] = []
    /// Klucz `film:123` / `serial:456` → tytuły i rok z Filmwebu.
    var titles: [String: FilmwebTitleInfo] = [:]
    /// Klucz jak wyżej → dopasowanie w TMDB.
    var refs: [String: TMDBRef] = [:]
    var lastSync: Date?

    private static var fileURL: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MovieDesk", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("library-v2.json")
    }

    static func load() -> Library {
        guard let data = try? Data(contentsOf: fileURL),
              let library = try? JSONDecoder().decode(Library.self, from: data)
        else { return Library() }
        return library
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }
}
