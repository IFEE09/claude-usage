import SwiftUI

@main
struct ClaudeUsageApp: App {
    @StateObject private var store = UsageStore()

    var body: some Scene {
        MenuBarExtra {
            MenuView(store: store)
        } label: {
            // La barra de menús no dibuja un Image metido dentro de un Text; van por separado.
            HStack(spacing: 4) {
                Image(systemName: "gauge.with.dots.needle.50percent")
                Text(store.menuBarText)
            }
        }
        .menuBarExtraStyle(.window)
    }
}
