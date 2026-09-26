import Foundation
import WebKit

enum ClaudeError: LocalizedError {
    case notLoggedIn
    case blocked
    case http(Int)
    case badResponse
    case noUsage

    var errorDescription: String? {
        switch self {
        case .notLoggedIn: return "No has iniciado sesión."
        case .blocked: return "claude.ai bloqueó la petición (verificación de Cloudflare). Reintenta en un momento."
        case .http(let code): return "claude.ai respondió con error \(code)."
        case .badResponse: return "Respuesta inesperada de claude.ai."
        case .noUsage: return "No se encontraron datos de uso para esta cuenta."
        }
    }
}

/// Hace peticiones a claude.ai desde un WKWebView oculto que comparte las cookies
/// de la ventana de login, así las peticiones salen igual que desde el navegador.
@MainActor
final class ClaudeClient: NSObject, WKNavigationDelegate {
    static let baseURL = URL(string: "https://claude.ai")!
    /// Segundos máximos por petición.
    static let timeout: TimeInterval = 30
    /// WKWebView no incluye "Safari" en su user agent por defecto y algunos proveedores de
    /// login lo rechazan; este es el de Safari, que usa el mismo motor WebKit.
    static let userAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"

    private let webView: WKWebView
    private var loadContinuation: CheckedContinuation<Void, Error>?
    private var originReady = false

    override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600), configuration: config)
        webView.customUserAgent = Self.userAgent
        super.init()
        webView.navigationDelegate = self
    }

    // MARK: Sesión

    static func hasSessionCookie() async -> Bool {
        let cookies: [HTTPCookie] = await withCheckedContinuation { cont in
            WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cont.resume(returning: $0) }
        }
        return cookies.contains { $0.name == "sessionKey" && $0.domain.hasSuffix("claude.ai") }
    }

    func logout() async {
        await WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: .distantPast
        )
        originReady = false
    }

    // MARK: Peticiones

    func getJSON(_ path: String) async throws -> Any {
        try await ensureOrigin()

        // Con tiempo límite: si fetch se queda colgado, la app nunca volvería a actualizar.
        let js = """
        const r = await fetch(path, {
            credentials: 'include',
            headers: { 'accept': 'application/json' },
            signal: AbortSignal.timeout(timeoutMs)
        });
        return { status: r.status, body: await r.text() };
        """
        let raw = try await webView.callAsyncJavaScript(
            js, arguments: ["path": path, "timeoutMs": Self.timeout * 1000], in: nil, contentWorld: .defaultClient
        )
        guard let result = raw as? [String: Any],
              let status = (result["status"] as? NSNumber)?.intValue,
              let body = result["body"] as? String
        else { throw ClaudeError.badResponse }

        let json = body.data(using: .utf8).flatMap { try? JSONSerialization.jsonObject(with: $0) }
        // La página de verificación de Cloudflare es HTML; una respuesta JSON nunca lo es.
        if json == nil, body.contains("Just a moment") || body.contains("cf-challenge") {
            originReady = false
            throw ClaudeError.blocked
        }
        switch status {
        case 200..<300: break
        case 401, 403: throw ClaudeError.notLoggedIn
        default: throw ClaudeError.http(status)
        }
        guard let json else { throw ClaudeError.badResponse }
        return json
    }

    /// `fetch` necesita un documento cargado en el origen claude.ai.
    private func ensureOrigin() async throws {
        if originReady, webView.url?.host == Self.baseURL.host { return }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            loadContinuation?.resume(throwing: CancellationError())
            loadContinuation = cont
            webView.load(URLRequest(
                url: Self.baseURL.appendingPathComponent("api/organizations"),
                timeoutInterval: Self.timeout
            ))
        }
        originReady = true
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadContinuation?.resume()
        loadContinuation = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loadContinuation?.resume(throwing: error)
        loadContinuation = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        loadContinuation?.resume(throwing: error)
        loadContinuation = nil
    }
}
