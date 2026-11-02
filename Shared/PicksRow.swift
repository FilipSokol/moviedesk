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

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(0..<PicksStore.pageSize, id: \.self) { slot in
                ZStack {
                    if slot < picks.count {
                        PickCard(pick: picks[slot], destination: destination(picks[slot]), titleSize: titleSize)
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

    var body: some View {
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
