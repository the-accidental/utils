import Foundation
import Combine
import AppKit

struct ProcessDetail: Identifiable, Sendable {
    let id: UUID
    let pid: Int
    let name: String
    var totalDownload: Int
    var totalUpload: Int
    var downloadRate: Int
    var uploadRate: Int
    var connections: [String]
}

struct DataPoint: Identifiable, Sendable {
    let id = UUID()
    let time: Date
    let rate: Int
}

struct ProcessUIModel: Identifiable {
    var id: UUID { detail.id }
    let detail: ProcessDetail
    let icon: NSImage?
}

@MainActor
class NetworkMonitor: ObservableObject {
    @Published var currentDownloadRate: Int = .zero
    @Published var currentUploadRate: Int = .zero
    @Published var topProcesses: [ProcessUIModel] = []
    
    @Published var downloadHistory: [DataPoint] = []
    @Published var uploadHistory: [DataPoint] = []

    private var previousProcessStats: [Int: (down: Int, up: Int)] = [:]
    private var monitoringTask: Task<Void, Never>?
    private var lastSampleTime: Date = Date()
    
    private var iconCache: [Int: NSImage] = [:]
    
    init() {
        let now = Date()
        for i in (0..<60).reversed() {
            downloadHistory.append(DataPoint(time: now.addingTimeInterval(TimeInterval(-i)), rate: 0))
            uploadHistory.append(DataPoint(time: now.addingTimeInterval(TimeInterval(-i)), rate: 0))
        }
        
        startMonitoring()
    }
    
    func startMonitoring() {
        monitoringTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }
                let output = await Self.fetchNettopOutput()
                self.parseNettopOutput(output)
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
        }
    }
    
    nonisolated static func fetchNettopOutput() async -> String {
        return await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
            process.arguments = ["-L", "1", "-J", "bytes_in,bytes_out"]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    return output
                }
            } catch {
                print("Failed to run nettop: \(error)")
            }
            return ""
        }.value
    }
    
    @MainActor
    private func parseNettopOutput(_ output: String) {
        let now = Date()
        let elapsed = max(0.001, now.timeIntervalSince(lastSampleTime))
        self.lastSampleTime = now
        
        let lines = output.components(separatedBy: .newlines)
        
        var parsedProcesses: [Int: ProcessDetail] = [:]
        var currentPID: Int? = nil
        var totalDownRate = 0
        var totalUpRate = 0
        
        for line in lines {
            if line.isEmpty { continue }
            
            let parts = line.components(separatedBy: ",")
            if parts.isEmpty { continue }
            
            let firstCol = parts[0]
            if firstCol == "time" { continue } // Header
            
            if firstCol.hasPrefix("tcp") || firstCol.hasPrefix("udp") || firstCol.hasPrefix("quic") {
                if let pid = currentPID {
                    let connectionStr = firstCol
                        .components(separatedBy: " ").last?
                        .components(separatedBy: "<->").last ?? firstCol
                    
                    if connectionStr != "*.*" && connectionStr != "*:*" && !connectionStr.isEmpty {
                        if !parsedProcesses[pid]!.connections.contains(connectionStr) {
                             parsedProcesses[pid]!.connections.append(connectionStr)
                        }
                    }
                }
            } else {
                if let dotIndex = firstCol.lastIndex(of: ".") {
                    let name = String(firstCol[..<dotIndex])
                    if let pid = Int(firstCol[firstCol.index(after: dotIndex)...]) {
                        
                        let strIn = parts.count > 1 ? parts[1] : "0"
                        let strOut = parts.count > 2 ? parts[2] : "0"
                        let bytesIn = Int(strIn) ?? 0
                        let bytesOut = Int(strOut) ?? 0
                        
                        var detail = ProcessDetail(
                            id: UUID(),
                            pid: pid,
                            name: name,
                            totalDownload: bytesIn,
                            totalUpload: bytesOut,
                            downloadRate: 0,
                            uploadRate: 0,
                            connections: []
                        )
                        
                        if let prev = previousProcessStats[pid] {
                            let downR = bytesIn - prev.down
                            let upR = bytesOut - prev.up
                            detail.downloadRate = max(0, Int(Double(downR) / elapsed))
                            detail.uploadRate = max(0, Int(Double(upR) / elapsed))
                            
                            totalDownRate += detail.downloadRate
                            totalUpRate += detail.uploadRate
                        }
                        
                        previousProcessStats[pid] = (bytesIn, bytesOut)
                        parsedProcesses[pid] = detail
                        currentPID = pid
                    }
                }
            }
        }
        
        let newProcesses = Array(parsedProcesses.values)
            .filter { $0.downloadRate > 0 || $0.uploadRate > 0 }
            .sorted { ($0.downloadRate + $0.uploadRate) > ($1.downloadRate + $1.uploadRate) }
        
        var topWithIcons: [ProcessUIModel] = []
        for proc in newProcesses.prefix(20) {
            let pid = proc.pid
            let icon: NSImage?
            if let cached = iconCache[pid] {
                icon = cached
            } else {
                icon = self.getIcon(for: pid)
                if let ic = icon { iconCache[pid] = ic }
            }
            topWithIcons.append(ProcessUIModel(detail: proc, icon: icon))
        }
        
        self.topProcesses = topWithIcons
        self.currentDownloadRate = totalDownRate
        self.currentUploadRate = totalUpRate
        
        self.downloadHistory.append(DataPoint(time: now, rate: totalDownRate))
        if self.downloadHistory.count > 60 { self.downloadHistory.removeFirst() }
        
        self.uploadHistory.append(DataPoint(time: now, rate: totalUpRate))
        if self.uploadHistory.count > 60 { self.uploadHistory.removeFirst() }
        
        if Int.random(in: 0...100) == 0 {
            let activePIDs = Set(parsedProcesses.keys)
            self.iconCache = self.iconCache.filter { activePIDs.contains($0.key) }
        }
    }
    
    private func getIcon(for pid: Int) -> NSImage? {
        if let app = NSRunningApplication(processIdentifier: pid_t(pid)) {
            return app.icon
        }
        return nil
    }
}
