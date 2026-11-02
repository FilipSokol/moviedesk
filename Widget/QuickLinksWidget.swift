import SwiftUI
import WidgetKit

// MARK: - Timeline

struct LinksEntry: TimelineEntry {
    let date: Date
    let links: [QuickLink]
}

/// Widget nie odświeża się sam — aplikacja woła `reloadTimelines` po każdej zmianie listy.
struct LinksProvider: TimelineProvider {
    func placeholder(in context: Context) -> LinksEntry {
        LinksEntry(date: .now, links: QuickLink.defaults)
    }

    func getSnapshot(in context: Context, completion: @escaping (LinksEntry) -> Void) {
        completion(LinksEntry(date: .now, links: context.isPreview ? QuickLink.defaults : LinkStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LinksEntry>) -> Void) {
        completion(Timeline(entries: [LinksEntry(date: .now, links: LinkStore.load())], policy: .never))
    }
}

// MARK: - Widget

struct QuickLinksWidget: Widget {
    static let kind = "QuickLinksWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: LinksProvider()) { entry in
            QuickLinksView(links: entry.links)
                .containerBackground(for: .widget) { WidgetBackdrop() }
        }
        .configurationDisplayName("Szybkie linki")
        .description("Otwiera ulubione strony w domyślnej przeglądarce.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - Layout

enum WidgetMetrics {
    static let padding: CGFloat = 10
    static let spacing: CGFloat = 8
    /// Promień kafelka koncentryczny z rogiem widgetu (≈ promień widgetu − padding).
    static let tileRadius: CGFloat = 14

    static func grid(for family: WidgetFamily) -> (columns: Int, rows: Int) {
        switch family {
        case .systemSmall: (2, 2)
        case .systemMedium: (4, 2)
        case .systemLarge: (4, 4)
        default: (2, 2)
        }
    }
}

struct QuickLinksView: View {
    let links: [QuickLink]

    @Environment(\.widgetFamily) private var family

    var body: some View {
        let columns = WidgetMetrics.grid(for: family).columns
        let rows = WidgetMetrics.grid(for: family).rows
        let visible = Array(links.prefix(columns * rows))

        if visible.isEmpty {
            EmptyStateView()
        } else {
            Grid(horizontalSpacing: WidgetMetrics.spacing, verticalSpacing: WidgetMetrics.spacing) {
                ForEach(0..<rows, id: \.self) { row in
                    GridRow {
                        ForEach(0..<columns, id: \.self) { column in
                            let index = row * columns + column
                            if index < visible.count {
                                LinkTile(link: visible[index], compact: family == .systemSmall)
                            } else {
                                Color.clear
                            }
                        }
                    }
                }
            }
            .padding(WidgetMetrics.padding)
        }
    }
}

// MARK: - Tile

struct LinkTile: View {
    let link: QuickLink
    var compact = false

    var body: some View {
        if let destination = DeepLink.url(for: link) {
            Link(destination: destination) { content }
        } else {
            content.opacity(0.4)
        }
    }

    private var content: some View {
        VStack(spacing: compact ? 4 : 6) {
            LinkGlyph(link: link, size: compact ? 30 : 34)
            Text(link.name)
                .font(.system(size: compact ? 9.5 : 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { GlassTile(tint: link.tint.color) }
    }
}

/// Imitacja Liquid Glass dla kafelka: delikatny tint, jasna krawędź od góry
/// i ciemniejsza od dołu. W trybach accented/vibrant zostaje sama neutralna tafla.
struct GlassTile: View {
    let tint: Color

    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: WidgetMetrics.tileRadius, style: .continuous)
        let fullColor = renderingMode == .fullColor
        let base = colorScheme == .dark ? Color.white : Color.black

        shape
            .fill(
                fullColor
                    ? AnyShapeStyle(LinearGradient(
                        colors: [tint.opacity(0.22), tint.opacity(0.06)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    : AnyShapeStyle(base.opacity(0.08))
            )
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(colorScheme == .dark ? 0.35 : 0.8),
                                 .white.opacity(0.02),
                                 base.opacity(0.10)],
                        startPoint: .top, endPoint: .bottom),
                    lineWidth: 0.75
                )
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

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "link.badge.plus")
                .font(.system(size: 22, weight: .medium))
                .widgetAccentable()
            Text("Dodaj linki w aplikacji MovieDesk")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

// MARK: - Previews

#Preview("Mały", as: .systemSmall) {
    QuickLinksWidget()
} timeline: {
    LinksEntry(date: .now, links: QuickLink.defaults)
}

#Preview("Średni", as: .systemMedium) {
    QuickLinksWidget()
} timeline: {
    LinksEntry(date: .now, links: QuickLink.defaults)
}

#Preview("Duży", as: .systemLarge) {
    QuickLinksWidget()
} timeline: {
    LinksEntry(date: .now, links: QuickLink.defaults)
}
