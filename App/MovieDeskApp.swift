import AppKit
import SwiftUI

@main
struct MovieDeskApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var links = LinksModel()
    @StateObject private var sync = SyncController()

    var body: some Scene {
        MenuBarExtra("MovieDesk", systemImage: "play.rectangle.on.rectangle") {
            MenuBarPanel()
                .environmentObject(links)
                .environmentObject(sync)
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

/// Odbiera `moviedesk://open?url=…` z widgetu i otwiera adres w domyślnej przeglądarce.
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
              let target = DeepLink.target(from: url)
        else { return }
        NSWorkspace.shared.open(target)
    }
}
