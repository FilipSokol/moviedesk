import AppKit
import SwiftUI
import WebKit

/// Okno logowania do Filmwebu. Logujesz się raz, na stronie Filmwebu; aplikacja niczego
/// nie podgląda ani nie zapisuje poza standardowymi ciasteczkami WebKitu.
///
/// Logowanie przez Google otwiera osobne okienko, które po zalogowaniu odsyła wynik do
/// strony Filmwebu przez `window.opener`. Dlatego okienko musi być prawdziwym, osobnym
/// widokiem WebKit utworzonym z konfiguracji podanej przez stronę — załadowanie go w tym
/// samym widoku zrywa to połączenie i kończy się białym ekranem.
struct FilmwebLoginView: View {
    static let windowID = "filmweb-login"

    @EnvironmentObject private var sync: SyncController
    @Environment(\.dismissWindow) private var dismissWindow
    @StateObject private var browser = LoginBrowser()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button { browser.webView.goBack() } label: { Image(systemName: "chevron.left") }
                    .disabled(!browser.canGoBack)
                    .help("Wstecz")
                Button { browser.restart() } label: { Image(systemName: "arrow.counterclockwise") }
                    .help("Zacznij logowanie od nowa")
                Text(browser.host)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                if browser.isLoading { ProgressView().controlSize(.small) }
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()
            BrowserView(webView: browser.webView)
            Divider()

            HStack {
                Text("Zaloguj się na Filmwebie (także przez Google), a potem kliknij „Gotowe”.")
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
        // Zamknięcie okna czerwonym przyciskiem też sprawdza logowanie.
        .onDisappear {
            browser.closePopups()
            Task { await sync.checkFilmweb() }
        }
    }
}

/// Przeglądarka logowania z obsługą okienek (Google, Facebook, Apple).
@MainActor
final class LoginBrowser: NSObject, ObservableObject, WKUIDelegate, WKNavigationDelegate {
    let webView: WKWebView
    @Published private(set) var canGoBack = false
    @Published private(set) var isLoading = false
    @Published private(set) var host = ""

    private var popups: [NSWindow] = []
    private var observations: [NSKeyValueObservation] = []

    /// Google odrzuca logowanie w „nieznanych” przeglądarkach wbudowanych w aplikacje —
    /// przedstawiamy się jak Safari (którym ten widok w praktyce jest).
    static let userAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15"

    override init() {
        let configuration = FilmwebSession.makeConfiguration()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.customUserAgent = Self.userAgent
        webView.uiDelegate = self
        webView.navigationDelegate = self
        observations = [
            webView.observe(\.canGoBack) { [weak self] view, _ in
                MainActor.assumeIsolated { self?.canGoBack = view.canGoBack }
            },
            webView.observe(\.isLoading) { [weak self] view, _ in
                MainActor.assumeIsolated { self?.isLoading = view.isLoading }
            },
            webView.observe(\.url) { [weak self] view, _ in
                MainActor.assumeIsolated { self?.host = view.url?.host ?? "" }
            },
        ]
        webView.load(URLRequest(url: FilmwebSession.loginURL))
    }

    func restart() {
        closePopups()
        webView.load(URLRequest(url: FilmwebSession.loginURL))
    }

    func closePopups() {
        popups.forEach { $0.close() }
        popups.removeAll()
    }

    // MARK: - WKUIDelegate

    /// Okienko logowania: osobny widok z konfiguracją od strony (zachowuje `window.opener`).
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        let popup = WKWebView(frame: .zero, configuration: configuration)
        popup.customUserAgent = Self.userAgent
        popup.uiDelegate = self

        let width = windowFeatures.width?.doubleValue ?? 500
        let height = windowFeatures.height?.doubleValue ?? 640
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: max(width, 420), height: max(height, 560)),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Logowanie"
        window.contentView = popup
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        popups.append(window)
        return popup
    }

    /// Strona sama zamyka okienko po zalogowaniu (`window.close()`).
    func webViewDidClose(_ webView: WKWebView) {
        popups.removeAll { window in
            guard window.contentView === webView else { return false }
            window.close()
            return true
        }
        // Po zamknięciu okienka Filmweb zwykle przeładowuje stronę jako zalogowaną.
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo
    ) async {
        let alert = NSAlert()
        alert.messageText = message
        alert.runModal()
    }
}

private struct BrowserView: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView { webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
