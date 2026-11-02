import Foundation

/// Twój gust w liczbach: które gatunki oceniasz powyżej, a które poniżej swojej średniej.
///
/// Dla każdego gatunku sumujemy odchylenia Twoich ocen od Twojej średniej i dzielimy przez
/// liczbę ocen powiększoną o 5 — gatunek z dwiema ocenami nie przeważy tego z pięćdziesięcioma.
struct TasteProfile {
    let meanRating: Double
    private let genreAffinity: [Int: Double]

    init(ratings: [(rate: Int, genres: [Int])]) {
        let mean = ratings.isEmpty ? 7 : Double(ratings.map { $0.rate }.reduce(0, +)) / Double(ratings.count)
        var sums: [Int: Double] = [:]
        var counts: [Int: Double] = [:]
        for rating in ratings {
            let deviation = Double(rating.rate) - mean
            for genre in rating.genres {
                sums[genre, default: 0] += deviation
                counts[genre, default: 0] += 1
            }
        }
        meanRating = mean
        genreAffinity = sums.reduce(into: [:]) { result, entry in
            result[entry.key] = entry.value / ((counts[entry.key] ?? 0) + 5)
        }
    }

    /// Ocena „ulubiona”: co najmniej 8, a przy wysokiej średniej — średnia + 1.
    var lovedThreshold: Int { min(9, max(8, Int((meanRating + 1).rounded()))) }

    /// Średnie dopasowanie gatunków tytułu do Twojego gustu (zwykle od -1 do 1).
    func affinity(genres: [Int]) -> Double {
        guard !genres.isEmpty else { return 0 }
        return genres.map { genreAffinity[$0] ?? 0 }.reduce(0, +) / Double(genres.count)
    }
}
