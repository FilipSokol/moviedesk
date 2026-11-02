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
        let fullColor = renderingMode == .fullColor
        ZStack {
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
