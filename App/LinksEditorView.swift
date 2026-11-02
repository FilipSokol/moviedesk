import SwiftUI

/// Edytor linków: lista po lewej (kolejność = kolejność w widgecie), szczegóły po prawej.
/// Nowy link dodajesz w arkuszu: wklejasz adres, nazwa podpowiada się sama.
struct LinksEditorView: View {
    @EnvironmentObject private var model: LinksModel
    @State private var selection: QuickLink.ID?
    @State private var isAdding = false

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                List(selection: $selection) {
                    ForEach(model.links) { link in
                        LinkListRow(link: link)
                            .tag(link.id)
                            .contextMenu {
                                Button("Usuń", role: .destructive) { delete(link.id) }
                            }
                    }
                    .onMove { model.move(from: $0, to: $1) }
                }
                .listStyle(.sidebar)
                .onDeleteCommand { if let selection { delete(selection) } }

                Divider()
                HStack(spacing: 4) {
                    Button { isAdding = true } label: { Image(systemName: "plus") }
                        .help("Dodaj link (⌘N)")
                        .keyboardShortcut("n", modifiers: .command)
                    Button { if let selection { delete(selection) } } label: { Image(systemName: "minus") }
                        .disabled(selection == nil)
                        .help("Usuń zaznaczony link")
                    Spacer()
                    Menu {
                        Button("Przywróć domyślne linki") { model.resetToDefaults(); selection = nil }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
                .buttonStyle(.borderless)
                .padding(8)
            }
            .frame(width: 230)

            Divider()

            Group {
                if let selection, let binding = model.binding(for: selection) {
                    LinkDetailForm(link: binding)
                        .id(selection)
                } else {
                    ContentUnavailableView {
                        Label("Wybierz link", systemImage: "link")
                    } description: {
                        Text("Średni widget pokazuje 4 pierwsze linki, duży 8, panel w pasku menu wszystkie. Kolejność zmieniasz przeciąganiem.")
                    } actions: {
                        Button("Dodaj link") { isAdding = true }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $isAdding) {
            NewLinkSheet(defaultTint: model.nextFreeTint) { name, address, tint in
                selection = model.add(name: name, address: address, tint: tint)
            }
        }
        .onAppear {
            if selection == nil { selection = model.links.first?.id }
        }
    }

    private func delete(_ id: QuickLink.ID) {
        let index = model.links.firstIndex { $0.id == id }
        model.remove(id)
        if selection == id {
            selection = index.flatMap { model.links.indices.contains($0) ? model.links[$0].id : model.links.last?.id }
        }
    }
}

private struct LinkListRow: View {
    let link: QuickLink

    var body: some View {
        HStack(spacing: 10) {
            LinkGlyph(link: link, size: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(link.name.isEmpty ? "Bez nazwy" : link.name)
                    .lineLimit(1)
                Text(link.url?.host ?? "niepoprawny adres")
                    .font(.caption)
                    .foregroundStyle(link.url == nil ? Color.red : Color.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if link.url.flatMap(StreamingService.detect(in:)) != nil {
                Text("VOD")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

/// Edycja zaznaczonego linku — zwykłe pola tekstowe, zmiany zapisują się same.
private struct LinkDetailForm: View {
    @Binding var link: QuickLink
    @FocusState private var focusedField: Field?

    private enum Field { case name, address }

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    LinkGlyph(link: link, size: 56)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
            Section {
                TextField("Nazwa", text: $link.name)
                    .focused($focusedField, equals: .name)
                TextField("Adres", text: $link.address, prompt: Text("np. example.com"))
                    .focused($focusedField, equals: .address)
                AddressStatus(address: link.address)
            }
            Section("Kolor") {
                TintGrid(selection: $link.tint)
            }
        }
        .formStyle(.grouped)
    }
}

/// Arkusz „Nowy link”: najpierw adres (pole aktywne od razu), nazwa podpowiada się z adresu.
private struct NewLinkSheet: View {
    let defaultTint: LinkTint
    let onAdd: (String, String, LinkTint) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var name = ""
    @State private var nameEdited = false
    @State private var tint: LinkTint = .blue
    @FocusState private var addressFocused: Bool

    private var isValid: Bool { QuickLink.webURL(from: address) != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Nowy link")
                .font(.title3.weight(.semibold))

            HStack(alignment: .top, spacing: 16) {
                LinkGlyph(link: QuickLink(name: name.isEmpty ? "?" : name, address: address, tint: tint), size: 48)
                Form {
                    TextField("Adres", text: $address, prompt: Text("np. example.com"))
                        .focused($addressFocused)
                        .onChange(of: address) { _, newValue in
                            if !nameEdited { name = QuickLink.suggestedName(for: newValue) }
                        }
                    TextField("Nazwa", text: Binding(
                        get: { name },
                        set: { name = $0; nameEdited = true }
                    ))
                    AddressStatus(address: address)
                }
                .formStyle(.columns)
            }

            TintGrid(selection: $tint)

            HStack {
                Spacer()
                Button("Anuluj", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Dodaj") {
                    let finalName = name.trimmingCharacters(in: .whitespaces)
                    onAdd(finalName.isEmpty ? QuickLink.suggestedName(for: address) : finalName, address, tint)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear {
            tint = defaultTint
            addressFocused = true
        }
    }
}

/// Podpowiedź pod adresem: czy jest poprawny i czy to rozpoznany serwis VOD.
private struct AddressStatus: View {
    let address: String

    var body: some View {
        let trimmed = address.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            EmptyView()
        } else if let url = QuickLink.webURL(from: trimmed) {
            if let service = StreamingService.detect(in: url) {
                Label("\(service.displayName) — propozycje filmów uwzględnią ten serwis", systemImage: "play.tv")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Label("Zwykły skrót — otworzy \(url.host ?? trimmed)", systemImage: "link")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            Label("To nie wygląda na adres strony", systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }
}

private struct TintGrid: View {
    @Binding var selection: LinkTint

    var body: some View {
        HStack(spacing: 8) {
            ForEach(LinkTint.allCases) { tint in
                Button {
                    selection = tint
                } label: {
                    Circle()
                        .fill(tint.color.gradient)
                        .frame(width: 20, height: 20)
                        .overlay {
                            if tint == selection {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .help(tint.rawValue)
            }
        }
    }
}
