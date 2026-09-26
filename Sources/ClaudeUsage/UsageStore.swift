import AppKit
import ServiceManagement

struct UsageLimit: Identifiable {
    let id: String
    let title: String
    let percent: Double
    let resetsAt: Date?
}

@MainActor
final class UsageStore: ObservableObject {
    enum Status: Equatable {
        case idle, loading, loggedOut, ok
        case error(String)
    }

    @Published private(set) var limits: [UsageLimit] = []
    @Published private(set) var status: Status = .idle
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var orgName: String?
    @Published var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled {
        didSet { setLaunchAtLogin(launchAtLogin) }
    }

    private let client = ClaudeClient()
    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var isRefreshing = false
    /// Intervalo actual del refresco adaptativo.
    private var interval = UsageStore.minInterval
    private lazy var loginWindow = LoginWindowController { [weak self] in
        Task { await self?.refresh() }
    }

    /// Mientras el uso cambia se consulta cada minuto; si no cambia, el intervalo
    /// se duplica hasta llegar a 5 minutos.
    private static let minInterval: TimeInterval = 60
    private static let maxInterval: TimeInterval = 5 * 60
    private static let orgKey = "selectedOrganizationUUID"

    init() {
        // Al despertar el Mac, actualizar en cuanto vuelva la red.
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                self?.interval = UsageStore.minInterval
                await self?.refresh()
            }
        }
        enableLaunchAtLoginOnFirstRun()
        Task { await refresh() }
    }

    var menuBarText: String {
        if let session = limits.first(where: { $0.id == "five_hour" }) ?? limits.first {
            return "\(Int(session.percent.rounded()))%"
        }
        return status == .loggedOut ? "–" : "…"
    }

    var isLoggedIn: Bool { status != .loggedOut }

    // MARK: Acciones

    func showLogin() { loginWindow.show() }

    func logout() async {
        await client.logout()
        UserDefaults.standard.removeObject(forKey: Self.orgKey)
        limits = []
        orgName = nil
        lastUpdated = nil
        status = .loggedOut
    }

    func refreshIfStale() async {
        if let lastUpdated, Date().timeIntervalSince(lastUpdated) < 60 { return }
        await refresh()
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer {
            isRefreshing = false
            scheduleNextRefresh()
        }
        status = .loading
        let previous = Dictionary(uniqueKeysWithValues: limits.map { ($0.id, $0.percent) })

        do {
            guard await ClaudeClient.hasSessionCookie() else { throw ClaudeError.notLoggedIn }

            guard let orgs = try await client.getJSON("/api/organizations") as? [[String: Any]] else {
                throw ClaudeError.badResponse
            }
            for org in orderedOrganizations(orgs) {
                guard let uuid = org["uuid"] as? String,
                      let usage = try? await client.getJSON("/api/organizations/\(uuid)/usage") as? [String: Any]
                else { continue }
                let parsed = Self.parseLimits(usage)
                if parsed.isEmpty { continue }

                UserDefaults.standard.set(uuid, forKey: Self.orgKey)
                let current = Dictionary(uniqueKeysWithValues: parsed.map { ($0.id, $0.percent) })
                interval = current == previous
                    ? min(interval * 2, Self.maxInterval)
                    : Self.minInterval
                limits = parsed
                orgName = org["name"] as? String
                lastUpdated = Date()
                status = .ok
                return
            }
            throw ClaudeError.noUsage
        } catch ClaudeError.notLoggedIn {
            limits = []
            status = .loggedOut
            interval = Self.maxInterval
        } catch {
            status = .error(error.localizedDescription)
            interval = Self.maxInterval
        }
    }

    /// Programa la siguiente consulta. Si algún límite se reinicia antes, consulta justo después.
    private func scheduleNextRefresh() {
        var delay = interval
        let nextReset = limits.compactMap(\.resetsAt).filter { $0 > Date() }.min()
        if let nextReset {
            delay = min(delay, nextReset.timeIntervalSinceNow + 5)
        }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: max(delay, 10), repeats: false) { [weak self] _ in
            Task { await self?.refresh() }
        }
    }

    // MARK: Parseo

    /// La organización guardada primero; después las que tienen chat (cuentas de claude.ai).
    private func orderedOrganizations(_ orgs: [[String: Any]]) -> [[String: Any]] {
        let saved = UserDefaults.standard.string(forKey: Self.orgKey)
        func rank(_ org: [String: Any]) -> Int {
            if let saved, org["uuid"] as? String == saved { return 0 }
            let caps = org["capabilities"] as? [String] ?? []
            return caps.contains("chat") ? 1 : 2
        }
        return orgs.sorted { rank($0) < rank($1) }
    }

    /// Toma cualquier límite que devuelva la página de uso ({ utilization, resets_at }),
    /// así aparecen también los que Anthropic agregue en el futuro.
    static func parseLimits(_ usage: [String: Any]) -> [UsageLimit] {
        let order = ["five_hour", "seven_day", "seven_day_opus", "seven_day_sonnet"]
        return usage.compactMap { key, value -> UsageLimit? in
            guard let dict = value as? [String: Any],
                  let utilization = (dict["utilization"] as? NSNumber)?.doubleValue
            else { return nil }
            return UsageLimit(
                id: key,
                title: title(for: key),
                percent: utilization,
                resetsAt: (dict["resets_at"] as? String).flatMap(parseDate)
            )
        }
        .sorted {
            let a = order.firstIndex(of: $0.id) ?? order.count
            let b = order.firstIndex(of: $1.id) ?? order.count
            return a == b ? $0.id < $1.id : a < b
        }
    }

    private static func title(for key: String) -> String {
        switch key {
        case "five_hour": return "Sesión actual (5 h)"
        case "seven_day": return "Semanal · todos los modelos"
        case "seven_day_opus": return "Semanal · Opus"
        case "seven_day_sonnet": return "Semanal · Sonnet"
        case "seven_day_oauth_apps": return "Semanal · apps conectadas"
        default:
            let words = key.split(separator: "_").map { $0.prefix(1).uppercased() + $0.dropFirst() }
            return words.joined(separator: " ")
        }
    }

    private static func parseDate(_ string: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return withFraction.date(from: string) ?? ISO8601DateFormatter().date(from: string)
    }

    // MARK: Inicio automático

    /// La primera vez que la app corre desde /Applications activa el inicio automático.
    /// Después respeta lo que elijas en el menú.
    private func enableLaunchAtLoginOnFirstRun() {
        let key = "didSetUpLaunchAtLogin"
        guard !UserDefaults.standard.bool(forKey: key),
              Bundle.main.bundlePath.hasPrefix("/Applications/")
        else { return }
        UserDefaults.standard.set(true, forKey: key)
        if !launchAtLogin { launchAtLogin = true }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            status = .error("No se pudo cambiar el inicio automático: \(error.localizedDescription)")
        }
    }
}
