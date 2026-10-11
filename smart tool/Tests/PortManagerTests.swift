//
//  PortManagerTests.swift
//  Borno Pulse
//
//  Automated unit tests for Port Manager, socket parsing, dev server identification,
//  secret redaction, conflict detection, termination safety, and presets.
//

import AppKit
import Darwin
import Foundation
import SwiftUI

extension SmartToolTests {
    @MainActor
    static func runPortManagerTests(_ assert: (Bool, String) -> Void) {
        // 1. Structured Lsof Parser Tests
        let sampleLsofOutput = """
        p1001
        cnode
        u501
        PTCP
        tIPv4
        n*:3000
        TST=LISTEN
        p1002
        cpython3
        u501
        PTCP
        tIPv4
        n127.0.0.1:8000
        TST=LISTEN
        p1003
        cvite
        u501
        PTCP
        tIPv6
        n[::1]:5173
        TST=LISTEN
        """
        
        let parsedEntries = PortScannerService.parseLsofStructuredOutput(sampleLsofOutput)
        assert(parsedEntries.count == 3, "PortManager: parsed exactly 3 lsof entries (got \(parsedEntries.count))")
        
        if parsedEntries.count >= 3 {
            assert(parsedEntries[0].port == 3000 && parsedEntries[0].command == "node" && parsedEntries[0].pid == 1001, "PortManager: entry 0 correctly parsed port 3000, node, PID 1001")
            assert(parsedEntries[1].port == 8000 && parsedEntries[1].localAddress == "127.0.0.1:8000", "PortManager: entry 1 parsed 127.0.0.1:8000")
            assert(parsedEntries[2].port == 5173 && parsedEntries[2].ipVersion == "IPv6", "PortManager: entry 2 parsed IPv6 port 5173")
        }
        
        // Empty lsof test
        let emptyEntries = PortScannerService.parseLsofStructuredOutput("")
        assert(emptyEntries.isEmpty, "PortManager: empty lsof output produces empty array")
        
        // 2. Port Number Parsing
        assert(PortScannerService.parsePortNumber(from: "*:3000") == 3000, "PortManager: parsePortNumber '*:3000' -> 3000")
        assert(PortScannerService.parsePortNumber(from: "127.0.0.1:5173") == 5173, "PortManager: parsePortNumber '127.0.0.1:5173' -> 5173")
        assert(PortScannerService.parsePortNumber(from: "[::1]:8080") == 8080, "PortManager: parsePortNumber '[::1]:8080' -> 8080")
        assert(PortScannerService.parsePortNumber(from: "invalid") == nil, "PortManager: parsePortNumber returns nil on non-numeric")
        
        // 3. Dev Server Classification
        let viteDev = PortScannerService.classifyDevServer(
            processName: "node",
            executablePath: "/opt/homebrew/bin/node",
            commandLine: "/opt/homebrew/bin/node /workspace/node_modules/.bin/vite --port 5173",
            port: 5173,
            isDocker: false
        )
        assert(viteDev?.framework == "Vite", "PortManager: Vite dev server identified from command line")
        
        let nextDev = PortScannerService.classifyDevServer(
            processName: "next-server",
            executablePath: "/usr/local/bin/node",
            commandLine: "node node_modules/.bin/next dev",
            port: 3000,
            isDocker: false
        )
        assert(nextDev?.framework == "Next.js", "PortManager: Next.js server identified")
        
        let djangoDev = PortScannerService.classifyDevServer(
            processName: "python3",
            executablePath: "/usr/bin/python3",
            commandLine: "python3 manage.py runserver 0.0.0.0:8000",
            port: 8000,
            isDocker: false
        )
        assert(djangoDev?.framework == "Django", "PortManager: Django runserver identified")
        
        let fastapiDev = PortScannerService.classifyDevServer(
            processName: "python3",
            executablePath: "/usr/local/bin/python3",
            commandLine: "uvicorn app.main:app --reload --port 8000",
            port: 8000,
            isDocker: false
        )
        assert(fastapiDev?.framework == "FastAPI", "PortManager: FastAPI / Uvicorn identified")
        
        let pgDev = PortScannerService.classifyDevServer(
            processName: "postgres",
            executablePath: "/opt/homebrew/opt/postgresql@16/bin/postgres",
            commandLine: "/opt/homebrew/opt/postgresql@16/bin/postgres -D /opt/homebrew/var/postgres",
            port: 5432,
            isDocker: false
        )
        assert(pgDev?.framework == "PostgreSQL", "PortManager: PostgreSQL server identified")
        
        let redisDev = PortScannerService.classifyDevServer(
            processName: "redis-server",
            executablePath: "/usr/local/bin/redis-server",
            commandLine: "redis-server *:6379",
            port: 6379,
            isDocker: false
        )
        assert(redisDev?.framework == "Redis", "PortManager: Redis store identified")
        
        let sysDaemon = PortScannerService.classifyDevServer(
            processName: "rapportd",
            executablePath: "/usr/libexec/rapportd",
            commandLine: "/usr/libexec/rapportd",
            port: 55287,
            isDocker: false
        )
        assert(sysDaemon == nil, "PortManager: system daemon rapportd is not falsely classified as dev server")
        
        // 4. Secret Redaction
        let rawSecretCmd = "python3 manage.py runserver --password SuperSecretPass123! --token eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.xyz --host 0.0.0.0"
        let redacted = PortScannerService.redactSecrets(from: rawSecretCmd)
        assert(!redacted.contains("SuperSecretPass123!"), "PortManager: secret password was redacted")
        assert(!redacted.contains("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.xyz"), "PortManager: secret token was redacted")
        assert(redacted.contains("••••••••"), "PortManager: redaction placeholder inserted")
        assert(redacted.contains("--host 0.0.0.0"), "PortManager: non-sensitive flags preserved")
        
        // 5. Conflict Detection
        let itemA = PortItem(
            id: "100:3000",
            port: 3000,
            protocolType: "TCP",
            localAddress: "127.0.0.1:3000",
            ipVersion: "IPv4",
            pid: 100,
            processName: "node-server",
            command: "node",
            commandLine: "node server.js",
            redactedCommandLine: "node server.js",
            executablePath: "/usr/local/bin/node",
            user: "dev",
            uid: 501
        )
        let itemB = PortItem(
            id: "200:3000",
            port: 3000,
            protocolType: "TCP",
            localAddress: "*:3000",
            ipVersion: "IPv6",
            pid: 200,
            processName: "python-server",
            command: "python3",
            commandLine: "python3 server.py",
            redactedCommandLine: "python3 server.py",
            executablePath: "/usr/bin/python3",
            user: "dev",
            uid: 501
        )
        let conflicts = PortScannerService.detectConflicts(in: [itemA, itemB])
        assert(conflicts.count == 1, "PortManager: detected conflict on port 3000 when 2 distinct PIDs listen")
        assert(conflicts.first?.port == 3000, "PortManager: conflict port is 3000")
        
        // Dual stack on same PID is not a conflict
        let itemA_v6 = PortItem(
            id: "100:3000:v6",
            port: 3000,
            protocolType: "TCP6",
            localAddress: "[::1]:3000",
            ipVersion: "IPv6",
            pid: 100,
            processName: "node-server",
            command: "node",
            commandLine: "node server.js",
            redactedCommandLine: "node server.js",
            executablePath: "/usr/local/bin/node",
            user: "dev",
            uid: 501
        )
        let noConflict = PortScannerService.detectConflicts(in: [itemA, itemA_v6])
        assert(noConflict.isEmpty, "PortManager: dual-stack sockets on same PID do not trigger false conflict")
        
        // 6. Docker Port Extraction
        let mockContainer = DockerContainerItem(
            id: "abc123456789",
            names: "pg-database",
            image: "postgres:16",
            status: "Up 2 hours",
            state: "running",
            ports: "0.0.0.0:5432->5432/tcp, :::5432->5432/tcp"
        )
        let dockerMappings = PortScannerService.extractDockerPortMappings(from: [mockContainer])
        assert(dockerMappings.count == 2, "PortManager: parsed 2 docker port bindings")
        assert(dockerMappings.first?.hostPort == 5432, "PortManager: docker host port is 5432")
        assert(dockerMappings.first?.containerName == "pg-database", "PortManager: docker container name is pg-database")
        
        // 7. Safety Validation for Termination
        let myPid = getpid()
        let ownProcessItem = PortItem(
            id: "\(myPid):9999",
            port: 9999,
            protocolType: "TCP",
            localAddress: "*:9999",
            ipVersion: "IPv4",
            pid: myPid,
            processName: "smart tool",
            command: "smart tool",
            commandLine: "smart tool",
            redactedCommandLine: "smart tool",
            executablePath: "/path/to/smart tool",
            user: "dev",
            uid: 501
        )
        let ownValidation = ProcessTerminationService.shared.validateCanTerminate(item: ownProcessItem)
        assert(!ownValidation.canTerminate, "PortManager: refusing to terminate own application PID")
        
        let launchdItem = PortItem(
            id: "1:80",
            port: 80,
            protocolType: "TCP",
            localAddress: "*:80",
            ipVersion: "IPv4",
            pid: 1,
            processName: "launchd",
            command: "launchd",
            commandLine: "/sbin/launchd",
            redactedCommandLine: "/sbin/launchd",
            executablePath: "/sbin/launchd",
            user: "root",
            uid: 0
        )
        let launchdValidation = ProcessTerminationService.shared.validateCanTerminate(item: launchdItem)
        assert(!launchdValidation.canTerminate, "PortManager: refusing to terminate PID 1 (launchd)")
        
        let windowServerItem = PortItem(
            id: "200:1234",
            port: 1234,
            protocolType: "TCP",
            localAddress: "*:1234",
            ipVersion: "IPv4",
            pid: 200,
            processName: "WindowServer",
            command: "WindowServer",
            commandLine: "/System/Library/Frameworks/CoreGraphics.framework/WindowServer",
            redactedCommandLine: "",
            executablePath: "",
            user: "root",
            uid: 0
        )
        let wsValidation = ProcessTerminationService.shared.validateCanTerminate(item: windowServerItem)
        assert(!wsValidation.canTerminate, "PortManager: refusing to terminate WindowServer")
        
        // 8. Port Filter Presets
        for preset in PortFilterPreset.allCases {
            assert(!preset.rawValue.isEmpty, "PortFilterPreset '\(preset.rawValue)' has non-empty label")
            assert(!preset.icon.isEmpty, "PortFilterPreset '\(preset.rawValue)' has non-empty icon")
        }
        assert(PortFilterPreset.frontend.defaultPorts.contains(5173), "PortFilterPreset frontend contains Vite port 5173")
        assert(PortFilterPreset.databases.defaultPorts.contains(5432), "PortFilterPreset databases contains Postgres port 5432")
        
        // 9. QuickLauncher Integration
        let qlItems = QuickLauncherService.shared.search(query: "port")
        assert(qlItems.contains(where: { $0.id == "port_manager" }), "QuickLauncher: search for 'port' finds Port Manager")
        
        // 10. CSV Export Formatting
        let csv = PortScannerService.shared.exportCSV()
        assert(csv.hasPrefix("Port,Process,PID,Protocol,Local Address,User,Category,Dev Server,Executable Path,Start Time\n"), "PortManager: CSV export contains expected header columns")
    }
}
