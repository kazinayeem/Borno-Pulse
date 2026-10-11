//
//  PortModels.swift
//  Borno Pulse
//
//  Data models for Port Manager and Local Development Server Monitor.
//

import Foundation
import SwiftUI

// MARK: - Process Classification Category
public enum ProcessCategory: String, CaseIterable, Identifiable, Sendable {
    case userDevelopment = "Dev Server"
    case userApplication = "User App"
    case systemService = "System Service"
    case dockerContainer = "Docker Container"
    case unknown = "Process"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .userDevelopment: return "hammer.fill"
        case .userApplication: return "app.fill"
        case .systemService: return "gearshape.fill"
        case .dockerContainer: return "shippingbox.fill"
        case .unknown: return "cpu"
        }
    }
}

// MARK: - Recognized Dev Server Frameworks
public struct DevServerType: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let framework: String
    public let icon: String
    public let defaultPort: Int?
    
    public init(id: String, name: String, framework: String, icon: String, defaultPort: Int? = nil) {
        self.id = id
        self.name = name
        self.framework = framework
        self.icon = icon
        self.defaultPort = defaultPort
    }
    
    public static let vite = DevServerType(id: "vite", name: "Vite Dev Server", framework: "Vite", icon: "bolt.fill", defaultPort: 5173)
    public static let nextjs = DevServerType(id: "nextjs", name: "Next.js Application", framework: "Next.js", icon: "arrow.triangle.pull", defaultPort: 3000)
    public static let react = DevServerType(id: "react", name: "React Dev Server", framework: "React", icon: "atom", defaultPort: 3000)
    public static let angular = DevServerType(id: "angular", name: "Angular CLI Server", framework: "Angular", icon: "shield.fill", defaultPort: 4200)
    public static let vue = DevServerType(id: "vue", name: "Vue CLI Dev Server", framework: "Vue", icon: "v.circle.fill", defaultPort: 8080)
    public static let node = DevServerType(id: "node", name: "Node.js / Express Server", framework: "Node.js", icon: "hexagon.fill", defaultPort: 3000)
    public static let bun = DevServerType(id: "bun", name: "Bun Development Server", framework: "Bun", icon: "flame.fill", defaultPort: 3000)
    public static let deno = DevServerType(id: "deno", name: "Deno Server", framework: "Deno", icon: "safari.fill", defaultPort: 8000)
    public static let laravel = DevServerType(id: "laravel", name: "Laravel Artisan Server", framework: "Laravel", icon: "diamond.fill", defaultPort: 8000)
    public static let django = DevServerType(id: "django", name: "Django Runserver", framework: "Django", icon: "d.circle.fill", defaultPort: 8000)
    public static let flask = DevServerType(id: "flask", name: "Flask Dev Server", framework: "Flask", icon: "flask.fill", defaultPort: 5000)
    public static let fastapi = DevServerType(id: "fastapi", name: "FastAPI / Uvicorn Server", framework: "FastAPI", icon: "bolt.horizontal.fill", defaultPort: 8000)
    public static let storybook = DevServerType(id: "storybook", name: "Storybook Studio", framework: "Storybook", icon: "book.fill", defaultPort: 6006)
    public static let jupyter = DevServerType(id: "jupyter", name: "Jupyter Notebook / Lab", framework: "Jupyter", icon: "sun.max.fill", defaultPort: 8888)
    public static let postgres = DevServerType(id: "postgres", name: "PostgreSQL Database", framework: "PostgreSQL", icon: "cylinder.split.1x2.fill", defaultPort: 5432)
    public static let mysql = DevServerType(id: "mysql", name: "MySQL / MariaDB Database", framework: "MySQL", icon: "cylinder.fill", defaultPort: 3306)
    public static let redis = DevServerType(id: "redis", name: "Redis In-Memory Store", framework: "Redis", icon: "circle.grid.3x3.fill", defaultPort: 6379)
    public static let mongodb = DevServerType(id: "mongodb", name: "MongoDB Database", framework: "MongoDB", icon: "leaf.fill", defaultPort: 27017)
    public static let docker = DevServerType(id: "docker", name: "Docker Published Service", framework: "Docker", icon: "shippingbox.fill", defaultPort: nil)
    public static let goServer = DevServerType(id: "go", name: "Go HTTP Server", framework: "Go", icon: "chevron.left.forwardslash.chevron.right", defaultPort: 8080)
    public static let rustServer = DevServerType(id: "rust", name: "Rust / Cargo Server", framework: "Rust", icon: "gear", defaultPort: 8080)
    public static let rails = DevServerType(id: "rails", name: "Ruby on Rails Server", framework: "Rails", icon: "sparkles", defaultPort: 3000)
    public static let genericDev = DevServerType(id: "genericDev", name: "Development Server", framework: "Development", icon: "network", defaultPort: nil)
}

