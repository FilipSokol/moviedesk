import AppKit
import SwiftUI

@main
struct MovieDeskApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var links = LinksModel()
    @StateObject private var sync = SyncController()

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanel()
                .environmentObject(links)
                .environmentObject(sync)
        } label: {
            MenuBarLabel()
        }
        .menuBarExtraStyle(.window)

        Window("MovieDesk", id: MainWindow.id) {
            MainWindow()
                .environmentObject(links)
                .environmentObject(sync)
        }
        .defaultSize(width: 640, height: 560)
        // Uruchomienie przez kliknięcie w widget nie powinno otwierać okna.
        .defaultLaunchBehavior(.suppressed)

        Window("Logowanie do Filmwebu", id: FilmwebLoginView.windowID) {
            FilmwebLoginView()
                .environmentObject(sync)
        }
        .defaultSize(width: 520, height: 720)
        .defaultLaunchBehavior(.suppressed)
    }
}

/// Okno ustawień: rekomendacje i linki.
struct MainWindow: View {
    static let id = "main"

    var body: some View {
        TabView {
            SettingsView()
                .tabItem { Label("Rekomendacje", systemImage: "film") }
            LinksEditorView()
                .tabItem { Label("Linki", systemImage: "link") }
        }
        .frame(minWidth: 560, minHeight: 460)
    }
}

/// Ikona w pasku menu. Żyje przez cały czas działania aplikacji, więc to ona otwiera
/// ustawienia na prośbę widgetu (`moviedesk://settings`).
private struct MenuBarLabel: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(systemName: "play.rectangle.on.rectangle")
            .accessibilityLabel("MovieDesk")
            .onReceive(NotificationCenter.default.publisher(for: .movieDeskSettingsRequested)) { _ in
                NSApp.activate()
                openWindow(id: MainWindow.id)
            }
    }
}

/// Odbiera adresy `moviedesk://…` z widgetów:
/// - `open?url=…` — otwiera stronę w domyślnej przeglądarce,
/// - `sync` — synchronizacja teraz, `settings` — ustawienia.
///
/// Handler Apple Event rejestrujemy przed zakończeniem startu, żeby złapać także URL,
/// który uruchomił aplikację — i żeby SwiftUI nie otwierało przy tym nowego okna.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURL(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc private func handleGetURL(_ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor) {
        guard let raw = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: raw),
              let route = DeepLink.route(from: url)
        else { return }
        switch route {
        case .open(let target):
            NSWorkspace.shared.open(target)
        case .sync:
            NotificationCenter.default.post(name: .movieDeskSyncRequested, object: nil)
        case .settings:
            NotificationCenter.default.post(name: .movieDeskSettingsRequested, object: nil)
        }
    }
}
