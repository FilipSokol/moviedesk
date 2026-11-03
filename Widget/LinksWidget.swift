import SwiftUI
import WidgetKit

struct LinksEntry: TimelineEntry {
    let date: Date
    let links: [QuickLink]
}

struct LinksProvider: TimelineProvider {
    func placeholder(in context: Context) -> LinksEntry {
        LinksEntry(date: .now, links: QuickLink.defaults)
    }

    func getSnapshot(in context: Context, completion: @escaping (LinksEntry) -> Void) {
        completion(LinksEntry(date: .now, links: LinkStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LinksEntry>) -> Void) {
        // Odświeża go aplikacja po każdej zmianie linków.
        completion(Timeline(entries: [LinksEntry(date: .now, links: LinkStore.load())], policy: .never))
    }
}

/// „Skróty” — same linki, w wygodnym rozmiarze i z nazwami.
struct LinksWidget: Widget {
    static let kind = "MovieDeskLinks"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: LinksProvider()) { entry in
            LinksWidgetView(links: entry.links)
                .containerBackground(for: .widget) { WidgetBackdrop() }
        }
        .configurationDisplayName("Skróty")
        .description("Twoje linki do serwisów i stron.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

private struct LinksWidgetView: View {
    let links: [QuickLink]
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if links.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "link.badge.plus")
                        .font(.system(size: 22, weight: .medium))
                        .widgetAccentable()
                    Text("Dodaj linki w MovieDesk")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            } else if family == .systemMedium {
                LinksGrid(links: Array(links.prefix(10)), columns: 5, glyphSize: 40, showsNames: true, spacing: 10)
            } else if links.count <= 4 {
                LinksGrid(links: links, columns: 2, glyphSize: 46, showsNames: true, spacing: 10)
            } else {
                LinksGrid(links: Array(links.prefix(9)), columns: 3, glyphSize: 38, spacing: 10)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Skróty — mały", as: .systemSmall) {
    LinksWidget()
} timeline: {
    LinksEntry(date: .now, links: QuickLink.defaults)
}

#Preview("Skróty — średni", as: .systemMedium) {
    LinksWidget()
} timeline: {
    LinksEntry(date: .now, links: QuickLink.defaults)
}
