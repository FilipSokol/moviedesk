import AppKit
import SwiftUI
import WidgetKit

/// Animacje zmiany tytułów — „tasowanie kart”.
///
/// Każde miejsce (stała tożsamość) obraca się wokół pionowej osi o 360° × licznik obrotów,
/// z lekką perspektywą i sprężystym dobiciem; kolumny startują po kolei. W połowie obrotu
/// karta jest bokiem do widza i wtedy podmienia się zawartość (przenikanie + skala),
/// a po plakacie przechodzi odblask. „Wstecz” zmniejsza licznik, więc karta obraca się
/// w drugą stronę. Wszystko to są interpolowane właściwości i wbudowane przejścia —
/// WidgetKit odtwarza je między kolejnymi stanami widgetu.
enum DeskTransitions {
    static func insertion(for event: LaneEvent?) -> AnyTransition {
        switch event?.kind {
        case .hide:
            return .scale(scale: 0.6).combined(with: .opacity).combined(with: .move(edge: .bottom))
        case .undo:
            return .scale(scale: 1.2).combined(with: .opacity)
        case .scenario:
            return AnyTransition(.blurReplace).combined(with: .scale(scale: 0.8))
        case .next, .shuffle, .jump, .back:
            return .opacity.combined(with: .scale(scale: 0.82))
        case nil:
            // Nowa pula po nocnej synchronizacji.
            return AnyTransition(.blurReplace).combined(with: .scale(scale: 0.95))
        }
    }

    static let removal: AnyTransition = .opacity.combined(with: .scale(scale: 1.12))

    static func card(for event: LaneEvent?) -> AnyTransition {
        .asymmetric(insertion: insertion(for: event), removal: removal)
    }

    /// Kolumny po kolei: 0 / 90 / 180 ms, sprężyna z wyraźnym dobiciem.
    static func slotAnimation(_ slot: Int) -> Animation {
        .spring(duration: 0.85, bounce: 0.28).delay(Double(slot) * 0.09)
    }
}

/// Obrót karty + odblask. Nakładane na miejsce (nie na kartę), żeby przetrwało zmianę tytułu
/// i dało się je płynnie interpolować.
struct CardFlip: ViewModifier {
    let turns: Int
    let slot: Int
    var cornerRadius: CGFloat = 10
    @Environment(\.widgetRenderingMode) private var renderingMode

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if renderingMode == .fullColor {
                    Sheen(phase: turns, slot: slot)
                        .aspectRatio(2.0 / 3.0, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                        .allowsHitTesting(false)
                }
            }
            .rotation3DEffect(
                .degrees(Double(turns) * 360),
                axis: (x: 0, y: 1, z: 0),
                anchor: .center,
                perspective: 0.55
            )
            .animation(DeskTransitions.slotAnimation(slot), value: turns)
    }
}

/// Smuga światła przesuwająca się po plakacie przy każdym obrocie
/// (parzysty licznik — smuga po lewej, nieparzysty — po prawej, więc zawsze przelatuje).
private struct Sheen: View {
    let phase: Int
    let slot: Int

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            LinearGradient(
                colors: [.clear, .white.opacity(0.08), .white.opacity(0.55), .white.opacity(0.08), .clear],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(width: width * 0.7, height: geometry.size.height * 1.6)
            .rotationEffect(.degrees(20))
            .offset(x: phase.isMultiple(of: 2) ? -width * 1.3 : width * 1.3, y: -geometry.size.height * 0.3)
            .blendMode(.plusLighter)
            .animation(.easeInOut(duration: 0.9).delay(0.3 + Double(slot) * 0.09), value: phase)
        }
    }
}

/// Polecenie w menu kontekstowym plakatu (tylko w aplikacji).
struct PickMenuAction: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    var role: ButtonRole? = nil
    let action: () -> Void
}

