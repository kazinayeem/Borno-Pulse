//
//  LaunchAtLoginService.swift
//  Borno Pulse
//

import Foundation
import ServiceManagement

public final class LaunchAtLoginService: Sendable {
    public static let shared = LaunchAtLoginService()
    
    private init() {}
    
    public var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }
    
    public func setEnabled(_ enable: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enable {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                print("LaunchAtLoginService error: \(error)")
            }
        }
    }
}
