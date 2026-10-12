//
//  SystemCleanerModels.swift
//  Borno Pulse
//
//  Production-grade models for System Cleaner and Node.js Project Cleanup
//

import Foundation
import SwiftUI

// MARK: - Cleanup Modes
public enum CleanerMode: String, CaseIterable, Identifiable, Sendable {
    case quick = "Quick Clean"
    case developer = "Developer Clean"
    case custom = "Custom Clean"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .quick: return "bolt.shield.fill"
        case .developer: return "hammer.fill"
        case .custom: return "slider.horizontal.3"
        }
    }
    
    public var description: String {
        switch self {
        case .quick:
            return "Safely clears safe user caches, expired temp files, and old logs without touching development dependencies."
        case .developer:
            return "Includes Node.js node_modules, Xcode DerivedData, and package manager caches with reinstall warnings."
        case .custom:
            return "Full manual control over every individual category, folder, and dependency item."
        }
    }
}

// MARK: - Safety Classification
public enum CleanerSafetyTier: String, Sendable, Comparable {
    case safe = "Safe"
    case caution = "Rebuild Needed"
    case warning = "Explicit Review"
    
    public static func < (lhs: CleanerSafetyTier, rhs: CleanerSafetyTier) -> Bool {
        switch (lhs, rhs) {
        case (.safe, .caution), (.safe, .warning), (.caution, .warning): return true
        default: return false
        }
    }
    
    public var badgeColor: Color {
        switch self {
        case .safe: return AppTheme.successGreen
        case .caution: return AppTheme.warningAmber
        case .warning: return AppTheme.orangeAccent
        }
    }
}

// MARK: - System Category Group
public enum CleanerCategoryGroup: String, CaseIterable, Identifiable, Sendable {
    case system = "System & User Caches"
    case developer = "Developer Build Artifacts"
    case packageManagers = "Package Manager Caches"
    case nodeProjects = "Node.js Dependencies"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .system: return "sparkles"
        case .developer: return "hammer.fill"
        case .packageManagers: return "shippingbox.fill"
        case .nodeProjects: return "cube.box.fill"
        }
    }
}

// MARK: - Enhanced Category Model
public struct SystemCleanupCategoryItem: Identifiable, Sendable {
    public var id: String
    public var name: String
    public var group: CleanerCategoryGroup
    public var icon: String
    public var path: String
    public var estimatedSizeBytes: UInt64
    public var fileCount: Int
    public var safety: CleanerSafetyTier
    public var reason: String
    public var isSelected: Bool
    public var isScanning: Bool
    public var files: [CleanupFileItem]
    
    public init(
        id: String,
        name: String,
        group: CleanerCategoryGroup,
        icon: String,
        path: String,
        estimatedSizeBytes: UInt64 = 0,
        fileCount: Int = 0,
        safety: CleanerSafetyTier = .safe,
        reason: String,
        isSelected: Bool = false,
        isScanning: Bool = false,
        files: [CleanupFileItem] = []
    ) {
        self.id = id
        self.name = name
        self.group = group
        self.icon = icon
        self.path = path
        self.estimatedSizeBytes = estimatedSizeBytes
        self.fileCount = fileCount
        self.safety = safety
        self.reason = reason
        self.isSelected = isSelected
        self.isScanning = isScanning
        self.files = files
    }
}

// MARK: - Detected Package Manager
public enum NodePackageManager: String, CaseIterable, Sendable {
    case npm = "npm"
    case pnpm = "pnpm"
    case yarn = "yarn"
    case bun = "bun"
    
    public var reinstallCommand: String {
        switch self {
        case .npm: return "npm install"
        case .pnpm: return "pnpm install"
        case .yarn: return "yarn install"
        case .bun: return "bun install"
        }
    }
    
    public var icon: String {
        switch self {
        case .npm: return "shippingbox"
        case .pnpm: return "bolt.fill"
        case .yarn: return "arrow.triangle.swap"
        case .bun: return "flame.fill"
        }
    }
}

// MARK: - Node Project Item
public struct NodeProjectItem: Identifiable, Sendable, Hashable {
    public var id: String { nodeModulesPath }
    public var projectPath: String
    public var projectName: String
    public var nodeModulesPath: String
    public var sizeBytes: UInt64
    public var fileCount: Int
    public var lastModified: Date?
    public var isGitRepo: Bool
    public var hasPackageJson: Bool
    public var packageManager: NodePackageManager
    public var lockfileName: String?
    public var isMonorepo: Bool
    public var isActivelyUsed: Bool
    public var isSelected: Bool
    
    public init(
        projectPath: String,
        projectName: String,
        nodeModulesPath: String,
        sizeBytes: UInt64 = 0,
        fileCount: Int = 0,
        lastModified: Date? = nil,
        isGitRepo: Bool = false,
        hasPackageJson: Bool = true,
        packageManager: NodePackageManager = .npm,
        lockfileName: String? = nil,
        isMonorepo: Bool = false,
        isActivelyUsed: Bool = false,
        isSelected: Bool = false
    ) {
        self.projectPath = projectPath
        self.projectName = projectName
        self.nodeModulesPath = nodeModulesPath
        self.sizeBytes = sizeBytes
        self.fileCount = fileCount
        self.lastModified = lastModified
        self.isGitRepo = isGitRepo
        self.hasPackageJson = hasPackageJson
        self.packageManager = packageManager
        self.lockfileName = lockfileName
        self.isMonorepo = isMonorepo
        self.isActivelyUsed = isActivelyUsed
        self.isSelected = isSelected
    }
}

// MARK: - Disk Space Info
public struct DiskVolumeSpace: Sendable {
    public var totalCapacityBytes: UInt64
    public var availableBytes: UInt64
    public var usedBytes: UInt64
    public var purgeableBytes: UInt64
    
    public var usedPercentage: Double {
        guard totalCapacityBytes > 0 else { return 0.0 }
        return Double(usedBytes) / Double(totalCapacityBytes)
    }
    
    public init(totalCapacityBytes: UInt64 = 0, availableBytes: UInt64 = 0, usedBytes: UInt64 = 0, purgeableBytes: UInt64 = 0) {
        self.totalCapacityBytes = totalCapacityBytes
        self.availableBytes = availableBytes
        self.usedBytes = usedBytes
        self.purgeableBytes = purgeableBytes
    }
}

// MARK: - Post-Cleanup Report
public struct CleanerExecutionReport: Sendable {
    public var bytesFreed: UInt64
    public var itemsRemoved: Int
    public var failuresCount: Int
    public var errors: [String]
    public var durationSeconds: Double
    
    public init(bytesFreed: UInt64 = 0, itemsRemoved: Int = 0, failuresCount: Int = 0, errors: [String] = [], durationSeconds: Double = 0.0) {
        self.bytesFreed = bytesFreed
        self.itemsRemoved = itemsRemoved
        self.failuresCount = failuresCount
        self.errors = errors
        self.durationSeconds = durationSeconds
    }
}
