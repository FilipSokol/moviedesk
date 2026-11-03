import Foundation

/// Polskie opisy metadanych, np. „2021 · 2 godz. 35 min · Sci-Fi” albo „Serial · 3 sezony”.
enum PickFormatting {
    static func metaLine(_ pick: Pick, maxGenres: Int = 1) -> String {
        var parts: [String] = []
        if pick.media == .serial {
            parts.append("Serial")
            if let seasons = pick.seasons, seasons > 0 { parts.append(seasonsText(seasons)) }
        } else {
            if let year = pick.year { parts.append(String(year)) }
            if let minutes = pick.runtimeMinutes, minutes > 0 { parts.append(runtimeText(minutes)) }
        }
        if let genres = pick.genres, !genres.isEmpty {
            parts.append(genres.prefix(maxGenres).joined(separator: ", "))
        }
        return parts.joined(separator: " · ")
    }

    static func runtimeText(_ minutes: Int) -> String {
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 { return "\(rest) min" }
        return rest == 0 ? "\(hours) godz." : "\(hours) godz. \(rest) min"
    }

    /// 1 sezon, 2–4 sezony, 5+ sezonów (ale 12–14 sezonów).
    static func seasonsText(_ count: Int) -> String {
        let lastTwo = count % 100
        let last = count % 10
        if count == 1 { return "1 sezon" }
        if (2...4).contains(last) && !(12...14).contains(lastTwo) { return "\(count) sezony" }
        return "\(count) sezonów"
    }

    /// Aplikacja jest po polsku, więc daty i godziny też — niezależnie od języka systemu.
    static let polish = Locale(identifier: "pl_PL")

    /// „22:41” — zawsze 24-godzinny zegar.
    static func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = polish
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    /// „dziś o 01:37”, „wczoraj o 23:10”, „3 listopada o 01:37”.
    static func relativeDay(_ date: Date, now: Date = .now) -> String {
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: now) { return "dziś o \(time(date))" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "wczoraj o \(time(date))"
        }
        let formatter = DateFormatter()
        formatter.locale = polish
        formatter.setLocalizedDateFormatFromTemplate(
            calendar.isDate(date, equalTo: now, toGranularity: .year) ? "d MMMM" : "d MMMM yyyy"
        )
        return "\(formatter.string(from: date)) o \(time(date))"
    }

    /// „Skończysz ok. 22:41” (film) albo „odc. ok. 45 min” (serial).
    static func finishText(_ pick: Pick, from date: Date) -> String? {
        guard let minutes = pick.runtimeMinutes, minutes > 0 else { return nil }
        if pick.media == .serial { return "odc. ok. \(minutes) min" }
        return "Skończysz ok. " + time(date.addingTimeInterval(TimeInterval(minutes * 60)))
    }

    /// Podpis pod tytułem: „bo lubisz Interstellar”, „Na Blu-ray/DVD od marca 2025”,
    /// „Dla was obojga”… zależnie od scenariusza i źródła.
    static func reasonLine(_ pick: Pick) -> String {
        if let note = pick.note, !note.isEmpty { return note }
        switch pick.resolvedScenario {
        case .forMe:
            if pick.kind == .discovery, let reason = pick.reason, !reason.isEmpty {
                return "bo lubisz \(reason)"
            }
            return pick.kind.label
        case .fresh:
            return "Nowość w serwisie"
        case .toBuy:
            return "Świeże wydanie"
        case .together, .togetherAnywhere:
            switch pick.kind {
            case .rewatch: return "Znasz i lubisz"
            case .wanted: return "Z Twojej listy"
            case .discovery: return "Dla was obojga"
            }
        }
    }
}
