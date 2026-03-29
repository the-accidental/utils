import SwiftUI

@main
struct BandBarApp: App {
    @StateObject private var monitor = NetworkMonitor()

    init() {
        // Force the app to act as an accessory (Menu Bar only)
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            ContentView(monitor: monitor)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "network")
                if monitor.currentDownloadRate > 0 || monitor.currentUploadRate > 0 {
                    Text("↓\(formatBytes(monitor.currentDownloadRate)) ↑\(formatBytes(monitor.currentUploadRate))")
                        .font(.system(size: 10, design: .monospaced))
                }
            }
        }
        .menuBarExtraStyle(.window)
    }

    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .memory
        // Keep it concise for the menu bar
        return formatter.string(fromByteCount: Int64(bytes)).replacingOccurrences(of: " ", with: "")
    }
}
