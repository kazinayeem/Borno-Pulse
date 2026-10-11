//
//  FocusModels.swift
//  Borno Pulse
//

import Foundation

public enum FocusSessionMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case focus = "Focus Session"
    case shortBreak = "Short Break"
    case longBreak = "Long Break"
    
    public var id: String { rawValue }
    
    public var defaultMinutes: Int {
        switch self {
        case .focus: return 25
        case .shortBreak: return 5
        case .longBreak: return 15
        }
    }
}

public struct FocusSessionRecord: Identifiable, Codable, Sendable {
    public let id: UUID
    public let startTime: Date
    public let endTime: Date
    public let durationSeconds: TimeInterval
    public let mode: FocusSessionMode
    public let isCompleted: Bool
    
    public init(
        id: UUID = UUID(),
        startTime: Date,
        endTime: Date,
        durationSeconds: TimeInterval,
        mode: FocusSessionMode,
        isCompleted: Bool = true
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.durationSeconds = durationSeconds
        self.mode = mode
        self.isCompleted = isCompleted
    }
}
