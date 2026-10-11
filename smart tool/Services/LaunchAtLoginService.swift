//
//  LaunchAtLoginService.swift
//  Borno Pulse
//

import Foundation
import ServiceManagement

public enum LaunchAtLoginStatus: Equatable, Sendable {
    case enabled
    case disabled
    /// Registered, but the user must allow it in System Settings › General › Login Items.
    case requiresApproval
    case failed(String)

    public var isOn: Bool {
        self == .enabled || self == .requiresApproval
    }

    public var message: String? {
        switch self {
        case .enabled, .disabled:
            return nil
        case .requiresApproval:
            return "Allow Borno Pulse in System Settings › General › Login Items to finish turning this on."
        case .failed(let reason):
            return "Couldn't change the login item: \(reason)"
        }
    }
}

public final class LaunchAtLoginService: Sendable {
    public static let shared = LaunchAtLoginService()
    
    private init() {}
    
    public var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public var status: LaunchAtLoginStatus {
        switch SMAppService.mainApp.status {
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        case .notRegistered, .notFound: return .disabled
        @unknown default: return .disabled
        }
    }
    
    /// Registers or removes the login item. Only call in response to an explicit user choice.
    @discardableResult
    public func setEnabled(_ enable: Bool) -> LaunchAtLoginStatus {
        do {
            if enable {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if [.enabled, .requiresApproval].contains(SMAppService.mainApp.status) {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            let current = status
            // Registration can throw while still leaving the item pending approval.
            if enable && current == .requiresApproval { return current }
            return .failed(error.localizedDescription)
        }
        return status
    }

    public func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
