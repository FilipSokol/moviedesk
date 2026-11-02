import SwiftUI
import WidgetKit

// MARK: - Timeline

struct DeskEntry: TimelineEntry {
    let date: Date
    let picks: [Pick]
    let cursor: Int
    let links: [QuickLink]
}

/// Widget tylko czyta to, co aplikacja zapisała w App Group. Przeładowuje go aplikacja
/// po nocnej synchronizacji i WidgetKit po kliknięciu „odśwież”; dodatkowo raz po północy.
struct DeskProvider: TimelineProvider {
    func placeholder(in context: Context) -> DeskEntry {
        DeskEntry(date: .now, picks: Pick.samples, cursor: 0, links: QuickLink.defaults)
    }

    func getSnapshot(in context: Context, completion: @escaping (DeskEntry) -> Void) {
        let entry = currentEntry()
        completion(context.isPreview && entry.picks.isEmpty ? placeholder(in: context) : entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DeskEntry>) -> Void) {
        let nextRefresh = Calendar.current.nextDate(
            after: .now, matching: DateComponents(hour: 0, minute: 30), matchingPolicy: .nextTime
        ) ?? .now.addingTimeInterval(24 * 3600)
        completion(Timeline(entries: [currentEntry()], policy: .after(nextRefresh)))
    }

    private func currentEntry() -> DeskEntry {
        let cursor = PicksStore.cursor
        return DeskEntry(
            date: .now,
            picks: PicksStore.page(of: PicksStore.load(), cursor: cursor),
            cursor: cursor,
            links: LinkStore.load()
        )
    }
}

// MARK: - Widget

struct MovieDeskWidget: Widget {
    static let kind = "MovieDeskWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: DeskProvider()) { entry in
            MovieDeskWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetBackdrop() }
        }
        .configurationDisplayName("MovieDesk")
        .description("Trzy tytuły na dziś w Twoim guście i skróty do serwisów.")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

struct MovieDeskWidgetView: View {
    let entry: DeskEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        if family == .systemLarge {
            LargeLayout(entry: entry)
        } else {
            MediumLayout(entry: entry)
        }
    }
}

/// Średni: trzy plakaty po lewej, wąska kolumna z linkami i przyciskiem po prawej.
private struct MediumLayout: View {
    let entry: DeskEntry

    var body: some View {
        HStack(spacing: 10) {
            PicksArea(entry: entry, titleSize: 9.5)

            VStack(spacing: 6) {
                LinksGrid(links: Array(entry.links.prefix(4)), columns: 2, glyphSize: 22)
                Spacer(minLength: 0)
                Button(intent: ShufflePicksIntent()) {
                    ShuffleGlyph(cursor: entry.cursor, size: 28)
                }
                .buttonStyle(.plain)
            }
            .frame(width: 52)
        }
        .padding(10)
    }
}

/// Duży: nagłówek z przyciskiem, większe plakaty, pasek linków na dole.
private struct LargeLayout: View {
    let entry: DeskEntry

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Na dziś")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .widgetAccentable()
                Spacer()
                Button(intent: ShufflePicksIntent()) {
                    ShuffleGlyph(cursor: entry.cursor, size: 30)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
            PicksArea(entry: entry, titleSize: 11)
            Spacer(minLength: 0)

            LinksGrid(links: Array(entry.links.prefix(8)), columns: 8, glyphSize: 24)
        }
        .padding(14)
    }
}

private struct PicksArea: View {
    let entry: DeskEntry
    let titleSize: CGFloat

    var body: some View {
        if entry.picks.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "film.stack")
                    .font(.system(size: 22, weight: .medium))
                    .widgetAccentable()
                Text("Propozycje pojawią się\npo synchronizacji w MovieDesk")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            PicksRow(
                picks: entry.picks,
                cursor: entry.cursor,
                destination: { DeepLink.url(for: $0.openURL) },
                titleSize: titleSize
            )
            .invalidatableContent()
        }
    }
}

/// Małe okrągłe skróty do stron.
private struct LinksGrid: View {
    let links: [QuickLink]
    let columns: Int
    let glyphSize: CGFloat

    var body: some View {
        let rows = stride(from: 0, to: links.count, by: max(1, columns)).map {
            Array(links[$0..<min($0 + columns, links.count)])
        }
        Grid(horizontalSpacing: 6, verticalSpacing: 6) {
            ForEach(rows.indices, id: \.self) { index in
                GridRow {
                    ForEach(rows[index]) { link in
                        LinkChip(link: link, size: glyphSize)
                    }
                }
            }
        }
    }
}

private struct LinkChip: View {
    let link: QuickLink
    let size: CGFloat

    var body: some View {
        if let destination = DeepLink.url(for: link) {
            Link(destination: destination) {
                LinkGlyph(link: link, size: size)
            }
        } else {
            LinkGlyph(link: link, size: size).opacity(0.4)
        }
    }
}

/// Tło widgetu w trybie pełnokolorowym. W trybach przezroczystych/tintowanych
/// macOS usuwa je i podkłada własne szkło.
struct WidgetBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors: [Color] = colorScheme == .dark
            ? [Color(white: 0.17), Color(white: 0.09)]
            : [Color(white: 0.99), Color(white: 0.91)]
        LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - Podgląd

extension Pick {
    /// Przykładowe dane do podglądu w galerii widżetów (bez plakatów).
    static let samples: [Pick] = [
        Pick(tmdbID: 1, media: .film, title: "Diuna", overview: nil, rating: Rating(value: 7.9, source: .imdb),
             service: .hboMax, openURL: URL(string: "https://play.hbomax.com")!, kind: .discovery, posterFile: nil),
        Pick(tmdbID: 2, media: .film, title: "Incepcja", overview: nil, rating: Rating(value: 8.3, source: .filmweb),
             service: .netflix, openURL: URL(string: "https://www.netflix.com")!, kind: .rewatch, posterFile: nil),
        Pick(tmdbID: 3, media: .serial, title: "Severance", overview: nil, rating: Rating(value: 8.7, source: .imdb),
             service: .appleTV, openURL: URL(string: "https://tv.apple.com")!, kind: .wanted, posterFile: nil),
    ]


#Preview("Średni", as: .systemMedium) {
    MovieDeskWidget()
} timeline: {
    DeskEntry(date: .now, picks: Pick.samples, cursor: 0, links: QuickLink.defaults)
    DeskEntry(date: .now, picks: Array(Pick.samples.reversed()), cursor: 3, links: QuickLink.defaults)
}

#Preview("Duży", as: .systemLarge) {
    MovieDeskWidget()
} timeline: {
    DeskEntry(date: .now, picks: Pick.samples, cursor: 0, links: QuickLink.defaults)
    DeskEntry(date: .now, picks: Array(Pick.samples.reversed()), cursor: 3, links: QuickLink.defaults)
}
