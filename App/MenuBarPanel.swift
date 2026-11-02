import AppKit
import SwiftUI

/// Popover z ikony w pasku menu: te same kafelki co w widgecie, ale w prawdziwym Liquid Glass.
struct MenuBarPanel: View {
    @EnvironmentObject private var model: LinksModel
    @Environment(\.openWindow) private var openWindow

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        VStack(spacing: 14) {
            if model.links.isEmpty {
                Text("Brak linków — dodaj pierwszy w edytorze.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                GlassEffectContainer(spacing: 10) {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(model.links) { link in
                            PanelTile(link: link)
                        }
                    }
                }
            }

            HStack {
                Button("Edytuj linki", systemImage: "slider.horizontal.3") {
                    openWindow(id: LinksEditorView.windowID)
                    NSApp.activate()
                }
                Spacer()
                Button("Zakończ", systemImage: "power") {
                    NSApp.terminate(nil)
                }
            }
            .buttonStyle(.glass)
            .controlSize(.small)
        }
        .padding(14)
        .frame(width: 360)
    }
}

private struct PanelTile: View {
    let link: QuickLink

    var body: some View {
        Button {
            if let url = link.url { NSWorkspace.shared.open(url) }
        } label: {
            VStack(spacing: 6) {
                LinkGlyph(link: link, size: 34)
                Text(link.name)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassEffect(
            .regular.tint(link.tint.color.opacity(0.2)).interactive(),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .disabled(link.url == nil)
        .help(link.url?.absoluteString ?? "Niepoprawny adres")
    }
}
