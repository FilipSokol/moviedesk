import Combine
import SwiftUI
import WidgetKit

/// Źródło prawdy dla listy linków po stronie aplikacji.
/// Każda zmiana (z opóźnieniem, żeby nie przeładowywać widgetu przy każdym znaku)
/// trafia do App Group i odświeża widget.
final class LinksModel: ObservableObject {
    @Published var links: [QuickLink]

    private var saveSubscription: AnyCancellable?

    init() {
        links = LinkStore.load()
        saveSubscription = $links
            .dropFirst()
            .debounce(for: .milliseconds(350), scheduler: RunLoop.main)
            .sink { links in
                LinkStore.save(links)
                WidgetCenter.shared.reloadAllTimelines()
            }
    }

    func add() {
        let used = Set(links.map(\.tint))
        let tint = LinkTint.allCases.first { !used.contains($0) } ?? .blue
        links.append(QuickLink(name: "Nowy link", address: "", tint: tint))
    }

    func remove(_ id: QuickLink.ID) {
        links.removeAll { $0.id == id }
    }

    func move(from source: IndexSet, to destination: Int) {
        links.move(fromOffsets: source, toOffset: destination)
    }

    func resetToDefaults() {
        links = QuickLink.defaults
    }
}
