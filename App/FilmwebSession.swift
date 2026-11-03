import AppKit
import WebKit

/// Zalogowana sesja Filmwebu trzymana w WebKicie aplikacji — bez wklejania ciasteczek.
///
/// Filmweb trzyma logowanie w długowiecznym ciasteczku (`_artuser_prm`), a do API używa
/// krótkiego tokenu `JWT` ważnego ok. 15 minut, który odświeża sama strona. Dlatego:
/// - przed zapytaniem sprawdzamy ważność tokenu (pole `exp` w ciasteczku `JWT`),
///   a gdy zostało mniej niż 2 minuty — przeładowujemy stronę główną,
/// - zapytania wymagające logowania wykonujemy jako `fetch` w kontekście strony filmweb.pl,
///   w odizolowanym „świecie” JavaScriptu (skrypty strony nie widzą odpowiedzi).
/// Ciasteczka leżą w magazynie WebKitu w kontenerze aplikacji.
@MainActor
final class FilmwebSession: NSObject, WKNavigationDelegate {
    static let shared = FilmwebSession()

    static let homeURL = URL(string: "https://www.filmweb.pl/")!
    static let loginURL = URL(string: "https://www.filmweb.pl/login")!
    private static let apiBase = "https://www.filmweb.pl/api/v1/"

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

    enum LoginState: Equatable {
        case loggedIn(String)
        case loggedOut
        /// Nie da się sprawdzić (brak sieci, Filmweb nie odpowiada) — to nie znaczy „wylogowany”.
        case unknown(String)
    }

    private let webView: WKWebView
    private var loadContinuation: CheckedContinuation<Void, Error>?
    private var currentNavigation: WKNavigation?
    private var currentLoadID: UUID?
    private var loadTask: Task<Void, Error>?

    /// Konfiguracja współdzielona z oknem logowania (ten sam magazyn ciasteczek).
    static func makeConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        // Żadnych reklam wideo z dźwiękiem o północy.
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        return configuration
    }

    override private init() {
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1024, height: 768), configuration: Self.makeConfiguration())
        super.init()
        webView.customUserAgent = LoginBrowser.userAgent
        webView.navigationDelegate = self
    }

    // MARK: - API

    /// GET `https://www.filmweb.pl/api/v1/<path>` z ciasteczkami zalogowanej sesji.
    /// Przy 401/403 raz przeładowuje stronę (nowy token) i ponawia.
    func getData(_ path: String) async throws -> Data {
        try await refresh(force: false)
        do {
            return try await fetch(path)
        } catch SessionError.notLoggedIn {
            try await refresh(force: true)
            return try await fetch(path)
        }
    }

    func checkLogin() async -> LoginState {
        do {
            let data = try await getData("logged/info")
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            for key in ["name", "userName", "login", "nick"] {
                if let value = json?[key] as? String, !value.isEmpty { return .loggedIn(value) }
            }
            return .loggedIn("zalogowano")
        } catch SessionError.notLoggedIn {
            return .loggedOut
        } catch {
            return .unknown(error.localizedDescription)
        }
    }

    /// Usuwa dane Filmwebu z magazynu WebKitu (wylogowanie).
    func logOut() async {
        let store = WKWebsiteDataStore.default()
        let records = await store.dataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes())
        let filmweb = records.filter { $0.displayName.contains("filmweb") }
        await store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: filmweb)
        suspend()
    }

    /// Zwalnia stronę po synchronizacji, żeby nie trzymać w pamięci reklam i skryptów Filmwebu.
    func suspend() {
        currentNavigation = nil
        webView.load(URLRequest(url: URL(string: "about:blank")!))
    }

    // MARK: - Token i ładowanie strony

    /// Przeładowuje stronę główną, gdy trzeba (albo zawsze przy `force`).
    /// Równoległe wywołania czekają na to samo ładowanie.
    func refresh(force: Bool = true) async throws {
        if !force, isOnFilmweb, await hasFreshToken() { return }
        if let loadTask { return try await loadTask.value }
        let task = Task { try await self.loadHome() }
        loadTask = task
        defer { loadTask = nil }
        try await task.value
    }

    private var isOnFilmweb: Bool {
        webView.url?.host?.hasSuffix("filmweb.pl") == true
    }

    private func loadHome() async throws {
        let loadID = UUID()
        currentLoadID = loadID
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            loadContinuation?.resume(throwing: CancellationError())
            loadContinuation = continuation
            currentNavigation = webView.load(URLRequest(url: Self.homeURL, timeoutInterval: 30))
            // Twardy limit — gdyby WebKit nigdy nie zgłosił końca ładowania.
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(45))
                guard let self, self.currentLoadID == loadID else { return }
                self.finishLoad(with: SessionError.loadFailed("przekroczono czas"))
            }
        }
        // Strona może ustawić nowy token chwilę po załadowaniu.
        for _ in 0..<10 {
            if await hasFreshToken() { return }
            try? await Task.sleep(for: .milliseconds(500))
        }
    }

    private func hasFreshToken(margin: TimeInterval = 120) async -> Bool {
        guard let expiry = await tokenExpiry() else { return false }
        return expiry.timeIntervalSinceNow > margin
    }

    /// Czas wygaśnięcia z ciasteczka `JWT` (pole `exp` w środkowej części tokenu).
    private func tokenExpiry() async -> Date? {
        let cookies = await webView.configuration.websiteDataStore.httpCookieStore.allCookies()
        guard let token = cookies.first(where: { $0.name == "JWT" && $0.domain.contains("filmweb") })?.value
        else { return nil }
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }
        guard let data = Data(base64Encoded: base64),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let exp = (json["exp"] as? NSNumber)?.doubleValue
        else { return nil }
        return Date(timeIntervalSince1970: exp)
    }

    private func fetch(_ path: String) async throws -> Data {
        guard isOnFilmweb else { throw SessionError.loadFailed("strona Filmwebu nie jest załadowana") }
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
            arguments: ["url": Self.apiBase + path],
            contentWorld: .defaultClient
        )
        guard let dictionary = result as? [String: Any],
              let status = (dictionary["status"] as? NSNumber)?.intValue
        else { throw SessionError.http(0) }

        switch status {
        case 200..<300:
            return Data((dictionary["body"] as? String ?? "").utf8)
        case 401, 403:
            throw SessionError.notLoggedIn
        default:
            throw SessionError.http(status)
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard navigation === currentNavigation else { return }
        finishLoad(with: nil)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard navigation === currentNavigation, !Self.isCancellation(error) else { return }
        finishLoad(with: SessionError.loadFailed(error.localizedDescription))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard navigation === currentNavigation, !Self.isCancellation(error) else { return }
        finishLoad(with: SessionError.loadFailed(error.localizedDescription))
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        finishLoad(with: SessionError.loadFailed("proces strony został zamknięty"))
    }

    private static func isCancellation(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }

    private func finishLoad(with error: Error?) {
        guard let continuation = loadContinuation else { return }
        loadContinuation = nil
        currentLoadID = nil
        if let error {
            continuation.resume(throwing: error)
        } else {
            continuation.resume()
        }
    }
}
