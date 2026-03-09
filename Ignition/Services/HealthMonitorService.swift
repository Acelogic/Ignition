import Foundation

struct AgentHealthInfo: Identifiable, Equatable {
    var id: String { label }
    let label: String
    var cpuPercent: Double
    var memoryMB: Double
    var pid: Int
}

@MainActor
class HealthMonitorService: ObservableObject {
    @Published var healthInfo: [String: AgentHealthInfo] = [:]
    @Published var crashLoopLabels: [String: Int] = [:]  // label → crash count in last hour

    private var pollTimer: Timer?

    func startMonitoring() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.pollProcessStats()
            }
        }
        Task { await pollProcessStats() }
    }

    func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func updateCrashLoops(from historyService: ActivityHistoryService) {
        crashLoopLabels = historyService.crashLoopAgents()
    }

    func healthFor(_ label: String) -> AgentHealthInfo? {
        healthInfo[label]
    }

    /// Problem agents: crash-looping or high CPU
    var problemAgents: [(label: String, reason: String)] {
        var problems: [(String, String)] = []

        for (label, count) in crashLoopLabels {
            problems.append((label, "Crash looping (\(count)x in last hour)"))
        }

        for (_, info) in healthInfo where info.cpuPercent > 90 {
            if !problems.contains(where: { $0.0 == info.label }) {
                problems.append((info.label, String(format: "High CPU: %.0f%%", info.cpuPercent)))
            }
        }

        return problems.sorted { $0.0 < $1.0 }
    }

    private func pollProcessStats() async {
        let result = await runPS()
        var newInfo: [String: AgentHealthInfo] = [:]

        for line in result.split(separator: "\n").dropFirst() {
            let cols = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
            guard cols.count >= 4 else { continue }

            guard let pid = Int(cols[0]),
                  let cpu = Double(cols[1]),
                  let memKB = Double(cols[2]) else { continue }

            let command = String(cols[3])

            // Store by PID for now; we'll correlate with agents later
            let info = AgentHealthInfo(
                label: command,
                cpuPercent: cpu,
                memoryMB: memKB / 1024.0,
                pid: pid
            )
            newInfo["\(pid)"] = info
        }

        healthInfo = newInfo
    }

    func statsForPID(_ pid: Int) -> AgentHealthInfo? {
        healthInfo["\(pid)"]
    }

    private func runPS() async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/ps")
                process.arguments = ["-eo", "pid,pcpu,rss,comm"]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = FileHandle.nullDevice

                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    continuation.resume(returning: String(data: data, encoding: .utf8) ?? "")
                } catch {
                    continuation.resume(returning: "")
                }
            }
        }
    }
}
