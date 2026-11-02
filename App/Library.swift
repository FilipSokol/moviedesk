import Foundation

/// Lokalna pamięć podręczna aplikacji (Application Support w kontenerze aplikacji).
/// Dzięki niej nocna synchronizacja pobiera z Filmwebu i TMDB tylko to, co nowe.
struct Library: Codable {
    var votes: [FilmwebVote] = []
    /// Filmweb ID → tytuły i rok.
    var titles: [Int: FilmwebTitleInfo] = [:]
    /// Filmweb ID → TMDB ID (0 = nie udało się dopasować).
    var tmdbIDs: [Int: Int] = [:]
    var lastSync: Date?

    private static var fileURL: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MovieDesk", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("library.json")
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
