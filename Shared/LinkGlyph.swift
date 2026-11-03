import SwiftUI
import WidgetKit

/// Okrągła ikona z inicjałem — wspólna dla widgetu i aplikacji.
/// W trybach accented/vibrant (przezroczyste i tintowane widgety na pulpicie)
/// rezygnuje z koloru i oddaje inicjał systemowemu akcentowi.
struct LinkGlyph: View {
    let link: QuickLink
    var size: CGFloat = 34

    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        if let service = link.url.flatMap(StreamingService.detect(in:)) {
            // Link do rozpoznanego serwisu — jednolity znaczek marki.
            ServiceMark(service: service, size: size)
        } else if let url = link.url, let icon = LinkIcon.image(for: url, maxPixel: size * 3) {
            // Zwykła strona — jej favikona: na całe kółko albo pomniejszona na jasnym tle.
            ZStack {
                if icon.style == .padded {
                    Circle().fill(Color.white)
                }
                Image(decorative: icon.image, scale: 1)
                    .resizable()
                    .widgetAccentedRenderingMode(.fullColor)
                    .scaledToFit()
                    .frame(
                        width: icon.style == .padded ? size * 0.62 : size,
                        height: icon.style == .padded ? size * 0.62 : size
                    )
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Color.white.opacity(0.4), lineWidth: 0.75))
            .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
        } else {
            monogram
        }
    }

    private var monogram: some View {
        let fullColor = renderingMode == .fullColor
        return ZStack {
            Circle()
                .fill(fullColor ? AnyShapeStyle(link.tint.color.gradient) : AnyShapeStyle(Color.white.opacity(0.14)))
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.55), .white.opacity(0.05)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 0.75
                )
            Text(link.monogram)
                .font(.system(size: size * 0.46, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .widgetAccentable()
        }
        .frame(width: size, height: size)
        .shadow(color: fullColor ? link.tint.color.opacity(0.35) : .clear, radius: 6, y: 2)
    }
}

/// Znaczek serwisu VOD w jednym stylu dla wszystkich: kółko w kolorach marki, szklana
/// krawędź i napis tym samym krojem. Krótkie znaki („N”, „D+”) są większe, słowa
/// („max”, „prime”) mniejsze — tak, żeby optycznie wypełniały kółko podobnie.
struct ServiceMark: View {
    let service: StreamingService
    var size: CGFloat = 34

    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        let fullColor = renderingMode == .fullColor
        let mark = service.mark
        ZStack {
            Circle()
                .fill(
                    fullColor
                        ? AnyShapeStyle(LinearGradient(colors: mark.colors, startPoint: .top, endPoint: .bottom))
                        : AnyShapeStyle(Color.white.opacity(0.14))
                )
            Circle()
                .strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.06)], startPoint: .top, endPoint: .bottom),
                    lineWidth: max(0.5, size * 0.022)
                )
            Text(mark.text)
                .font(.system(size: size * (mark.text.count <= 2 ? 0.46 : 0.31), weight: .black, design: .rounded))
                .tracking(mark.text.count <= 2 ? 0 : -0.2)
                .foregroundStyle(fullColor ? mark.textColor : .white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, size * 0.1)
                .widgetAccentable()
        }
        .frame(width: size, height: size)
        .shadow(color: fullColor ? mark.colors.last!.opacity(0.35) : .clear, radius: size * 0.15, y: size * 0.05)
        .accessibilityLabel(service.displayName)
    }
}
