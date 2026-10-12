//
//  PortScannerService.swift
//  Borno Pulse
//
//  High-performance socket scanner that discovers local listening TCP sockets,
//  classifies dev servers, enriches metadata with Darwin APIs, and correlates with Docker.
//

import AppKit
import Combine
import Darwin
import Foundation

@MainActor
public final class PortScannerService: ObservableObject {
    public static let shared = PortScannerService()
    
    // MARK: - Published State
    @Published public var ports: [PortItem] = []
    @Published public var conflicts: [PortConflictItem] = []
    @Published public var isLoading: Bool = false
    @Published public var lastScanDate: Date? = nil
    @Published public var errorMessage: String? = nil
    @Published public var isPaused: Bool = false
    
    // Filtering & Navigation State
    @Published public var searchText: String = ""
    @Published public var activePreset: PortFilterPreset = .all
    @Published public var customPortString: String = "3000, 5173, 8000, 8080"
    @Published public var sortColumn: PortSortColumn = .port
    @Published public var sortAscending: Bool = true
    @Published public var selectedPortItem: PortItem? = nil
    @Published public var hideCommandLines: Bool = false
    @Published public var autoRefreshInterval: Double = 5.0 // seconds, 0 = off
    
    // Docker status
    @Published public var dockerAvailable: Bool = false
    @Published public var dockerPublishedCount: Int = 0
    
    private var timerSubscription: AnyCancellable?
    private var inFlightScanTask: Task<Void, Never>?
    
    private init() {
        startAutoRefreshTimer()
        refresh()
    }
    
    // MARK: - Timer Control
    public func startAutoRefreshTimer() {
        timerSubscription?.cancel()
        guard autoRefreshInterval > 0, !isPaused else { return }
        
        timerSubscription = Timer.publish(every: autoRefreshInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, !self.isLoading, !self.isPaused else { return }
                self.refresh()
            }
    }
    
    public func pauseMonitoring() {
        isPaused = true
        timerSubscription?.cancel()
    }
    
    public func resumeMonitoring() {
        isPaused = false
        startAutoRefreshTimer()
        refresh()
    }
    
    public func updateInterval(_ seconds: Double) {
        autoRefreshInterval = seconds
        startAutoRefreshTimer()
    }
    
