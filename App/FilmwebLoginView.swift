import SwiftUI
import WebKit

/// Okno logowania do Filmwebu. Logujesz się raz, na stronie Filmwebu; aplikacja niczego
/// nie podgląda ani nie zapisuje poza standardowymi ciasteczkami WebKitu.
struct FilmwebLoginView: View {
    static let windowID = "filmweb-login"

    @EnvironmentObject private var sync: SyncController
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        VStack(spacing: 0) {
            LoginWebView()
            Divider()
            HStack {
                Text("Zaloguj się na Filmwebie, a potem kliknij „Gotowe”.")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Gotowe") {
                    Task {
                        await sync.checkFilmweb()
                        dismissWindow(id: Self.windowID)
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .frame(minWidth: 520, minHeight: 640)
    }
}

private struct LoginWebView: NSViewRepresentable {
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: FilmwebSession.makeConfiguration())
        webView.load(URLRequest(url: FilmwebSession.loginURL))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
