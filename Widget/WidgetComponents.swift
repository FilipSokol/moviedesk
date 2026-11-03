import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Tło

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

/// Tło z kadru filmu (albo plakatu, gdy kadru brak), z płynnym przejściem przy zmianie tytułu.
struct BackdropFill: View {
    let pick: Pick?
    var maxPixel: CGFloat = 760
    var blur: CGFloat = 0

    var body: some View {
        ZStack {
            WidgetBackdrop()
            if let pick, let image = ImageStore.backdrop(for: pick, maxPixel: maxPixel)
                ?? ImageStore.poster(for: pick, maxPixel: maxPixel) {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .widgetAccentedRenderingMode(.accentedDesaturated)
                    .scaledToFill()
                    .blur(radius: blur)
                    .id(pick.id)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 1.08)),
                        removal: .opacity
                    ))
            }
        }
        .animation(.easeOut(duration: 0.9), value: pick?.id)
        .clipped()
    }
}

// MARK: - Przyciski

/// Szklane kółko z symbolem — wygląd wszystkich akcji w widgetach.
struct ActionCircle: View {
    let symbol: String
    let label: String
    var size: CGFloat = 24

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .frame(width: size, height: size)
            .background(Circle().fill(Color.white.opacity(0.14)))
            .overlay(Circle().strokeBorder(Color.white.opacity(0.32), lineWidth: 0.5))
            .contentShape(Circle())
            .widgetAccentable()
            .accessibilityLabel(label)
    }
}

struct NextButton: View {
    let lane: DeskLane
    let slot: Int
    let pick: Pick
    var size: CGFloat = 24
    var enabled = true

    var body: some View {
        if enabled {
            Button(intent: NextPickIntent(lane: lane, slot: slot, pickID: pick.id)) {
                ActionCircle(symbol: "forward.fill", label: "Inny tytuł", size: size)
            }
            .buttonStyle(.plain)
        } else {
            ActionCircle(symbol: "forward.fill", label: "Brak innych tytułów", size: size)
                .opacity(0.35)
        }
    }
}

struct HideButton: View {
    let lane: DeskLane
    let slot: Int
    let pick: Pick
    var size: CGFloat = 24

    var body: some View {
        Button(intent: HidePickIntent(lane: lane, slot: slot, pickID: pick.id)) {
            ActionCircle(symbol: "eye.slash", label: "Nie pokazuj więcej", size: size)
        }
        .buttonStyle(.plain)
    }
}

struct SaveToggle: View {
    let pick: Pick
    let isSaved: Bool
    var size: CGFloat = 24

    var body: some View {
        Toggle(isOn: isSaved, intent: SetSavedIntent(pickID: pick.id)) {
            ActionCircle(
                symbol: isSaved ? "bookmark.fill" : "bookmark",
                label: isSaved ? "Usuń z zapisanych" : "Zapisz na później",
                size: size
            )
            .contentTransition(.symbolEffect(.replace))
        }
        .toggleStyle(.button)
        .buttonStyle(.plain)
        .animation(.snappy, value: isSaved)
    }
}

struct ShuffleButton: View {
    let entry: DeskEntry
    var size: CGFloat = 28

    var body: some View {
        if entry.canAdvance {
            Button(intent: ShuffleLaneIntent(lane: entry.lane)) {
                ShuffleGlyph(tapCounter: entry.tapCounter, size: size)
            }
            .buttonStyle(.plain)
        } else {
            ShuffleGlyph(tapCounter: entry.tapCounter, size: size).opacity(0.35)
        }
    }
}

/// „Ukryto · Cofnij” — przez kilka sekund po ukryciu tytułu.
struct UndoPill: View {
    let lane: DeskLane

