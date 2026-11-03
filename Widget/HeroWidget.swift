import SwiftUI
import WidgetKit

/// „Jeden na dziś” — jeden tytuł w dużym formacie: kadr, plakat, opis i szybkie akcje.
struct HeroWidget: Widget {
    static let kind = "MovieDeskHero"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: DeskConfigurationIntent.self, provider: DeskProvider(kind: .hero)) { entry in
            HeroView(entry: entry)
                .containerBackground(for: .widget) { HeroBackground(entry: entry) }
        }
        .configurationDisplayName("Jeden na dziś")
        .description("Jeden tytuł na dziś: duży plakat, opis i szybkie akcje.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

/// Tło zależy od rozmiaru: mały — kadr z ciemnym gradientem, średni — rozmyty kadr,
/// duży — zwykłe tło (kadr jest w treści).
private struct HeroBackground: View {
    let entry: DeskEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:
            BackdropFill(pick: entry.hero, maxPixel: 360)
                .overlay {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.15), .black.opacity(0.78)],
                        startPoint: .top, endPoint: .bottom
                    )
                }
        case .systemMedium:
            BackdropFill(pick: entry.hero, maxPixel: 300, blur: 28)
                .overlay {
                    LinearGradient(
                        colors: [
                            (entry.hero?.tint ?? .gray).opacity(0.25),
                            Color.black.opacity(0.45),
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                }
        default:
            WidgetBackdrop()
        }
    }
}

private struct HeroView: View {
    let entry: DeskEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.showsWidgetContainerBackground) private var hasBackground

    var body: some View {
        if entry.status != .ok || entry.hero == nil {
            StatusView(status: entry.status == .ok ? .noData : entry.status, entry: entry)
        } else if let pick = entry.hero {
            switch family {
            case .systemSmall:
                if hasBackground {
                    HeroSmall(entry: entry, pick: pick)
                } else {
                    HeroSmallCompact(entry: entry, pick: pick)
                }
            case .systemMedium:
                HeroMedium(entry: entry, pick: pick, onImage: hasBackground)
            default:
                HeroLarge(entry: entry, pick: pick)
            }
        }
    }
}

// MARK: - Mały

private struct HeroSmall: View {
    let entry: DeskEntry
    let pick: Pick

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 4) {
                ScenarioButton(entry: entry, compact: true, size: 26)
                KindMark(kind: pick.kind, size: 18)
                Spacer()
                NextButton(lane: entry.lane, slot: 0, pick: pick, size: 26, enabled: entry.canAdvance)
            }
            Spacer(minLength: 0)
            HeroTitle(pick: pick, size: 14, lines: 2)
                .foregroundStyle(.white)
            HStack(spacing: 5) {
                if let rating = pick.rating {
                    RatingBadge(rating: rating)
                }
                Text(smallMeta)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.8))
                    .lineLimit(1)
            }
        }
        .padding(12)
        .widgetURL(DeepLink.url(for: pick.openURL))
        .overlay(alignment: .bottom) {
            if entry.showsUndo { UndoPill(lane: entry.lane).padding(.bottom, 6) }
        }
    }

    private var smallMeta: String {
        [pick.year.map(String.init), pick.destinationName].compactMap { $0 }.joined(separator: " · ")
    }
}

/// Mały w trybie przezroczystym: bez tła z kadru, więc plakat obok tytułu.
private struct HeroSmallCompact: View {
    let entry: DeskEntry
    let pick: Pick

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                PosterThumb(pick: pick, maxPixel: 180)
                    .frame(width: 60)
                    .id(pick.id)
                    .transition(.push(from: .bottom))
                Spacer(minLength: 0)
                VStack(spacing: 6) {
                    NextButton(lane: entry.lane, slot: 0, pick: pick, size: 26, enabled: entry.canAdvance)
                    ScenarioButton(entry: entry, compact: true, size: 26)
                }
            }
            .animation(.spring(duration: 0.55, bounce: 0.2), value: pick.id)
            HeroTitle(pick: pick, size: 13, lines: 2)
            Text(PickFormatting.metaLine(pick))
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .widgetURL(DeepLink.url(for: pick.openURL))
    }
}

// MARK: - Średni

private struct HeroMedium: View {
    let entry: DeskEntry
    let pick: Pick
    let onImage: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Link(destination: DeepLink.url(for: pick.openURL) ?? DeepLink.syncURL) {
                PosterThumb(pick: pick, maxPixel: 300, cornerRadius: 10)
            }
            .frame(width: 96)
            .id(pick.id)
            .transition(.push(from: .bottom).combined(with: .opacity))
            .animation(.spring(duration: 0.55, bounce: 0.2).delay(0.05), value: pick.id)
            .invalidatableContent()

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    ScenarioButton(entry: entry, compact: true, size: 18)
                    Text(PickFormatting.reasonLine(pick))
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .textCase(.uppercase)
                        .tracking(0.4)
                        .foregroundStyle(secondary)
                        .lineLimit(1)
                }
                HeroTitle(pick: pick, size: 16, lines: 2)
                    .foregroundStyle(primary)
                Text(PickFormatting.metaLine(pick, maxGenres: 2))
                    .font(.system(size: 10.5, design: .rounded))
                    .foregroundStyle(secondary)
                    .lineLimit(1)
                HeroOverview(pick: pick, size: 11, lines: 3)
                    .foregroundStyle(secondary)
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    if let rating = pick.rating {
                        FullRatingBadge(rating: rating, size: 11, color: primary)
                    }
                    ServiceChip(pick: pick, height: 22)
                    Spacer(minLength: 0)
                    HideButton(lane: entry.lane, slot: 0, pick: pick, size: 24)
                    SaveToggle(pick: pick, isSaved: entry.isSaved(pick), size: 24)
                    NextButton(lane: entry.lane, slot: 0, pick: pick, size: 24, enabled: entry.canAdvance)
                }
            }
        }
        .padding(12)
        .overlay(alignment: .bottom) {
            if entry.showsUndo { UndoPill(lane: entry.lane).padding(.bottom, 6) }
        }
    }

    private var primary: Color { onImage ? .white : .primary }
    private var secondary: Color { onImage ? .white.opacity(0.75) : .secondary }
}