    // MARK: - Public Refresh
    public func refresh() {
        inFlightScanTask?.cancel()
        isLoading = true
        errorMessage = nil
        
        inFlightScanTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            
            let rawItems = await self.performLsofScan()
            let (enrichedItems, conflicts, dockerFound, dockerCount) = await self.enrichAndAnalyze(items: rawItems)
            
            await MainActor.run {
                self.ports = enrichedItems
                self.conflicts = conflicts
                self.dockerAvailable = dockerFound
                self.dockerPublishedCount = dockerCount
                self.lastScanDate = Date()
                self.isLoading = false
                
                // Keep selected port updated if still present
                if let currentSelected = self.selectedPortItem {
                    self.selectedPortItem = enrichedItems.first(where: { $0.id == currentSelected.id })
                }
            }
        }
    }
    
    // MARK: - Background Discovery
    private nonisolated func performLsofScan() async -> [RawLsofEntry] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        // -iTCP: TCP only
        // -sTCP:LISTEN: listening sockets only
        // -n: do not resolve hostnames
        // -P: do not resolve port names to service names
        // -F pcnPtTu: machine-parseable field output
        process.arguments = ["-iTCP", "-sTCP:LISTEN", "-n", "-P", "-F", "pcnPtTu"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe() // suppress stderr
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let text = String(data: data, encoding: .utf8) else { return [] }
            return PortScannerService.parseLsofStructuredOutput(text)
        } catch {
            return []
        }
    }
    
    // MARK: - Machine-Parseable Lsof Output Parser
    public nonisolated static func parseLsofStructuredOutput(_ text: String) -> [RawLsofEntry] {
        var results: [RawLsofEntry] = []
        
        var currentPid: pid_t = 0
        var currentCmd: String = ""
        var currentUid: uid_t = 0
        
        var currentProto: String = "TCP"
        var currentType: String = "IPv4"
        var currentName: String = ""
        
        let lines = text.components(separatedBy: "\n")
        
        for line in lines {
            guard !line.isEmpty else { continue }
            let prefix = line.first!
            let value = String(line.dropFirst())
            
            switch prefix {
            case "p":
                currentPid = pid_t(value) ?? 0
            case "c":
                currentCmd = value
            case "u":
                currentUid = uid_t(value) ?? 0
            case "P":
                currentProto = value
            case "t":
                currentType = value
            case "n":
                currentName = value
                // A socket endpoint was specified
                if let port = parsePortNumber(from: currentName), currentPid > 0 {
                    results.append(RawLsofEntry(
                        pid: currentPid,
                        command: currentCmd,
                        uid: currentUid,
                        protocolType: currentProto,
                        ipVersion: currentType,
                        localAddress: currentName,
                        port: port
                    ))
                }
            default:
                break
            }
        }
        
        return results
    }
    
    public nonisolated static func parsePortNumber(from address: String) -> Int? {
        // Formats:
        // *:3000
        // 127.0.0.1:8080
        // [::1]:5173
        // *:http (if unformatted)
        guard let lastColon = address.lastIndex(of: ":") else { return nil }
        let portStr = address[address.index(after: lastColon)...]
        return Int(portStr)
    }
    
    // MARK: - Enrichment & Analysis
    private nonisolated func enrichAndAnalyze(items: [RawLsofEntry]) async -> (items: [PortItem], conflicts: [PortConflictItem], dockerAvailable: Bool, dockerCount: Int) {
        // Query Docker mappings
        let dockerSummary = await DockerService.shared.fetchSummary()
        let dockerMappings = PortScannerService.extractDockerPortMappings(from: dockerSummary.containers)
        
        // Collect unique PIDs for batch ps inspection
        let uniquePids = Array(Set(items.map { $0.pid }))
        let processDetails = PortScannerService.batchInspectProcesses(pids: uniquePids)
        
        // Group ports by PID to identify associated ports
        var pidToPorts: [pid_t: [Int]] = [:]
        for entry in items {
            pidToPorts[entry.pid, default: []].append(entry.port)
        }
        
        var enriched: [PortItem] = []
        var seenKeys: Set<String> = []
        
        for raw in items {
            // Deduplicate same port + protocol on same PID
            let key = "\(raw.pid):\(raw.port):\(raw.protocolType):\(raw.localAddress)"
            if seenKeys.contains(key) { continue }
            seenKeys.insert(key)
            
            let meta = processDetails[raw.pid]
            let procPath = PortScannerService.getProcessExecutablePath(pid: raw.pid) ?? meta?.executablePath ?? ""
            let procName = PortScannerService.resolveBestProcessName(rawCommand: raw.command, execPath: procPath, fullArgs: meta?.commandLine ?? "")
            let rawCmdLine = meta?.commandLine ?? procPath
            let redactedCmd = PortScannerService.redactSecrets(from: rawCmdLine)
            
            // Check Docker published mapping
            let dockerMatch = dockerMappings.first(where: { $0.hostPort == raw.port })
            let isDocker = dockerMatch != nil || procName.lowercased().contains("docker") || procPath.contains("Docker.app")
            
            let devServer = PortScannerService.classifyDevServer(
                processName: procName,
                executablePath: procPath,
                commandLine: rawCmdLine,
                port: raw.port,
                isDocker: isDocker
            )
            
            let category: ProcessCategory
            if isDocker {
                category = .dockerContainer
            } else if devServer != nil {
                category = .userDevelopment
            } else if raw.uid == 0 || procPath.hasPrefix("/System/") || procPath.hasPrefix("/usr/libexec/") {
                category = .systemService
            } else {
                category = .userApplication
            }
            
            let allPortsForPid = Array(Set(pidToPorts[raw.pid] ?? [raw.port])).sorted()
            
            let item = PortItem(
                id: key,
                port: raw.port,
                protocolType: raw.protocolType,
                localAddress: raw.localAddress,
                ipVersion: raw.ipVersion,
                pid: raw.pid,
                ppid: meta?.ppid,
                processName: procName,
                command: raw.command,
                commandLine: rawCmdLine,
                redactedCommandLine: redactedCmd,
                executablePath: procPath,
                user: meta?.user ?? (raw.uid == 0 ? "root" : NSUserName()),
                uid: raw.uid,
                startTime: meta?.startTime,
                startTimeString: meta?.startTimeString ?? "",
                listeningState: "LISTEN",
                category: category,
                devServerType: devServer,
                childPIDs: meta?.childPids ?? [],
                isDockerPublished: dockerMatch != nil,
                dockerMapping: dockerMatch,
                associatedPorts: allPortsForPid
            )
            enriched.append(item)
        }
        
        // Detect Conflicts
        let conflicts = PortScannerService.detectConflicts(in: enriched)
        let dockerCount = enriched.filter { $0.isDockerPublished }.count
        
        return (enriched, conflicts, dockerSummary.summary.isAvailable, dockerCount)
    }
    
    // MARK: - Process Metadata via Darwin & Batch PS
    public nonisolated static func getProcessExecutablePath(pid: pid_t) -> String? {
        var pathBuffer = [CChar](repeating: 0, count: 4096)
        let len = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))
        guard len > 0 else { return nil }
        return pathBuffer.withUnsafeBufferPointer { ptr in
            guard let base = ptr.baseAddress else { return nil }
            return String(cString: base)
        }
    }
    
    public nonisolated static func batchInspectProcesses(pids: [pid_t]) -> [pid_t: ProcessMetadata] {
        guard !pids.isEmpty else { return [:] }
        
        let pidStrings = pids.map { String($0) }.joined(separator: ",")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-p", pidStrings, "-o", "pid=,ppid=,user=,lstart=,command="]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        var results: [pid_t: ProcessMetadata] = [:]
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let text = String(data: data, encoding: .utf8) else { return [:] }
            
            for line in text.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { continue }
                
                // ps output format: PID PPID USER LSTART (approx 24 chars) COMMAND...
                let parts = trimmed.split(separator: " ", maxSplits: 4, omittingEmptySubsequences: true)
                guard parts.count >= 4 else { continue }
                
                guard let pid = pid_t(parts[0]) else { continue }
                let ppid = pid_t(parts[1])
                let user = String(parts[2])
                
                // The lstart field format is "Day Mon DD HH:MM:SS YYYY" (5 tokens)
                let commandTokens = trimmed.split(separator: " ", maxSplits: 7, omittingEmptySubsequences: true)
                var startTimeStr = ""
                var commandLine = ""
                
                if commandTokens.count >= 8 {
                    startTimeStr = "\(commandTokens[3]) \(commandTokens[4]) \(commandTokens[5])"
                    commandLine = String(commandTokens[7])
                } else if parts.count == 5 {
                    commandLine = String(parts[4])
                }
                
                results[pid] = ProcessMetadata(
                    pid: pid,
                    ppid: ppid,
                    user: user,
                    commandLine: commandLine,
                    executablePath: "",
                    startTime: nil,
                    startTimeString: startTimeStr,
                    childPids: []
                )
            }
        } catch {}
        
        return results
    }
    
    // MARK: - Process Name Resolution
    public nonisolated static func resolveBestProcessName(rawCommand: String, execPath: String, fullArgs: String) -> String {
        if !execPath.isEmpty {
            let lastComponent = (execPath as NSString).lastPathComponent
            if !lastComponent.isEmpty && lastComponent != "app_process" {
                return lastComponent
            }
        }
        if !rawCommand.isEmpty {
            return rawCommand
        }
        if !fullArgs.isEmpty {
            let first = fullArgs.split(separator: " ").first ?? ""
            return (String(first) as NSString).lastPathComponent
        }
        return "Unknown"
    }
    
    // MARK: - Secret Redaction
    public nonisolated static func redactSecrets(from commandLine: String) -> String {
        var sanitized = commandLine
        
        // Regex patterns for credentials
        let patterns = [
            #"(?i)(--password[=\s]+)([^\s]+)"#,
            #"(?i)(--secret[=\s]+)([^\s]+)"#,
            #"(?i)(--token[=\s]+)([^\s]+)"#,
            #"(?i)(--api[-_]?key[=\s]+)([^\s]+)"#,
            #"(?i)(--access[-_]?key[=\s]+)([^\s]+)"#,
            #"(?i)(password=)([^\s&]+)"#,
            #"(?i)(secret=)([^\s&]+)"#,
            #"(?i)(token=)([^\s&]+)"#,
            #"(?i)(bearer\s+)([A-Za-z0-9_\-\.]{15,})"#,
            #"(?i)(Authorization:\s*Bearer\s+)([^\s]+)"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(sanitized.startIndex..<sanitized.endIndex, in: sanitized)
                sanitized = regex.stringByReplacingMatches(in: sanitized, options: [], range: range, withTemplate: "$1••••••••")
            }
        }
        
        return sanitized
    }
    
    // MARK: - Dev Server Classifier
    public nonisolated static func classifyDevServer(
        processName: String,
        executablePath: String,
        commandLine: String,
        port: Int,
        isDocker: Bool
    ) -> DevServerType? {
        if isDocker {
            return DevServerType.docker
        }
        
        let pName = processName.lowercased()
        let cmd = commandLine.lowercased()
        let path = executablePath.lowercased()
        
        // 1. Vite
        if cmd.contains("vite") || pName.contains("vite") {
            return DevServerType.vite
        }
        
        // 2. Next.js
        if cmd.contains("next dev") || cmd.contains("next-server") || cmd.contains("node_modules/.bin/next") {
            return DevServerType.nextjs
        }
        
        // 3. React / Webpack
        if cmd.contains("react-scripts") || cmd.contains("webpack-dev-server") {
            return DevServerType.react
        }
        
        // 4. Angular
        if cmd.contains("ng serve") || cmd.contains("@angular/cli") {
            return DevServerType.angular
        }
        
        // 5. Vue CLI
        if cmd.contains("vue-cli-service") || cmd.contains("@vue/cli") {
            return DevServerType.vue
        }
        
        // 6. Bun
        if pName == "bun" || path.contains("/bun") || cmd.contains("bun run") {
            return DevServerType.bun
        }
        
        // 7. Deno
        if pName == "deno" || path.contains("/deno") {
            return DevServerType.deno
        }
        
        // 8. Storybook
        if cmd.contains("storybook") || cmd.contains("@storybook") {
            return DevServerType.storybook
        }
        
        // 9. Jupyter
        if pName.contains("jupyter") || cmd.contains("jupyter-lab") || cmd.contains("jupyter-notebook") {
            return DevServerType.jupyter
        }
        
        // 10. Laravel
        if cmd.contains("artisan serve") || (pName.contains("php") && cmd.contains("artisan")) {
            return DevServerType.laravel
        }
        
        // 11. Django
        if (pName.contains("python") || pName.contains("django")) && cmd.contains("runserver") {
            return DevServerType.django
        }
        
        // 12. Flask
        if (pName.contains("python") || pName.contains("flask")) && (cmd.contains("flask run") || cmd.contains("app.py")) {
            return DevServerType.flask
        }
        
        // 13. FastAPI / Uvicorn
        if pName.contains("uvicorn") || cmd.contains("uvicorn") || cmd.contains("gunicorn") || cmd.contains("fastapi") {
            return DevServerType.fastapi
        }
        
        // 14. PostgreSQL
        if pName.contains("postgres") || path.contains("postgres") {
            return DevServerType.postgres
        }
        
        // 15. MySQL / MariaDB
        if pName.contains("mysqld") || pName.contains("mariadbd") || path.contains("mysql") {
            return DevServerType.mysql
        }
        
        // 16. Redis
        if pName.contains("redis-server") || path.contains("redis") {
            return DevServerType.redis
        }
        
        // 17. MongoDB
        if pName.contains("mongod") || path.contains("mongod") {
            return DevServerType.mongodb
        }
        
        // 18. Rails / Puma
        if cmd.contains("rails server") || cmd.contains("puma") || (pName.contains("ruby") && cmd.contains("rails")) {
            return DevServerType.rails
        }
        
        // 19. Go Dev Server
        if cmd.contains("go run") || pName.contains("air") || path.contains("go-build") {
            return DevServerType.goServer
        }
        
        // 20. Rust Server
        if cmd.contains("cargo run") || cmd.contains("cargo-watch") {
            return DevServerType.rustServer
        }
        
        // 21. General Node.js / Express
        if pName == "node" || path.contains("/node") || cmd.contains("nodemon") || cmd.contains("ts-node") || cmd.contains("tsx") {
            return DevServerType.node
        }
        
        // Common dev port hints if running user code (e.g. 3000, 5173, 8000, 8080)
        let commonDevPorts: Set<Int> = [3000, 3001, 4000, 4200, 5000, 5173, 8000, 8080, 8888]
        if commonDevPorts.contains(port) && !path.hasPrefix("/System/") && !path.hasPrefix("/usr/libexec/") {
            return DevServerType.genericDev
        }
        
        return nil
    }
    
    // MARK: - Docker Port Extraction
    public nonisolated static func extractDockerPortMappings(from containers: [DockerContainerItem]) -> [DockerPortMapping] {
        var mappings: [DockerPortMapping] = []
        
        for c in containers {
            // Docker port string format: "0.0.0.0:5432->5432/tcp, :::5432->5432/tcp"
            let portsString = c.ports
            guard !portsString.isEmpty else { continue }
            
            for part in portsString.components(separatedBy: ",") {
                let trimmed = part.trimmingCharacters(in: .whitespaces)
                // Match host:port->container:port
                if let arrowIdx = trimmed.range(of: "->") {
                    let hostSide = trimmed[..<arrowIdx.lowerBound]
                    let containerSide = trimmed[arrowIdx.upperBound...]
                    
                    if let hostPort = parsePortNumber(from: String(hostSide)) {
                        let cPort = Int(containerSide.split(separator: "/").first ?? "") ?? hostPort
                        mappings.append(DockerPortMapping(
                            containerID: c.id,
                            containerName: c.names,
                            image: c.image,
                            hostPort: hostPort,
                            containerPort: cPort,
                            status: c.status
                        ))
                    }
                }
            }
        }
        
        return mappings
    }
    
    // MARK: - Conflict Detection
    public nonisolated static func detectConflicts(in items: [PortItem]) -> [PortConflictItem] {
        var portGroups: [Int: [PortItem]] = [:]
        for item in items {
            portGroups[item.port, default: []].append(item)
        }
        
        var conflicts: [PortConflictItem] = []
        
        for (port, group) in portGroups {
            // Distinct PIDs
            let pids = Set(group.map { $0.pid })
            if pids.count > 1 {
                let procNames = group.map { "\($0.processName) (PID: \($0.pid))" }.joined(separator: ", ")
                conflicts.append(PortConflictItem(
                    port: port,
                    processes: group,
                    reason: "Multiple processes are simultaneously bound to port \(port): \(procNames)."
                ))
            }
        }
        
        return conflicts.sorted { $0.port < $1.port }
    }
    
    // MARK: - Filtering & Sorting
    public var filteredPorts: [PortItem] {
        var list = ports
        
        // 1. Preset Filtering
        switch activePreset {
        case .all:
            break
        case .devServers:
            let devPorts = Set(PortFilterPreset.devServers.defaultPorts)
            list = list.filter { devPorts.contains($0.port) || $0.devServerType != nil }
        case .frontend:
            let fPorts = Set(PortFilterPreset.frontend.defaultPorts)
            list = list.filter { fPorts.contains($0.port) }
        case .backend:
            let bPorts = Set(PortFilterPreset.backend.defaultPorts)
            list = list.filter { bPorts.contains($0.port) }
        case .databases:
            let dPorts = Set(PortFilterPreset.databases.defaultPorts)
            list = list.filter { dPorts.contains($0.port) || $0.category == .userDevelopment && ($0.devServerType == .postgres || $0.devServerType == .mysql || $0.devServerType == .redis || $0.devServerType == .mongodb) }
        case .docker:
            list = list.filter { $0.isDockerPublished || $0.category == .dockerContainer }
        case .custom:
            let parsed = parseCustomPorts(customPortString)
            if !parsed.isEmpty {
                let customSet = Set(parsed)
                list = list.filter { customSet.contains($0.port) }
            }
        }
        
        // 2. Search Text Filtering
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            list = list.filter { item in
                String(item.port).contains(q) ||
                String(item.pid).contains(q) ||
                item.processName.lowercased().contains(q) ||
                item.executablePath.lowercased().contains(q) ||
                item.user.lowercased().contains(q) ||
                item.localAddress.lowercased().contains(q) ||
                (item.devServerType?.name.lowercased().contains(q) ?? false) ||
                (item.devServerType?.framework.lowercased().contains(q) ?? false)
            }
        }
        
        // 3. Sorting
        list.sort { a, b in
            switch sortColumn {
            case .port:
                return sortAscending ? a.port < b.port : a.port > b.port
            case .name:
                return sortAscending ? a.processName.localizedCaseInsensitiveCompare(b.processName) == .orderedAscending : a.processName.localizedCaseInsensitiveCompare(b.processName) == .orderedDescending
            case .pid:
                return sortAscending ? a.pid < b.pid : a.pid > b.pid
            case .user:
                return sortAscending ? a.user < b.user : a.user > b.user
            case .address:
                return sortAscending ? a.localAddress < b.localAddress : a.localAddress > b.localAddress
            }
        }
        
        return list
    }
    
    private func parseCustomPorts(_ str: String) -> [Int] {
        var ports: [Int] = []
        let parts = str.components(separatedBy: CharacterSet(charactersIn: ",; "))
        for p in parts {
            let trimmed = p.trimmingCharacters(in: .whitespaces)
            if let num = Int(trimmed), num > 0, num <= 65535 {
                ports.append(num)
            }
        }
        return ports
    }
    
    // MARK: - CSV Export
    public func exportCSV() -> String {
        var csv = "Port,Process,PID,Protocol,Local Address,User,Category,Dev Server,Executable Path,Start Time\n"
        for item in filteredPorts {
            let row = [
                "\(item.port)",
                "\"\(item.processName.replacingOccurrences(of: "\"", with: "\"\""))\"",
                "\(item.pid)",
                item.protocolType,
                item.localAddress,
                item.user,
                item.category.rawValue,
                item.devServerType?.name ?? "",
                "\"\(item.executablePath.replacingOccurrences(of: "\"", with: "\"\""))\"",
                item.startTimeString
            ].joined(separator: ",")
            csv.append(row + "\n")
        }
        return csv
    }
}

// MARK: - Internal Helper Structs
public struct RawLsofEntry: Sendable {
    public let pid: pid_t
    public let command: String
    public let uid: uid_t
    public let protocolType: String
    public let ipVersion: String
    public let localAddress: String
    public let port: Int
}

public struct ProcessMetadata: Sendable {
    public let pid: pid_t
    public let ppid: pid_t?
    public let user: String
    public let commandLine: String
    public let executablePath: String
    public let startTime: Date?
    public let startTimeString: String
    public let childPids: [pid_t]
}