    var body: some View {
        Button(intent: UndoHideIntent(lane: lane)) {
            Label("Ukryto · Cofnij", systemImage: "arrow.uturn.backward")
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.black.opacity(0.6)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - Informacje o tytule

/// „▶ Netflix” — otwiera tytuł w serwisie.
struct ServiceChip: View {
    let pick: Pick
    var height: CGFloat = 24

    var body: some View {
        let label = HStack(spacing: 4) {
            Image(systemName: "play.fill")
                .font(.system(size: height * 0.38, weight: .bold))
            Text(pick.service.displayName)
                .font(.system(size: height * 0.44, weight: .semibold, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, height * 0.45)
        .frame(height: height)
        .background(Capsule().fill(pick.service.tint.gradient))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 0.5))
        .widgetAccentable()

        if let url = DeepLink.url(for: pick.openURL) {
            Link(destination: url) { label }
                .accessibilityLabel("Obejrzyj w \(pick.service.displayName)")
        } else {
            label
        }
    }
}

/// „★ 7,8 IMDb” — większa ocena, cyfry przewijają się przy zmianie tytułu.
struct FullRatingBadge: View {
    let rating: Rating
    var size: CGFloat = 11
    var color: Color = .primary

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "star.fill")
                .font(.system(size: size * 0.85))
                .foregroundStyle(.yellow)
                .widgetAccentable()
            Text(rating.formatted)
                .font(.system(size: size, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(value: rating.value))
            Text(rating.source.fullLabel)
                .font(.system(size: size * 0.85, weight: .medium, design: .rounded))
                .opacity(0.7)
        }
        .foregroundStyle(color)
        .accessibilityElement(children: .combine)
    }
}

/// Plakat bez linku i bez plakietek (do miniatur i dużych układów).
struct PosterThumb: View {
    let pick: Pick
    var maxPixel: CGFloat = 200
    var cornerRadius: CGFloat = 8

    var body: some View {
        PickPoster(pick: pick, cornerRadius: cornerRadius, maxPixel: maxPixel, showsBadges: false)
    }
}

// MARK: - Stany

struct StatusView: View {
    let status: DeskEntry.Status

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .medium))
                .widgetAccentable()
            Text(message)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var symbol: String {
        switch status {
        case .noAppGroup: "exclamationmark.triangle"
        case .filteredEmpty: "line.3.horizontal.decrease.circle"
        default: "film.stack"
        }
    }

    private var message: String {
        switch status {
        case .noAppGroup: "Widget nie widzi danych MovieDesk.\nSprawdź Team ID w konfiguracji."
        case .filteredEmpty: "Brak tytułów dla tych ustawień.\nZmień je w „Edytuj widżet”."
        default: "Propozycje pojawią się\npo synchronizacji w MovieDesk."
        }
    }
}

/// „Dane sprzed 3 dni · odśwież” — gdy nocna synchronizacja od dawna się nie udała.
struct StaleNotice: View {
    let days: Int

    var body: some View {
        Link(destination: DeepLink.syncURL) {
            Label("Dane sprzed \(days) dni · odśwież", systemImage: "exclamationmark.arrow.circlepath")
                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.orange)
        }
    }
}

// MARK: - Linki

/// Małe okrągłe skróty do stron w siatce.
struct LinksGrid: View {
    let links: [QuickLink]
    let columns: Int
    let glyphSize: CGFloat
    var showsNames = false
    var spacing: CGFloat = 6

    var body: some View {
        let perRow = max(1, columns)
        let rows = stride(from: 0, to: links.count, by: perRow).map {
            Array(links[$0..<min($0 + perRow, links.count)])
        }
        Grid(horizontalSpacing: spacing, verticalSpacing: spacing) {
            ForEach(rows.indices, id: \.self) { index in
                GridRow {
                    ForEach(rows[index]) { link in
                        LinkChip(link: link, size: glyphSize, showsName: showsNames)
                    }
                }
            }
        }
    }
}

struct LinkChip: View {
    let link: QuickLink
    let size: CGFloat
    var showsName = false

    var body: some View {
        let content = VStack(spacing: 4) {
            LinkGlyph(link: link, size: size)
            if showsName {
                Text(link.name)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .lineLimit(1)
                    .frame(maxWidth: size + 18)
            }
        }
        if let destination = DeepLink.url(for: link) {
            Link(destination: destination) { content }
                .accessibilityLabel(link.name)
        } else {
            content.opacity(0.4)
        }
    }
}
