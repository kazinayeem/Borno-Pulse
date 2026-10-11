//
//  HIDThermalSensorReader.swift
//  Borno Pulse
//
//  Reads named temperature services from the IOHID event system (Apple Silicon).
//
//  Compatibility & distribution notes:
//  • Enumerating services and their properties uses public API
//    (IOHIDEventSystemClientCopyServices / IOHIDServiceClientCopyProperty).
//  • Creating a client that may read events, copying the temperature event and reading its
//    value require private IOKit symbols (IOHIDEventSystemClientCreate,
//    IOHIDServiceClientCopyEvent, IOHIDEventGetFloatValue). They are resolved with dlsym so a
//    future macOS that removes them yields `.unavailable` instead of a launch failure.
//  • Private symbol use is not permitted for Mac App Store distribution.
//  • Sensor names ("gas gauge battery", "NAND CH0 temp", "PMU tdie1", …) come from the
//    system and are used verbatim for classification; nothing is renamed to CPU/GPU unless
//    the system's own name says so.
//

import Foundation
import IOKit
import IOKit.hidsystem

final class HIDThermalSensorReader: @unchecked Sendable {
    private typealias CreateClientFn = @convention(c) (CFAllocator?) -> Unmanaged<IOHIDEventSystemClient>?
    private typealias CopyEventFn = @convention(c) (IOHIDServiceClient, Int64, Int32, Int64) -> Unmanaged<CFTypeRef>?
    private typealias GetFloatValueFn = @convention(c) (CFTypeRef, Int32) -> Double

    private static let vendorUsagePage = 0xff00
    private static let temperatureUsage = 5
    private static let temperatureEventType: Int64 = 15
    private static let temperatureLevelField = Int32(15 << 16)
    private static let serviceRefreshInterval: TimeInterval = 60

    private struct Service {
        let client: IOHIDServiceClient
        let product: String
        let locationID: Int
        let component: ThermalComponent
    }

    private var createClient: CreateClientFn?
    private var copyEvent: CopyEventFn?
    private var getFloatValue: GetFloatValueFn?
    private var symbolFailure: String?

    private var client: IOHIDEventSystemClient?
    private var services: [Service] = []
    private var lastServiceRefresh: Date = .distantPast

    init() {
        guard let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW) else {
            symbolFailure = "IOKit could not be loaded."
            return
        }
        guard let create = dlsym(handle, "IOHIDEventSystemClientCreate"),
              let copy = dlsym(handle, "IOHIDServiceClientCopyEvent"),
              let value = dlsym(handle, "IOHIDEventGetFloatValue") else {
            symbolFailure = "This macOS version does not provide the HID thermal event interface."
            return
        }
        createClient = unsafeBitCast(create, to: CreateClientFn.self)
        copyEvent = unsafeBitCast(copy, to: CopyEventFn.self)
        getFloatValue = unsafeBitCast(value, to: GetFloatValueFn.self)
    }

    /// Call from a single serial context.
    func readTemperatures(now: Date = Date()) -> SensorReadResult {
        if let failure = symbolFailure {
            return .unavailable(reason: failure)
        }
        guard let copyEvent, let getFloatValue else {
            return .unavailable(reason: "The HID thermal event interface is unavailable.")
        }
        if client == nil {
            client = createClient?(kCFAllocatorDefault)?.takeRetainedValue()
        }
        guard let client else {
            return .unavailable(reason: "macOS refused to create an HID event system client.")
        }

        if services.isEmpty || now.timeIntervalSince(lastServiceRefresh) > Self.serviceRefreshInterval {
            services = Self.temperatureServices(of: client)
            lastServiceRefresh = now
        }
        guard !services.isEmpty else {
            return .unavailable(reason: "No HID temperature services are published on this Mac.")
        }

        var values: [RawTemperatureValue] = []
        for service in services {
            guard let event = copyEvent(service.client, Self.temperatureEventType, 0, 0)?.takeRetainedValue() else { continue }
            let celsius = getFloatValue(event, Self.temperatureLevelField)
            values.append(RawTemperatureValue(
                key: "\(service.product)#\(String(format: "0x%08x", service.locationID))",
                name: service.product,
                celsius: celsius,
                source: .hidEventSystem
            ))
        }
        if values.isEmpty {
            return .unavailable(reason: "HID temperature services exist but returned no events. Reading them may require an unsandboxed app.")
        }
        return .values(values)
    }

    private static func temperatureServices(of client: IOHIDEventSystemClient) -> [Service] {
        guard let all = IOHIDEventSystemClientCopyServices(client) as? [IOHIDServiceClient] else { return [] }
        return all.compactMap { service in
            let page = (IOHIDServiceClientCopyProperty(service, kIOHIDPrimaryUsagePageKey as CFString) as? NSNumber)?.intValue
            let usage = (IOHIDServiceClientCopyProperty(service, kIOHIDPrimaryUsageKey as CFString) as? NSNumber)?.intValue
            guard page == vendorUsagePage, usage == temperatureUsage,
                  let product = IOHIDServiceClientCopyProperty(service, kIOHIDProductKey as CFString) as? String,
                  let component = SensorClassifier.component(forHIDProduct: product) else { return nil }
            let location = (IOHIDServiceClientCopyProperty(service, kIOHIDLocationIDKey as CFString) as? NSNumber)?.intValue ?? 0
            return Service(client: service, product: product, locationID: location, component: component)
        }
    }
}
