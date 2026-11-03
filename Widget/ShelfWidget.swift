import SwiftUI
import WidgetKit

/// „Na dziś” — trzy tytuły obok siebie. Nazwa rodzaju zostaje stara, żeby już postawione
/// widgety nie zniknęły z pulpitu.
struct ShelfWidget: Widget {
    static let kind = "MovieDeskWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: DeskConfigurationIntent.self, provider: DeskProvider(kind: .shelf)) { entry in
            ShelfView(entry: entry)
                .containerBackground(for: .widget) { WidgetBackdrop() }
        }
        .configurationDisplayName("Na dziś")
        .description("Trzy tytuły w Twoim guście i skróty do serwisów.")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

private struct ShelfView: View {
    let entry: DeskEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if entry.status != .ok {
            StatusView(status: entry.status, entry: entry)
        } else if family == .systemLarge {
            ShelfLarge(entry: entry)
        } else {
            ShelfMedium(entry: entry)
        }
    }
}

/// Średni: trzy plakaty po lewej, wąska kolumna ze skrótami i przyciskiem po prawej.
private struct ShelfMedium: View {
    let entry: DeskEntry

    var body: some View {
        HStack(spacing: 10) {
            PicksRow(
                picks: entry.slots,
                event: entry.event,
                destination: { DeepLink.url(for: $0.openURL) },
                titleSize: 9.5,
                posterPixels: 260
            )
            .invalidatableContent()

            VStack(spacing: 6) {
                LinksGrid(links: Array(entry.links.prefix(4)), columns: 2, glyphSize: 22)
                Spacer(minLength: 0)
                ScenarioButton(entry: entry, compact: true, size: 26)
                ShuffleButton(entry: entry, size: 28)
            }
            .frame(width: 52)
        }
        .padding(12)
        .overlay(alignment: .bottom) {
            if entry.showsUndo {
                UndoPill(lane: entry.lane).padding(.bottom, 6)
            }
        }
    }
}

/// Duży: nagłówek z pozycją, trzy większe karty z akcjami, pasek skrótów.
private struct ShelfLarge: View {
    let entry: DeskEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                ScenarioButton(entry: entry, size: 24)
                if let summary = entry.lane.filter.summary {
                    Text(summary)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if entry.total > 0 {
                    Text("\(entry.position) z \(entry.total)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText(value: Double(entry.position)))
                        .animation(.snappy, value: entry.position)
                }
                ShuffleButton(entry: entry, size: 30)
            }

            if let days = entry.staleDays {
                StaleNotice(days: days)
            }

            HStack(alignment: .top, spacing: 12) {
                ForEach(0..<DeskKind.shelf.capacity, id: \.self) { slot in
                    ZStack {
                        if slot < entry.slots.count {
                            ShelfCard(entry: entry, slot: slot, pick: entry.slots[slot])
                                .id(entry.slots[slot].id)
                                .transition(DeskTransitions.card(for: entry.event))
                        } else {
                            SlotPlaceholder()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                    .animation(
                        DeskTransitions.slotAnimation(slot),
                        value: slot < entry.slots.count ? entry.slots[slot].id : ""
                    )
                }
            }

            Spacer(minLength: 0)

            HStack {
                LinksGrid(links: Array(entry.links.prefix(8)), columns: 8, glyphSize: 24)
                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .overlay(alignment: .bottom) {
            if entry.showsUndo {
                UndoPill(lane: entry.lane).padding(.bottom, 44)
            }
        }
    }
}

private struct ShelfCard: View {
    let entry: DeskEntry
    let slot: Int
    let pick: Pick

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Group {
                if let url = DeepLink.url(for: pick.openURL) {
                    Link(destination: url) { PickPoster(pick: pick, maxPixel: 320) }
                } else {
                    PickPoster(pick: pick, maxPixel: 320)
                }
            }
            .invalidatableContent()

            Text(pick.title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .lineLimit(2, reservesSpace: true)
            Text(PickFormatting.metaLine(pick))
                .font(.system(size: 9.5, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 6) {
                NextButton(lane: entry.lane, slot: slot, pick: pick, size: 20, enabled: entry.canAdvance)
                HideButton(lane: entry.lane, slot: slot, pick: pick, size: 20)
                SaveToggle(pick: pick, isSaved: entry.isSaved(pick), size: 20)
            }
        }
    }
}

#Preview("Na dziś — średni", as: .systemMedium) {
    ShelfWidget()
} timeline: {
    DeskEntry.sample(kind: .shelf)
}

#Preview("Na dziś — duży", as: .systemLarge) {
    ShelfWidget()
} timeline: {
    DeskEntry.sample(kind: .shelf)
}
