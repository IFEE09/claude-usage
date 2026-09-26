import AppKit
import SwiftUI

struct MenuView: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Uso de Claude").font(.headline)
                Spacer()
                if store.status == .loading {
                    ProgressView().controlSize(.small)
                }
            }

            if store.status == .loggedOut {
                Text("Inicia sesión en claude.ai para ver tus límites.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button("Iniciar sesión…") { store.showLogin() }
                    .buttonStyle(.borderedProminent)
            }

            if case .error(let message) = store.status {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Redibuja cada 30 s para que la cuenta regresiva no se congele con el menú abierto.
            TimelineView(.periodic(from: .now, by: 30)) { _ in
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(store.limits) { LimitRow(limit: $0) }
                }
            }

            if let lastUpdated = store.lastUpdated {
                Text(footer(lastUpdated))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                Button("Actualizar") { Task { await store.refresh() } }
                Button("Abrir en claude.ai") {
                    NSWorkspace.shared.open(URL(string: "https://claude.ai/settings/usage")!)
                }
            }

            Toggle("Abrir al iniciar sesión en el Mac", isOn: $store.launchAtLogin)
                .toggleStyle(.checkbox)

            HStack {
                if store.isLoggedIn {
                    Button("Cerrar sesión") { Task { await store.logout() } }
                }
                Spacer()
                Button("Salir") { NSApp.terminate(nil) }
            }
        }
        .padding(14)
        .frame(width: 300)
        .task { await store.refreshIfStale() }
    }

    private func footer(_ date: Date) -> String {
        let time = date.formatted(date: .omitted, time: .shortened)
        if let org = store.orgName { return "\(org) · actualizado \(time)" }
        return "Actualizado \(time)"
    }
}

struct LimitRow: View {
    let limit: UsageLimit

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(limit.title).font(.subheadline.weight(.medium))
                Spacer()
                Text("\(Int(limit.percent.rounded()))%")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(color)
            }
            ProgressView(value: min(max(limit.percent, 0), 100), total: 100)
                .tint(color)
            if let resetsAt = limit.resetsAt {
                Text("Se reinicia \(Self.resetText(resetsAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var color: Color {
        switch limit.percent {
        case 90...: return .red
        case 75...: return .orange
        default: return .accentColor
        }
    }

    static func resetText(_ date: Date) -> String {
        let seconds = date.timeIntervalSinceNow
        if seconds <= 0 { return "ahora" }
        if seconds < 24 * 3600 {
            let hours = Int(seconds) / 3600
            let minutes = (Int(seconds) % 3600) / 60
            return hours > 0 ? "en \(hours) h \(minutes) min" : "en \(minutes) min"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es")
        formatter.setLocalizedDateFormatFromTemplate("EEE d MMM HH:mm")
        return "el \(formatter.string(from: date))"
    }
}