// MARK: - Docker Port Mapping
public struct DockerPortMapping: Hashable, Sendable {
    public let containerID: String
    public let containerName: String
    public let image: String
    public let hostPort: Int
    public let containerPort: Int
    public let status: String
    
    public init(containerID: String, containerName: String, image: String, hostPort: Int, containerPort: Int, status: String) {
        self.containerID = containerID
        self.containerName = containerName
        self.image = image
        self.hostPort = hostPort
        self.containerPort = containerPort
        self.status = status
    }
}

// MARK: - Port Item
public struct PortItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let port: Int
    public let protocolType: String // "TCP", "TCP6"
    public let localAddress: String // "*:3000", "127.0.0.1:5173", "[::1]:8080"
    public let ipVersion: String // "IPv4", "IPv6"
    public let pid: pid_t
    public let ppid: pid_t?
    public let processName: String
    public let command: String
    public let commandLine: String
    public let redactedCommandLine: String
    public let executablePath: String
    public let user: String
    public let uid: uid_t
    public let startTime: Date?
    public let startTimeString: String
    public let listeningState: String
    public let category: ProcessCategory
    public let devServerType: DevServerType?
    public let childPIDs: [pid_t]
    public let isDockerPublished: Bool
    public let dockerMapping: DockerPortMapping?
    public var associatedPorts: [Int]
    
    public init(
        id: String,
        port: Int,
        protocolType: String,
        localAddress: String,
        ipVersion: String,
        pid: pid_t,
        ppid: pid_t? = nil,
        processName: String,
        command: String,
        commandLine: String,
        redactedCommandLine: String,
        executablePath: String,
        user: String,
        uid: uid_t,
        startTime: Date? = nil,
        startTimeString: String = "",
        listeningState: String = "LISTEN",
        category: ProcessCategory = .unknown,
        devServerType: DevServerType? = nil,
        childPIDs: [pid_t] = [],
        isDockerPublished: Bool = false,
        dockerMapping: DockerPortMapping? = nil,
        associatedPorts: [Int] = []
    ) {
        self.id = id
        self.port = port
        self.protocolType = protocolType
        self.localAddress = localAddress
        self.ipVersion = ipVersion
        self.pid = pid
        self.ppid = ppid
        self.processName = processName
        self.command = command
        self.commandLine = commandLine
        self.redactedCommandLine = redactedCommandLine
        self.executablePath = executablePath
        self.user = user
        self.uid = uid
        self.startTime = startTime
        self.startTimeString = startTimeString
        self.listeningState = listeningState
        self.category = category
        self.devServerType = devServerType
        self.childPIDs = childPIDs
        self.isDockerPublished = isDockerPublished
        self.dockerMapping = dockerMapping
        self.associatedPorts = associatedPorts
    }
    
    public var isLocalhostOnly: Bool {
        localAddress.hasPrefix("127.0.0.1") || localAddress.hasPrefix("[::1]") || localAddress.hasPrefix("localhost")
    }
    
    public var formattedURLString: String {
        let host = isLocalhostOnly ? "127.0.0.1" : "localhost"
        return "http://\(host):\(port)"
    }
}

// MARK: - Port Conflict Item
public struct PortConflictItem: Identifiable, Hashable, Sendable {
    public var id: Int { port }
    public let port: Int
    public let processes: [PortItem]
    public let reason: String
    
    public init(port: Int, processes: [PortItem], reason: String) {
        self.port = port
        self.processes = processes
        self.reason = reason
    }
}

// MARK: - Presets & Filtering
public enum PortFilterPreset: String, CaseIterable, Identifiable, Sendable {
    case all = "All Ports"
    case devServers = "Dev Servers"
    case frontend = "Frontend"
    case backend = "Backend"
    case databases = "Databases"
    case docker = "Docker"
    case custom = "Custom"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .all: return "network"
        case .devServers: return "laptopcomputer"
        case .frontend: return "chevron.left.forwardslash.chevron.right"
        case .backend: return "server.rack"
        case .databases: return "cylinder.split.1x2.fill"
        case .docker: return "shippingbox.fill"
        case .custom: return "slider.horizontal.3"
        }
    }
    
    public var defaultPorts: [Int] {
        switch self {
        case .all:
            return []
        case .devServers:
            return [3000, 3001, 4000, 4200, 5000, 5173, 5432, 6006, 6379, 8000, 8080, 8888, 9229, 27017]
        case .frontend:
            return [3000, 3001, 4200, 5173, 8080, 6006]
        case .backend:
            return [4000, 5000, 8000, 8080, 8888, 9229]
        case .databases:
            return [5432, 3306, 6379, 27017]
        case .docker:
            return []
        case .custom:
            return []
        }
    }
}

// MARK: - Sort Options
public enum PortSortColumn: String, CaseIterable, Identifiable, Sendable {
    case port = "Port"
    case name = "Process"
    case pid = "PID"
    case user = "User"
    case address = "Address"
    
    public var id: String { rawValue }
}