// MARK: - Duży

private struct HeroLarge: View {
    let entry: DeskEntry
    let pick: Pick
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                BackdropFill(pick: pick, maxPixel: 740)
                    .frame(height: 150)
                    .opacity(renderingMode == .fullColor ? 1 : 0.6)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(alignment: .bottom) {
                        if renderingMode == .fullColor {
                            LinearGradient(colors: [.clear, .black.opacity(0.35)], startPoint: .top, endPoint: .bottom)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                    .invalidatableContent()

                UpNextStrip(entry: entry)
                    .padding(8)
            }
            .overlay(alignment: .topLeading) {
                ScenarioButton(entry: entry, size: 24).padding(8)
            }

            HStack(alignment: .top, spacing: 12) {
                Link(destination: DeepLink.url(for: pick.openURL) ?? DeepLink.syncURL) {
                    PosterThumb(pick: pick, maxPixel: 260, cornerRadius: 10)
                }
                .frame(width: 70)
                .id(pick.id)
                .transition(.push(from: .bottom).combined(with: .opacity))
                .animation(.spring(duration: 0.55, bounce: 0.2).delay(0.05), value: pick.id)

                VStack(alignment: .leading, spacing: 4) {
                    HeroTitle(pick: pick, size: 18, lines: 2)
                    Text(PickFormatting.metaLine(pick, maxGenres: 2))
                        .font(.system(size: 10.5, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        if let rating = pick.rating {
                            FullRatingBadge(rating: rating, size: 11.5)
                        }
                        Text(PickFormatting.reasonLine(pick))
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            HeroOverview(pick: pick, size: 11.5, lines: 4)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            if let days = entry.staleDays {
                StaleNotice(days: days)
            } else if let finish = PickFormatting.finishText(pick, from: entry.date) {
                Text(finish)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }

            HStack(spacing: 8) {
                ServiceChip(pick: pick, height: 26)
                Spacer(minLength: 0)
                HideButton(lane: entry.lane, slot: 0, pick: pick, size: 28)
                SaveToggle(pick: pick, isSaved: entry.isSaved(pick), size: 28)
                NextButton(lane: entry.lane, slot: 0, pick: pick, size: 28, enabled: entry.canAdvance)
            }
        }
        .padding(14)
        .overlay(alignment: .bottom) {
            if entry.showsUndo { UndoPill(lane: entry.lane).padding(.bottom, 48) }
        }
    }
}

/// Pionowy pasek „Dalej” na kadrze: kliknięcie miniatury przenosi tytuł na główne miejsce.
private struct UpNextStrip: View {
    let entry: DeskEntry

    var body: some View {
        VStack(spacing: 6) {
            ForEach(entry.upNext) { pick in
                Button(intent: JumpToPickIntent(lane: entry.lane, pickID: pick.id)) {
                    PosterThumb(pick: pick, maxPixel: 110, cornerRadius: 6)
                        .frame(width: 30)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Pokaż \(pick.title)")
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .scale(scale: 0.8).combined(with: .opacity)
                ))
            }
        }
        .animation(.snappy(duration: 0.45), value: entry.upNext.map(\.id))
    }
}

// MARK: - Tekst

/// Tytuł — ta sama tożsamość widoku, więc przy zmianie tytułu tekst płynnie się przenika.
private struct HeroTitle: View {
    let pick: Pick
    let size: CGFloat
    let lines: Int

    var body: some View {
        Text(pick.title)
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .lineLimit(lines)
            .minimumScaleFactor(0.85)
            .contentTransition(.interpolate)
            .animation(.smooth(duration: 0.45).delay(0.1), value: pick.id)
    }
}

private struct HeroOverview: View {
    let pick: Pick
    let size: CGFloat
    let lines: Int

    var body: some View {
        if let text = pick.overview?.nilIfEmpty ?? pick.tagline?.nilIfEmpty {
            Text(text)
                .font(.system(size: size, design: .rounded))
                .lineLimit(lines)
                .id(pick.id)
                .transition(.opacity.combined(with: .offset(y: 6)))
                .animation(.smooth(duration: 0.45).delay(0.18), value: pick.id)
        }
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

#Preview("Jeden — mały", as: .systemSmall) {
    HeroWidget()
} timeline: {
    DeskEntry.sample(kind: .hero)
}

#Preview("Jeden — średni", as: .systemMedium) {
    HeroWidget()
} timeline: {
    DeskEntry.sample(kind: .hero)
}

#Preview("Jeden — duży", as: .systemLarge) {
    HeroWidget()
} timeline: {
    DeskEntry.sample(kind: .hero)
}
