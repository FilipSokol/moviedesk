import SwiftUI

/// Edytor listy linków. Kolejność = kolejność kafelków w widgecie.
struct LinksEditorView: View {
    static let windowID = "links-editor"

    @EnvironmentObject private var model: LinksModel

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach($model.links) { $link in
                    LinkRow(link: $link) { model.remove(link.id) }
                }
                .onMove { model.move(from: $0, to: $1) }
            }
            .listStyle(.inset)

            Divider()

            HStack(alignment: .firstTextBaseline) {
                Text("Mały widget pokazuje 4 pierwsze linki, średni 8, duży 16. Przeciągnij wiersz, aby zmienić kolejność.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 16)
                Button("Przywróć domyślne") { model.resetToDefaults() }
                    .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .toolbar {
            ToolbarItem {
                Button("Dodaj link", systemImage: "plus") { model.add() }
            }
        }
        .frame(minWidth: 560, minHeight: 380)
    }
}

private struct LinkRow: View {
    @Binding var link: QuickLink
    let onDelete: () -> Void

    private var addressIsInvalid: Bool {
        !link.address.trimmingCharacters(in: .whitespaces).isEmpty && link.url == nil
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)

            LinkGlyph(link: link, size: 28)

            TextField("Nazwa", text: $link.name)
                .textFieldStyle(.plain)
                .font(.body.weight(.medium))
                .frame(width: 140)

            TextField("adres, np. filmweb.pl", text: $link.address)
                .textFieldStyle(.plain)
                .foregroundStyle(addressIsInvalid ? Color.red : Color.secondary)
                .help(addressIsInvalid ? "Obsługiwane są tylko adresy http(s)" : "")

            TintPicker(selection: $link.tint)

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Usuń")
        }
        .padding(.vertical, 4)
    }
}

private struct TintPicker: View {
    @Binding var selection: LinkTint
    @State private var isPresented = false

    private let columns = Array(repeating: GridItem(.fixed(22), spacing: 8), count: 6)

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Circle()
                .fill(selection.color.gradient)
                .frame(width: 16, height: 16)
                .overlay { Circle().strokeBorder(.white.opacity(0.4), lineWidth: 0.5) }
        }
        .buttonStyle(.plain)
        .help("Kolor")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(LinkTint.allCases) { tint in
                    Button {
                        selection = tint
                        isPresented = false
                    } label: {
                        Circle()
                            .fill(tint.color.gradient)
                            .frame(width: 22, height: 22)
                            .overlay {
                                if tint == selection {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
        }
    }
}
