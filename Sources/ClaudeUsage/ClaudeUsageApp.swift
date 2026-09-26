import SwiftUI

@main
struct ClaudeUsageApp: App {
    @StateObject private var store = UsageStore()

    var body: some Scene {
        MenuBarExtra {
            MenuView(store: store)
        } label: {
            Text("\(Image(systemName: "gauge.with.dots.needle.50percent")) \(store.menuBarText)")
        }
        .menuBarExtraStyle(.window)
    }
}
