import AppKit
import Combine
import SwiftUI
import WidgetKit

/// Źródło prawdy dla listy linków po stronie aplikacji.
/// Każda zmiana (z opóźnieniem, żeby nie przeładowywać widgetu przy każdym znaku)
/// trafia do App Group i odświeża widget.
@MainActor
final class LinksModel: ObservableObject {
    @Published var links: [QuickLink]

    private var saveSubscription: AnyCancellable?
    private var terminateObserver: NSObjectProtocol?

    init() {
        links = LinkStore.load()
        saveSubscription = $links
            .dropFirst()
            .debounce(for: .milliseconds(350), scheduler: RunLoop.main)
            .sink { [weak self] links in
                LinkStore.save(links)
                WidgetCenter.shared.reloadAllTimelines()
                // Nowy link — od razu dociągamy jego ikonę (favikonę strony).
                Task { @MainActor in
                    if await IconFetcher.refreshFavicons(for: links) {
                        self?.objectWillChange.send()
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }
            }
        // Ostatnie zmiany mogły jeszcze czekać na debounce.
        terminateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.flush() }
        }
    }

    /// Kolor, którego jeszcze nie używasz (żeby nowe kółka się odróżniały).
    var nextFreeTint: LinkTint {
        let used = Set(links.map(\.tint))
        return LinkTint.allCases.first { !used.contains($0) } ?? .blue
    }

    @discardableResult
    func add(name: String, address: String, tint: LinkTint) -> QuickLink.ID {
        let link = QuickLink(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            address: address.trimmingCharacters(in: .whitespacesAndNewlines),
            tint: tint
        )
        links.append(link)
        return link.id
    }

    func binding(for id: QuickLink.ID) -> Binding<QuickLink>? {
        guard links.contains(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { [weak self] in
                self?.links.first { $0.id == id } ?? QuickLink(name: "", address: "", tint: .blue)
            },
            set: { [weak self] newValue in
                guard let self, let index = links.firstIndex(where: { $0.id == id }) else { return }
                links[index] = newValue
            }
        )
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

    /// Zapis od razu, bez czekania na debounce (np. przy zamykaniu aplikacji).
    func flush() {
        LinkStore.save(links)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
