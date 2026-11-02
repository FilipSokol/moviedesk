import AppKit
import SwiftUI

@main
struct MovieDeskApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = LinksModel()

    var body: some Scene {
        MenuBarExtra("MovieDesk", systemImage: "play.rectangle.on.rectangle") {
            MenuBarPanel()
                .environmentObject(model)
        }
        .menuBarExtraStyle(.window)

        Window("Linki", id: LinksEditorView.windowID) {
            LinksEditorView()
                .environmentObject(model)
        }
        .defaultSize(width: 640, height: 480)
        // Uruchomienie przez kliknięcie w widget nie powinno otwierać okna.
        .defaultLaunchBehavior(.suppressed)
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