/// Trzy plakaty obok siebie. Każde miejsce ma stałą tożsamość, a plakat w środku zmienia się
/// razem z tytułem — animuje się tylko to miejsce, w którym tytuł się zmienił; przy
/// „pokaż kolejne” wszystkie trzy, z opóźnieniem między kolumnami.
/// Ten sam widok działa w widgecie i w panelu z paska menu.
struct PicksRow: View {
    let picks: [Pick]
    var event: LaneEvent? = nil
    /// Dokąd prowadzi kliknięcie w plakat (widget: deep link przez aplikację, panel: wprost).
    let destination: (Pick) -> URL?
    var slots = 3
    var titleSize: CGFloat = 10
    var posterPixels: CGFloat = 260
    /// Dymek z opisem po najechaniu — tylko w aplikacji, widgety nie obsługują kursora.
    var showsDetailsOnHover = false
    var menu: ((Int, Pick) -> [PickMenuAction])? = nil
    /// Liczniki obrotów miejsc (z pasa); puste — bez obrotów.
    var flips: [Int] = []
    /// Stała szerokość plakatu. Potrzebna w panelu z paska menu: okno dopasowuje się do
    /// treści i nie podaje plakatom szerokości, więc bez tego zwijały się do kropki.
    var posterWidth: CGFloat? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(0..<slots, id: \.self) { slot in
                ZStack {
                    if slot < picks.count {
                        PickCard(
                            pick: picks[slot],
                            destination: destination(picks[slot]),
                            titleSize: titleSize,
                            posterPixels: posterPixels,
                            showsDetailsOnHover: showsDetailsOnHover,
                            menu: menu?(slot, picks[slot]) ?? [],
                            posterWidth: posterWidth
                        )
                        .id(picks[slot].id)
                        .transition(DeskTransitions.card(for: event))
                    } else {
                        SlotPlaceholder()
                    }
                }
                .frame(maxWidth: .infinity)
                .animation(DeskTransitions.slotAnimation(slot), value: slot < picks.count ? picks[slot].id : "")
                .modifier(CardFlip(turns: flips.indices.contains(slot) ? flips[slot] : 0, slot: slot))
            }
        }
    }
}

private struct PickCard: View {
    let pick: Pick
    let destination: URL?
    let titleSize: CGFloat
    let posterPixels: CGFloat
    let showsDetailsOnHover: Bool
    let menu: [PickMenuAction]
    var posterWidth: CGFloat? = nil

    var body: some View {
        // Menu i dymek tylko w aplikacji — w widgecie nie zadziałają.
        if showsDetailsOnHover {
            linked
                .contextMenu {
                    ForEach(menu) { item in
                        Button(item.title, systemImage: item.systemImage, role: item.role, action: item.action)
                    }
                }
                .modifier(HoverDetails(pick: pick))
        } else {
            linked
        }
    }

    @ViewBuilder
    private var linked: some View {
        if let destination {
            if showsDetailsOnHover {
                // W aplikacji: zwykły przycisk. `Link` na macOS zgniata zawartość do
                // minimalnego rozmiaru (plakat stawał się kropką) i barwi tekst na niebiesko.
                Button {
                    NSWorkspace.shared.open(destination)
                } label: {
                    content
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(pick.title), \(pick.destinationName)")
            } else {
                // W widgecie przyciski z akcją nie działają — tylko `Link`.
                Link(destination: destination) { content }
                    .accessibilityLabel("\(pick.title), \(pick.destinationName)")
            }
        } else {
            content
        }
    }

    private var content: some View {
        VStack(spacing: 5) {
            PickPoster(pick: pick, maxPixel: posterPixels)
                .frame(width: posterWidth, height: posterWidth.map { $0 * 1.5 })
            Text(pick.title)
                .font(.system(size: titleSize, weight: .medium, design: .rounded))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

struct PickPoster: View {
    let pick: Pick
    var cornerRadius: CGFloat = 10
    var maxPixel: CGFloat = 300
    var showsBadges = true

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        Color.clear
            .frame(maxWidth: .infinity)
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .overlay {
                if let image = ImageStore.poster(for: pick, maxPixel: maxPixel) {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .widgetAccentedRenderingMode(.fullColor)
                        .scaledToFill()
                } else {
                    PosterPlaceholder(title: pick.title, tint: pick.tint)
                }
            }
            .overlay(alignment: .bottomLeading) {
                if showsBadges, let rating = pick.rating {
                    RatingBadge(rating: rating).padding(4)
                }
            }
            .overlay(alignment: .topLeading) {
                if showsBadges, let mine = pick.myRating {
                    WatchedBadge(rating: mine).padding(4)
                }
            }
            .overlay(alignment: .topTrailing) {
                if showsBadges {
                    HStack(spacing: 3) {
                        KindMark(kind: pick.kind)
                        if let service = pick.service {
                            ServiceDot(service: service)
                        }
                    }
                    .padding(4)
                }
            }
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.45), .white.opacity(0.04)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 0.75
                )
            }
            .shadow(color: .black.opacity(0.22), radius: 5, y: 3)
    }
}

