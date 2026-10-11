//
//  BackupModels.swift
//  Borno Pulse
//

import Foundation

public enum BackupMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case full = "Full Copy"
    case incremental = "Incremental Sync"
    case mirror = "Mirror Mode (Advanced)"
    
    public var id: String { rawValue }
    
    public var description: String {
        switch self {
        case .full:
            return "Creates an isolated timestamped backup folder containing all selected source files."
        case .incremental:
            return "Copies only new or modified files based on file size and timestamp, preserving unchanged files."
        case .mirror:
            return "Synchronizes destination exactly with source. Removes orphaned destination files that no longer exist in source."
        }
    }
}

public struct BackupProfile: Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var sourcePaths: [String]
    public var destinationPath: String
    public var mode: BackupMode
    public var exclusions: [String]
    public var verifyChecksums: Bool
    public var lastRunDate: Date?
    public var lastStatus: String?
    
    public init(
        id: UUID = UUID(),
        name: String,
        sourcePaths: [String] = [],
        destinationPath: String = "",
        mode: BackupMode = .incremental,
        exclusions: [String] = [".DS_Store", "*.tmp", ".Trash"],
        verifyChecksums: Bool = true,
        lastRunDate: Date? = nil,
        lastStatus: String? = nil
    ) {
        self.id = id
        self.name = name
        self.sourcePaths = sourcePaths
        self.destinationPath = destinationPath
        self.mode = mode
        self.exclusions = exclusions
        self.verifyChecksums = verifyChecksums
        self.lastRunDate = lastRunDate
        self.lastStatus = lastStatus
    }
}

public struct BackupRunReport: Identifiable, Codable, Sendable {
    public let id: UUID
    public let profileName: String
    public let date: Date
    public let mode: BackupMode
    public let filesConsidered: Int
    public let filesCopied: Int
    public let filesSkipped: Int
    public let filesFailed: Int
    public let totalBytesCopied: Int64
    public let durationSeconds: Double
    public let verificationPassed: Bool
    public let destinationPath: String
    
    public init(
        id: UUID = UUID(),
        profileName: String,
        date: Date = Date(),
        mode: BackupMode,
        filesConsidered: Int,
        filesCopied: Int,
        filesSkipped: Int,
        filesFailed: Int,
        totalBytesCopied: Int64,
        durationSeconds: Double,
        verificationPassed: Bool,
        destinationPath: String
    ) {
        self.id = id
        self.profileName = profileName
        self.date = date
        self.mode = mode
        self.filesConsidered = filesConsidered
        self.filesCopied = filesCopied
        self.filesSkipped = filesSkipped
        self.filesFailed = filesFailed
        self.totalBytesCopied = totalBytesCopied
        self.durationSeconds = durationSeconds
        self.verificationPassed = verificationPassed
        self.destinationPath = destinationPath
    }
}
