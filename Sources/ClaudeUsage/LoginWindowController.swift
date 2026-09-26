import AppKit
import WebKit

/// Ventana con claude.ai para que inicies sesión tú mismo. Se cierra sola al detectar la sesión.
@MainActor
final class LoginWindowController: NSObject, NSWindowDelegate, WKUIDelegate {
    private var window: NSWindow?
    /// Ventanas emergentes (login con Google / Apple), abiertas por la página con window.open.
    private var popups: [NSWindow] = []
    private var checkTimer: Timer?
    private let onFinish: () -> Void

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = ClaudeClient.userAgent
        webView.uiDelegate = self
        webView.load(URLRequest(url: ClaudeClient.baseURL.appendingPathComponent("login")))

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 720),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Iniciar sesión en Claude"
        window.contentView = webView
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        self.window = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        checkTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                if await ClaudeClient.hasSessionCookie() { self?.window?.close() }
            }
        }
    }

    // MARK: Ventanas emergentes

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        // Hay que usar la configuración recibida para que window.opener siga conectado.
        let popupView = WKWebView(frame: .zero, configuration: configuration)
        popupView.customUserAgent = ClaudeClient.userAgent
        popupView.uiDelegate = self

        let popup = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 640),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        popup.title = "Iniciar sesión"
        popup.contentView = popupView
        popup.isReleasedWhenClosed = false
        popup.delegate = self
        popup.center()
        popup.makeKeyAndOrderFront(nil)
        popups.append(popup)
        return popupView
    }

    func webViewDidClose(_ webView: WKWebView) {
        if let popup = popups.first(where: { $0.contentView === webView }) {
            popup.close()
            popups.removeAll { $0 === popup }
        }
    }

    func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow, closing === window else {
            popups.removeAll { $0 === notification.object as? NSWindow }
            return
        }
        popups.forEach { $0.close() }
        popups.removeAll()
        checkTimer?.invalidate()
        checkTimer = nil
        window = nil
        onFinish()
    }
}
