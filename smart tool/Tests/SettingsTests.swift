//
//  SettingsTests.swift
//  Borno Pulse
//
//  Settings behavior tests. Every preference touched here is restored before the test returns.
//

import AppKit
import Combine
import Foundation
import SwiftUI

extension SmartToolTests {
    @MainActor
    static func runSettingsTests(_ assert: (Bool, String) -> Void) {
        let settings = AppSettings.shared

        var fired = 0
        let token = settings.objectWillChange.sink { _ in fired += 1 }
        let originalScale = settings.fontScale
        settings.fontScale = originalScale == 1.0 ? 1.05 : 1.0
        assert(fired > 0, "Settings: changing a stored preference notifies observers (fired \(fired))")
        settings.fontScale = originalScale
        token.cancel()
    }
}
