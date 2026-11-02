import AppKit
import WebKit

/// Zalogowana sesja Filmwebu trzymana w WebKicie aplikacji — bez wklejania ciasteczek.
///
/// Filmweb trzyma logowanie w długowiecznym ciasteczku (`_artuser_prm`), a do API używa
/// krótkiego tokenu `JWT` ważnego ok. 15 minut, odświeżanego przez samą stronę. Dlatego
/// zapytania wymagające logowania wykonujemy *wewnątrz* załadowanej strony filmweb.pl
/// (`fetch` z jej ciasteczkami), a przed synchronizacją przeładowujemy stronę, żeby
/// dostać świeży token. Ciasteczka leżą w magazynie WebKitu w kontenerze aplikacji.
@MainActor
final class FilmwebSession: NSObject, WKNavigationDelegate {
    static let shared = FilmwebSession()

    static let homeURL = URL(string: "https://www.filmweb.pl/")!
    static let loginURL = URL(string: "https://www.filmweb.pl/login")!

    enum SessionError: LocalizedError {
        case notLoggedIn
        case http(Int)
        case loadFailed(String)

        var errorDescription: String? {
            switch self {
            case .notLoggedIn: "Filmweb: sesja wygasła — zaloguj się ponownie w ustawieniach MovieDesk."
            case .http(let code): "Filmweb: błąd \(code)."
            case .loadFailed(let reason): "Filmweb: nie udało się otworzyć strony (\(reason))."
            }
        }
    }

    private let webView: WKWebView
    private var loadContinuation: CheckedContinuation<Void, Error>?
    private var loadTask: Task<Void, Error>?
    private var lastLoad: Date?

    /// Konfiguracja współdzielona z oknem logowania (ten sam magazyn ciasteczek).
    static func makeConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        return configuration
    }

    override private init() {
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1024, height: 768), configuration: Self.makeConfiguration())
        super.init()
        webView.navigationDelegate = self
    }

    /// Ładuje stronę główną (świeży token). Przy `force == false` tylko, gdy minęło > 10 minut.
    /// Równoległe wywołania czekają na to samo ładowanie.
    func refresh(force: Bool = true) async throws {
        if !force, let lastLoad, Date().timeIntervalSince(lastLoad) < 600 { return }
        if let loadTask { return try await loadTask.value }
        let task = Task { try await self.loadHome() }
        loadTask = task
        defer { loadTask = nil }
        try await task.value
        lastLoad = .now
    }

    private func loadHome() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            loadContinuation = continuation
            webView.load(URLRequest(url: Self.homeURL, timeoutInterval: 30))
        }
    }

    /// GET do `https://www.filmweb.pl/api/v1/<path>` z ciasteczkami zalogowanej sesji.
    /// Przy 401/403 raz przeładowuje stronę (nowy token) i ponawia.
    func getJSON(_ path: String) async throws -> Any {
        try await refresh(force: false)
        do {
            return try await fetch(path)
        } catch SessionError.notLoggedIn {
            try await refresh(force: true)
            return try await fetch(path)
        }
    }

    /// Nazwa zalogowanego użytkownika albo `nil`, gdy nie jesteś zalogowany.
    func loggedUserName() async -> String? {
        guard let json = try? await getJSON("logged/info") as? [String: Any] else { return nil }
        for key in ["name", "userName", "login", "nick"] {
            if let value = json[key] as? String, !value.isEmpty { return value }
        }
        return "zalogowano"
    }

    /// Usuwa dane Filmwebu z magazynu WebKitu (wylogowanie).
    func logOut() async {
        let store = WKWebsiteDataStore.default()
        let records = await store.dataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes())
        let filmweb = records.filter { $0.displayName.contains("filmweb") }
        await store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: filmweb)
        lastLoad = nil
    }

    private func fetch(_ path: String) async throws -> Any {
        let script = """
        const response = await fetch(url, {
            credentials: 'include',
            headers: { 'Accept': 'application/json', 'X-Locale': 'pl' }
        });
        if (!response.ok) { return { status: response.status }; }
        return { status: response.status, body: await response.text() };
        """
        let result = try await webView.callAsyncJavaScript(
            script,
            arguments: ["url": "/api/v1/" + path],
            contentWorld: .page
        )
        guard let dictionary = result as? [String: Any],
              let status = (dictionary["status"] as? NSNumber)?.intValue
        else { throw SessionError.http(0) }

        switch status {
        case 200..<300:
            let body = dictionary["body"] as? String ?? ""
            return try JSONSerialization.jsonObject(with: Data(body.utf8), options: [.fragmentsAllowed])
        case 401, 403:
            throw SessionError.notLoggedIn
        default:
            throw SessionError.http(status)
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finishLoad(with: nil)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finishLoad(with: error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finishLoad(with: error)
    }

    private func finishLoad(with error: Error?) {
        guard let continuation = loadContinuation else { return }
        loadContinuation = nil
        if let error {
            continuation.resume(throwing: SessionError.loadFailed(error.localizedDescription))
        } else {
            continuation.resume()
        }
    }
}