/// Mała szklana plakietka z oceną, np. „IMDb 7,8”.
struct RatingBadge: View {
    let rating: Rating

    var body: some View {
        HStack(spacing: 3) {
            Text(rating.source.shortLabel)
                .font(.system(size: 7.5, weight: .bold, design: .rounded))
                .opacity(0.75)
            Text(rating.formatted)
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Capsule().fill(Color.black.opacity(0.55)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5))
        .accessibilityLabel("Ocena \(rating.source.fullLabel) \(rating.formatted)")
    }
}

/// Znaczek serwisu: prawdziwe logo (z TMDB), a dopóki go nie ma — inicjał w kolorze marki.
/// „✓ 8” — już to widziałeś i tak oceniłeś na Filmwebie.
struct WatchedBadge: View {
    let rating: Int

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "checkmark")
                .font(.system(size: 7, weight: .black))
            Text("\(rating)")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Capsule().fill(Color.green.opacity(0.85)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5))
        .accessibilityLabel("Widziałeś, Twoja ocena \(rating)")
    }
}

struct ServiceDot: View {
    let service: StreamingService
    var size: CGFloat = 16

    var body: some View {
        ServiceMark(service: service, size: size)
    }
}

/// Znaczek dla tytułów spoza „W Twoim guście”: z listy albo do powtórki.
struct KindMark: View {
    let kind: Pick.Kind
    var size: CGFloat = 14

    var body: some View {
        if let symbol {
            Image(systemName: symbol)
                .font(.system(size: size * 0.55, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Circle().fill(Color.black.opacity(0.55)))
                .accessibilityLabel(kind.label)
        }
    }

    private var symbol: String? {
        switch kind {
        case .discovery: nil
        case .wanted: "list.star"
        case .rewatch: "arrow.counterclockwise"
        }
    }
}

struct SlotPlaceholder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .foregroundStyle(Color.secondary.opacity(0.5))
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .overlay {
                Text("Brak więcej")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
    }
}

struct PosterPlaceholder: View {
    let title: String
    let tint: Color

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [tint.opacity(0.55), tint.opacity(0.15)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .padding(6)
        }
    }
}

/// Po chwili najechania pokazuje dymek z opisem, oceną i serwisem.
private struct HoverDetails: ViewModifier {
    let pick: Pick
    @State private var isShown = false
    @State private var hoverTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onHover { inside in
                hoverTask?.cancel()
                if inside {
                    hoverTask = Task {
                        try? await Task.sleep(for: .milliseconds(450))
                        if !Task.isCancelled { isShown = true }
                    }
                } else {
                    isShown = false
                }
            }
            .popover(isPresented: $isShown, arrowEdge: .bottom) {
                PickDetails(pick: pick)
            }
    }
}

struct PickDetails: View {
    let pick: Pick

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(pick.title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
            let meta = PickFormatting.metaLine(pick, maxGenres: 2)
            if !meta.isEmpty {
                Text(meta).font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                if let rating = pick.rating {
                    RatingBadge(rating: rating)
                }
                Text("\(pick.destinationName) · \(PickFormatting.reasonLine(pick))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let overview = pick.overview, !overview.isEmpty {
                Text(overview)
                    .font(.callout)
                    .lineLimit(8)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(width: 290, alignment: .leading)
    }
}

/// Mały okrągły przycisk „pokaż kolejne”. Strzałka robi pełny obrót przy każdym kliknięciu;
/// licznik tylko rośnie, więc po nocnej synchronizacji nie kręci się do tyłu.
struct ShuffleGlyph: View {
    let tapCounter: Int
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: "arrow.clockwise")
            .font(.system(size: size * 0.43, weight: .semibold))
            .rotationEffect(.degrees(Double(tapCounter) * 360))
            .animation(.spring(duration: 0.6, bounce: 0.3), value: tapCounter)
            .frame(width: size, height: size)
            .background(Circle().fill(Color.white.opacity(0.12)))
            .overlay(Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5))
            .contentShape(Circle())
            .widgetAccentable()
            .accessibilityLabel("Pokaż kolejne")
    }
}
