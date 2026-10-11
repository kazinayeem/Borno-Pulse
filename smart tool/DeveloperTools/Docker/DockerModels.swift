//
//  DockerModels.swift
//  Borno Pulse
//

import Foundation

public struct DockerContainerItem: Identifiable, Sendable {
    public let id: String
    public let names: String
    public let image: String
    public let status: String
    public let state: String // "running", "exited", "paused"
    public let ports: String
    public var cpuPercent: String
    public var memoryUsage: String
    
    public var isRunning: Bool {
        state.lowercased().contains("running") || status.lowercased().hasPrefix("up")
    }
    
    public init(
        id: String,
        names: String,
        image: String,
        status: String,
        state: String,
        ports: String = "",
        cpuPercent: String = "0.0%",
        memoryUsage: String = "0 B"
    ) {
        self.id = id
        self.names = names
        self.image = image
        self.status = status
        self.state = state
        self.ports = ports
        self.cpuPercent = cpuPercent
        self.memoryUsage = memoryUsage
    }
}

public struct DockerImageItem: Identifiable, Sendable {
    public let id: String
    public let repository: String
    public let tag: String
    public let size: String
    public let createdSince: String
    
    public init(id: String, repository: String, tag: String, size: String, createdSince: String) {
        self.id = id
        self.repository = repository
        self.tag = tag
        self.size = size
        self.createdSince = createdSince
    }
}

public struct DockerSystemSummary: Sendable {
    public let isAvailable: Bool
    public let engineVersion: String?
    public let socketPath: String?
    public let runningContainersCount: Int
    public let totalContainersCount: Int
    public let imagesCount: Int
    public let message: String
    
    public init(
        isAvailable: Bool,
        engineVersion: String? = nil,
        socketPath: String? = nil,
        runningContainersCount: Int = 0,
        totalContainersCount: Int = 0,
        imagesCount: Int = 0,
        message: String = ""
    ) {
        self.isAvailable = isAvailable
        self.engineVersion = engineVersion
        self.socketPath = socketPath
        self.runningContainersCount = runningContainersCount
        self.totalContainersCount = totalContainersCount
        self.imagesCount = imagesCount
        self.message = message
    }
}
