import SwiftUI
import Charts

struct ContentView: View {
    @ObservedObject var monitor: NetworkMonitor
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("BandBar")
                    .font(.headline)
                Spacer()
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Image(systemName: "power")
                }
                .buttonStyle(.plain)
                .help("Quit")
            }
            .padding(.horizontal)
            .padding(.top, 10)
            
            // Sparklines
            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("↓ \(formatBytes(monitor.currentDownloadRate))/s")
                        .font(.body)
                        .foregroundColor(.green)
                    Chart(monitor.downloadHistory) { dp in
                        LineMark(
                            x: .value("Time", dp.time),
                            y: .value("Rate", dp.rate)
                        )
                        .foregroundStyle(.green)
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(height: 50)
                }
                
                VStack(alignment: .leading) {
                    Text("↑ \(formatBytes(monitor.currentUploadRate))/s")
                        .font(.body)
                        .foregroundColor(.blue)
                    Chart(monitor.uploadHistory) { dp in
                        LineMark(
                            x: .value("Time", dp.time),
                            y: .value("Rate", dp.rate)
                        )
                        .foregroundStyle(.blue)
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(height: 50)
                }
            }
            .padding(.horizontal)
            
            Divider()
            
            // Process List
            Table(monitor.topProcesses) {
                TableColumn("App") { proc in
                    HStack(spacing: 8) {
                        if let icon = proc.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "terminal")
                                .resizable()
                                .frame(width: 16, height: 16)
                                .foregroundColor(.gray)
                        }
                        VStack(alignment: .leading) {
                            Text(proc.detail.name)
                                .font(.subheadline)
                                .lineLimit(1)
                            if let conn = proc.detail.connections.first {
                                Text(conn)
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .width(min: 150, ideal: 180)
                
                TableColumn("↓ Down") { proc in
                    Text("\(formatBytes(proc.detail.downloadRate))/s")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .width(60)
                
                TableColumn("↑ Up") { proc in
                    Text("\(formatBytes(proc.detail.uploadRate))/s")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .width(60)
            }
        }
        .frame(width: 380, height: 500)
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes)).replacingOccurrences(of: " ", with: "")
    }
}
