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
        if let service = link.url.flatMap(StreamingService.detect(in:)),
           let logo = service.logo(maxPixel: size * 3) {
            // Link do rozpoznanego serwisu — jego prawdziwe logo zamiast inicjału.
            Image(decorative: logo, scale: 1)
                .resizable()
                .widgetAccentedRenderingMode(.fullColor)
                .scaledToFill()
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
