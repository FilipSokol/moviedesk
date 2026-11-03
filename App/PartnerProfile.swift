import Foundation

/// Gust na wspólny wieczór: love story i dobre dramaty/komedie tak, horrory i krwawe sceny nie,
/// akcja raczej nie. Przykład z życia: „Django” wciągnęło, ale było za brutalne — więc
/// przemoc nie wyklucza filmu od razu, tylko mocno obniża ocenę, a bardzo krwawe filmy odpadają.
///
/// Gatunki to identyfikatory TMDB, słowa kluczowe to nazwy słów kluczowych TMDB (małymi literami).
struct PartnerProfile {
    /// Nigdy: horror.
    var blockedGenres: Set<Int> = [27]

    var genreWeights: [Int: Double] = [
        10749: 1.2,   // romans
        18: 0.5,      // dramat
        35: 0.5,      // komedia
        10402: 0.4,   // muzyczny
        16: 0.2,      // animacja
        14: 0.1,      // fantasy
        10751: 0.1,   // familijny
        28: -0.7,     // akcja
        10752: -0.7,  // wojenny
        53: -0.4,     // thriller
        80: -0.3,     // kryminał
        878: -0.2,    // sci-fi
    ]

    /// Bardzo krwawe — każde takie słowo to dużo „brutalności”.
    var heavyKeywords: Set<String> = [
        "gore", "splatter", "torture", "body horror", "slasher", "cannibalism", "cannibal",
        "dismemberment", "decapitation", "mutilation", "snuff", "graphic violence",
        "extreme violence", "brutality", "sadism", "blood splatter", "bloody violence",
    ]

    /// Przemoc „zwykła” — obniża ocenę, ale sama nie wyklucza.
    var mildKeywords: Set<String> = [
        "violence", "blood", "massacre", "revenge", "serial killer", "murder", "shootout",
        "gunfight", "war crimes", "execution", "assassin", "hitman", "gang violence",
    ]

    var romanticKeywords: Set<String> = [
        "love", "romance", "falling in love", "love story", "relationship", "wedding",
        "romantic comedy", "first love", "lovers",
    ]

    /// Od tej „brutalności” film odpada (np. jedno ciężkie + dwa zwykłe słowa kluczowe).
    var violenceLimit: Double = 1.6

    static let standard = PartnerProfile()

    /// Dopasowanie do wspólnego wieczoru albo `nil`, gdy film odpada.
    func score(genres: [Int], keywords: [String]) -> Double? {
        guard blockedGenres.isDisjoint(with: genres) else { return nil }
        let names = Set(keywords.map { $0.lowercased() })

        let violence = Double(names.intersection(heavyKeywords).count) * 1.0
            + Double(names.intersection(mildKeywords).count) * 0.35
        guard violence < violenceLimit else { return nil }

        let genreScore = genres.isEmpty ? 0 : genres.map { genreWeights[$0] ?? 0 }.reduce(0, +)
        let romance = min(0.6, Double(names.intersection(romanticKeywords).count) * 0.2)
        return genreScore + romance - violence * 0.6
    }

    /// Szybkie sito po samych gatunkach (zanim pobierzemy słowa kluczowe).
    func preliminary(genres: [Int]) -> Double? {
        guard blockedGenres.isDisjoint(with: genres) else { return nil }
        return genres.map { genreWeights[$0] ?? 0 }.reduce(0, +)
    }
}
