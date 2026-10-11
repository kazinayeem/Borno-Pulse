//
//  IdleDetector.swift
//  Borno Pulse
//

import CoreGraphics
import Foundation
import IOKit

/// Native macOS hardware idle detector using IOHIDSystem and CoreGraphics event state.
/// Measures time elapsed since the last physical human keyboard, mouse, or trackpad interaction.
public final class IdleDetector: Sendable {
    public static let shared = IdleDetector()
    
    private init() {}
    
    /// Returns the system-wide idle time in seconds.
    public func getSystemIdleTimeSeconds() -> TimeInterval {
        // Primary: IOHIDSystem kernel idle time in nanoseconds
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOHIDSystem"), &iterator)
        if result == KERN_SUCCESS {
            let entry = IOIteratorNext(iterator)
            if entry != 0 {
                var unmanagedDict: Unmanaged<CFMutableDictionary>?
                if IORegistryEntryCreateCFProperties(entry, &unmanagedDict, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                   let dict = unmanagedDict?.takeRetainedValue() as? [String: Any],
                   let nanoseconds = dict["HIDIdleTime"] as? Int64 {
                    IOObjectRelease(entry)
                    IOObjectRelease(iterator)
                    return TimeInterval(nanoseconds) / 1_000_000_000.0
                }
                IOObjectRelease(entry)
            }
            IOObjectRelease(iterator)
        }
        
        // Fallback: CoreGraphics event source state
        let cgIdle = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: CGEventType(rawValue: ~0) ?? .null)
        if cgIdle >= 0 && cgIdle < 86400 {
            return cgIdle
        }
        
        return 0
    }
}
