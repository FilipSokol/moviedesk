import SwiftUI
import WidgetKit

/// „Wieczór” — bardzo duży widget: propozycja na wieczór po lewej, kolejka „Dalej” po prawej.
struct BoardWidget: Widget {
    static let kind = "MovieDeskBoard"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: DeskConfigurationIntent.self, provider: DeskProvider(kind: .board)) { entry in
            BoardView(entry: entry)
                .containerBackground(for: .widget) { WidgetBackdrop() }
        }
        .configurationDisplayName("Wieczór")
        .description("Propozycja na wieczór i kolejka następnych tytułów.")
        .supportedFamilies([.systemExtraLarge])
        .contentMarginsDisabled()
    }
}

private struct BoardView: View {
    let entry: DeskEntry

    var body: some View {
        if entry.status != .ok || entry.hero == nil {
            StatusView(status: entry.status == .ok ? .noData : entry.status)
        } else if let pick = entry.hero {
            HStack(spacing: 0) {
                BoardFeature(entry: entry, pick: pick)
                    .frame(width: 452)
                BoardQueue(entry: entry)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct BoardFeature: View {
    let entry: DeskEntry
    let pick: Pick
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            BackdropFill(pick: pick, maxPixel: 900)
                .opacity(renderingMode == .fullColor ? 1 : 0.5)
                .invalidatableContent()
            if renderingMode == .fullColor {
                LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                LinearGradient(colors: [.clear, .black.opacity(0.35)], startPoint: .leading, endPoint: .trailing)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(PickFormatting.reasonLine(pick))
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundStyle(Color.white.opacity(0.75))
                Text(pick.title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .contentTransition(.interpolate)
                    .animation(.smooth(duration: 0.45).delay(0.1), value: pick.id)
                HStack(spacing: 8) {
                    if let rating = pick.rating {
                        FullRatingBadge(rating: rating, size: 12, color: .white)
                    }
                    Text(PickFormatting.metaLine(pick, maxGenres: 2))
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.8))
                        .lineLimit(1)
                }
                if let overview = pick.overview?.nilIfEmpty ?? pick.tagline?.nilIfEmpty {
                    Text(overview)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .lineLimit(3)
                        .id(pick.id)
                        .transition(.opacity.combined(with: .offset(y: 6)))
                        .animation(.smooth(duration: 0.45).delay(0.18), value: pick.id)
                }
                HStack(spacing: 8) {
                    ServiceChip(pick: pick, height: 30)
                    SaveToggle(pick: pick, isSaved: entry.isSaved(pick), size: 30)
                    HideButton(lane: entry.lane, slot: 0, pick: pick, size: 30)
                    NextButton(lane: entry.lane, slot: 0, pick: pick, size: 30, enabled: entry.canAdvance)
                    Spacer(minLength: 0)
                    if let finish = PickFormatting.finishText(pick, from: entry.date) {
                        Text(finish)
                            .font(.system(size: 10.5, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.7))
                            .contentTransition(.numericText())
                    }
                }
                .padding(.top, 4)
            }
            .padding(18)
        }
        .clipped()
        .overlay(alignment: .top) {
            if entry.showsUndo { UndoPill(lane: entry.lane).padding(.top, 10) }
        }
    }
}

private struct BoardQueue: View {
    let entry: DeskEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Dalej")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .widgetAccentable()
                if let summary = entry.lane.filter.summary {
                    Text(summary)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                ShuffleButton(entry: entry, size: 26)
            }

            if let days = entry.staleDays {
                StaleNotice(days: days)
            }

            VStack(spacing: 6) {
                ForEach(entry.upNext) { pick in
                    Button(intent: JumpToPickIntent(lane: entry.lane, pickID: pick.id)) {
                        QueueRow(pick: pick)
                    }
                    .buttonStyle(.plain)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .scale(scale: 0.8).combined(with: .opacity)
                    ))
                }
            }
            .animation(.snappy(duration: 0.45), value: entry.upNext.map(\.id))

            Spacer(minLength: 0)

            LinksGrid(links: Array(entry.links.prefix(8)), columns: 8, glyphSize: 22)
        }
        .padding(16)
    }
}

private struct QueueRow: View {
    let pick: Pick

    var body: some View {
        HStack(spacing: 10) {
            PosterThumb(pick: pick, maxPixel: 130, cornerRadius: 6)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(pick.title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Text(PickFormatting.metaLine(pick))
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if let rating = pick.rating {
                RatingBadge(rating: rating)
            }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.05)))
        .contentShape(Rectangle())
        .accessibilityLabel("Pokaż \(pick.title)")
    }
}

#Preview("Wieczór", as: .systemExtraLarge) {
    BoardWidget()
} timeline: {
    DeskEntry.sample(kind: .board)
}
