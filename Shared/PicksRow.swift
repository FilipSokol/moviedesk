import SwiftUI
import WidgetKit

/// Trzy plakaty obok siebie. Każde miejsce ma stałą tożsamość, a plakat w środku zmienia się
/// razem z filmem — dzięki temu zmiana kursora animuje „przetasowanie”: nowe plakaty wjeżdżają
/// z prawej, stare wyjeżdżają w lewo, z lekkim opóźnieniem między kolumnami.
/// Ten sam widok działa w widgecie i w panelu z paska menu.
struct PicksRow: View {
    let picks: [Pick]
    let cursor: Int
    /// Dokąd prowadzi kliknięcie w plakat (widget: deep link przez aplikację, panel: wprost).
    let destination: (Pick) -> URL?
    var titleSize: CGFloat = 10
    /// Dymek z opisem po najechaniu — tylko w aplikacji, widgety nie obsługują kursora.
    var showsDetailsOnHover = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(0..<PicksStore.pageSize, id: \.self) { slot in
                ZStack {
                    if slot < picks.count {
                        PickCard(
                            pick: picks[slot],
                            destination: destination(picks[slot]),
                            titleSize: titleSize,
                            showsDetailsOnHover: showsDetailsOnHover
                        )
                        .id(picks[slot].id)
                        .transition(
                            .asymmetric(
                                insertion: .push(from: .trailing).combined(with: .scale(scale: 0.86)),
                                removal: .push(from: .trailing).combined(with: .scale(scale: 0.9))
                            )
                        )
                    } else {
                        Color.clear
                    }
                }
                .frame(maxWidth: .infinity)
                .animation(
                    .spring(response: 0.55, dampingFraction: 0.78).delay(Double(slot) * 0.08),
                    value: cursor
                )
            }
        }
    }
}

private struct PickCard: View {
    let pick: Pick
    let destination: URL?
    let titleSize: CGFloat
    let showsDetailsOnHover: Bool

    var body: some View {
        if showsDetailsOnHover {
            linked.modifier(HoverDetails(pick: pick))
        } else {
            linked
        }
    }

    @ViewBuilder
    private var linked: some View {
        if let destination {
            Link(destination: destination) { content }
        } else {
            content
        }
    }

    private var content: some View {
        VStack(spacing: 5) {
            PickPoster(pick: pick)
            Text(pick.title)
                .font(.system(size: titleSize, weight: .medium, design: .rounded))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(.primary)
        }
    }
}

struct PickPoster: View {
    let pick: Pick
    var cornerRadius: CGFloat = 10

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        Color.clear
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .overlay {
                if let image = PicksStore.posterImage(for: pick) {
                    Image(nsImage: image)
                        .resizable()
                        .widgetAccentedRenderingMode(.fullColor)
                        .scaledToFill()
                } else {
                    PosterPlaceholder(title: pick.title, tint: pick.service.tint)
                }
            }
            .overlay(alignment: .bottomLeading) {
                if let rating = pick.rating {
                    RatingBadge(rating: rating).padding(4)
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
    }
}

private struct PosterPlaceholder: View {
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
            HStack(spacing: 6) {
                if let rating = pick.rating {
                    RatingBadge(rating: rating)
                }
                Text("\(pick.service.displayName) · \(pick.kind.label)")
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

/// Mały okrągły przycisk „odśwież”. Strzałka obraca się o pełny obrót przy każdej zmianie kursora.
struct ShuffleGlyph: View {
    let cursor: Int
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: "arrow.clockwise")
            .font(.system(size: size * 0.43, weight: .semibold))
            .rotationEffect(.degrees(Double(cursor / PicksStore.pageSize) * 360))
            .animation(.spring(response: 0.7, dampingFraction: 0.7), value: cursor)
            .frame(width: size, height: size)
            .background(Circle().fill(Color.white.opacity(0.12)))
            .overlay(Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5))
            .contentShape(Circle())
            .widgetAccentable()
    }
}
