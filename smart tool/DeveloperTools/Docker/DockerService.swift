//
//  DockerService.swift
//  Borno Pulse
//

import AppKit
import Foundation

public final class DockerService: Sendable {
    public static let shared = DockerService()
    
    private init() {}
    
    // Potential Docker binary locations on macOS (Homebrew Apple Silicon, Homebrew Intel, Docker Desktop standard)
    private var possibleDockerPaths: [String] {
        [
            "/usr/local/bin/docker",
            "/opt/homebrew/bin/docker",
            "/usr/bin/docker",
            "/Applications/Docker.app/Contents/Resources/bin/docker"
        ]
    }
    
    public func findDockerCLI() -> String? {
        let fm = FileManager.default
        for p in possibleDockerPaths {
            if fm.isExecutableFile(atPath: p) {
                return p
            }
        }
        return nil
    }
    
    // MARK: - Check System Availability
    public func fetchSummary() async -> (summary: DockerSystemSummary, containers: [DockerContainerItem], images: [DockerImageItem]) {
        guard let dockerCLI = findDockerCLI() else {
            return (
                DockerSystemSummary(
                    isAvailable: false,
                    message: "Docker CLI not detected in standard system paths. Install Docker Desktop or OrbStack to view containers."
                ),
                [],
                []
            )
        }
        
        // Query version
        let versionOut = runProcess(executable: dockerCLI, arguments: ["version", "--format", "{{.Server.Version}}"])
        let engineVer = versionOut.output.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard versionOut.exitCode == 0, !engineVer.isEmpty else {
            return (
                DockerSystemSummary(
                    isAvailable: false,
                    engineVersion: nil,
                    message: "Docker CLI found at \(dockerCLI), but Docker daemon is currently stopped or unreachable."
                ),
                [],
                []
            )
        }
        
        // Query containers: docker ps -a --format '{{json .}}'
        let psOut = runProcess(executable: dockerCLI, arguments: ["ps", "-a", "--format", "{{json .}}"])
        var containerList: [DockerContainerItem] = []
        
        for line in psOut.output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                  let data = trimmed.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            
            let id = json["ID"] as? String ?? "unknown"
            let names = json["Names"] as? String ?? id
            let image = json["Image"] as? String ?? ""
            let status = json["Status"] as? String ?? ""
            let state = json["State"] as? String ?? ""
            let ports = json["Ports"] as? String ?? ""
            
            containerList.append(DockerContainerItem(
                id: id,
                names: names,
                image: image,
                status: status,
                state: state,
                ports: ports
            ))
        }
        
        // Query images: docker images --format '{{json .}}'
        let imagesOut = runProcess(executable: dockerCLI, arguments: ["images", "--format", "{{json .}}"])
        var imageList: [DockerImageItem] = []
        
        for line in imagesOut.output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                  let data = trimmed.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            
            let id = json["ID"] as? String ?? ""
            let repo = json["Repository"] as? String ?? "<none>"
            let tag = json["Tag"] as? String ?? "<none>"
            let size = json["Size"] as? String ?? "0 B"
            let created = json["CreatedSince"] as? String ?? ""
            
            imageList.append(DockerImageItem(
                id: id,
                repository: repo,
                tag: tag,
                size: size,
                createdSince: created
            ))
        }
        
        let runningCount = containerList.filter { $0.isRunning }.count
        
        let summary = DockerSystemSummary(
            isAvailable: true,
            engineVersion: engineVer,
            socketPath: "/var/run/docker.sock",
            runningContainersCount: runningCount,
            totalContainersCount: containerList.count,
            imagesCount: imageList.count,
            message: "Connected to Docker Engine \(engineVer)"
        )
        
        return (summary, containerList, imageList)
    }
    
    // MARK: - Actions
    public func startContainer(id: String) async -> Bool {
        guard let dockerCLI = findDockerCLI() else { return false }
        let res = runProcess(executable: dockerCLI, arguments: ["start", id])
        return res.exitCode == 0
    }
    
    public func stopContainer(id: String) async -> Bool {
        guard let dockerCLI = findDockerCLI() else { return false }
        let res = runProcess(executable: dockerCLI, arguments: ["stop", id])
        return res.exitCode == 0
    }
    
    public func restartContainer(id: String) async -> Bool {
        guard let dockerCLI = findDockerCLI() else { return false }
        let res = runProcess(executable: dockerCLI, arguments: ["restart", id])
        return res.exitCode == 0
    }
    
    public func fetchContainerLogs(id: String) async -> String {
        guard let dockerCLI = findDockerCLI() else { return "Docker CLI unavailable" }
        let res = runProcess(executable: dockerCLI, arguments: ["logs", "--tail", "100", id])
        return res.output.isEmpty ? "(No logs available)" : res.output
    }
    
    // MARK: - Subprocess Helper
    private func runProcess(executable: String, arguments: [String]) -> (output: String, exitCode: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return (output, process.terminationStatus)
        } catch {
            return (error.localizedDescription, -1)
        }
    }
}
