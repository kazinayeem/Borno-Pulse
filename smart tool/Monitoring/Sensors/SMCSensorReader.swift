//
//  SMCSensorReader.swift
//  Borno Pulse
//
//  Read-only access to temperature and fan keys of the System Management Controller.
//
//  Compatibility & distribution notes:
//  • The AppleSMC user-client protocol (selector 2, SMCKeyData struct) is undocumented.
//    It works for unsandboxed apps without root on Intel and Apple Silicon, but Apple may
//    change it in any macOS release. Every failure path returns `.unavailable` instead of
//    a value, so the UI degrades to an honest "unavailable" state.
//  • App Sandbox (and therefore the Mac App Store) blocks opening the AppleSMC user client.
//  • Key → component mapping follows the community-documented naming convention
//    (Tp/Te = CPU clusters, Tg = GPU on Apple Silicon; TC/TG on Intel; TB = battery).
//    Readings are marked `.keyConvention` so the UI can disclose this.
//  • This reader never writes SMC keys.
//

import Foundation
import IOKit

final class SMCSensorReader: @unchecked Sendable {
    private struct Version { var major: UInt8 = 0; var minor: UInt8 = 0; var build: UInt8 = 0; var reserved: UInt8 = 0; var release: UInt16 = 0 }
    private struct PowerLimit { var version: UInt16 = 0; var length: UInt16 = 0; var cpu: UInt32 = 0; var gpu: UInt32 = 0; var memory: UInt32 = 0 }
    private struct KeyInfo { var dataSize: UInt32 = 0; var dataType: UInt32 = 0; var dataAttributes: UInt8 = 0 }
    private typealias Bytes32 = (
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
    )

    /// Mirrors the kernel's 80-byte SMCKeyData_t layout.
    private struct Param {
        var key: UInt32 = 0
        var version = Version()
        var powerLimit = PowerLimit()
        var keyInfo = KeyInfo()
        var padding: UInt16 = 0
        var result: UInt8 = 0
        var status: UInt8 = 0
        var command: UInt8 = 0
        var data32: UInt32 = 0
        var bytes: Bytes32 = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    }

    private enum Command: UInt8 {
        case readKey = 5
        case keyFromIndex = 8
        case keyInfo = 9
    }

    private struct DiscoveredKey {
        let key: String
        let code: UInt32
        let info: KeyInfo
        let component: ThermalComponent
    }

    private let isAppleSilicon: Bool
    private var connection: io_connect_t = 0
    private var openFailureReason: String?
    private var temperatureKeys: [DiscoveredKey]?
    private var keyInfoCache: [UInt32: KeyInfo] = [:]

    init() {
        #if arch(arm64)
        isAppleSilicon = true
        #else
        isAppleSilicon = false
        #endif
    }

    deinit {
        if connection != 0 { IOServiceClose(connection) }
    }

    // MARK: - Public API (call from a single serial context)

    func readTemperatures() -> SensorReadResult {
        guard openIfNeeded() else {
            return .unavailable(reason: openFailureReason ?? "The SMC could not be opened.")
        }
        if temperatureKeys == nil {
            temperatureKeys = discoverTemperatureKeys()
        }
        guard let keys = temperatureKeys, !keys.isEmpty else {
            return .unavailable(reason: "The SMC exposes no CPU, GPU or battery temperature keys on this Mac.")
        }

        var values: [RawTemperatureValue] = []
        values.reserveCapacity(keys.count)
        for entry in keys {
            guard let bytes = read(code: entry.code, info: entry.info),
                  let value = Self.decode(type: entry.info.dataType, bytes: bytes) else { continue }
            values.append(RawTemperatureValue(
                key: entry.key,
                name: SensorClassifier.smcDisplayName(forKey: entry.key, component: entry.component),
                celsius: value,
                source: .smc
            ))
        }
        if values.isEmpty {
            return .unavailable(reason: "SMC temperature keys exist but returned no readable values.")
        }
        return .values(values)
    }

    func readFans() -> FanReadResult {
        guard openIfNeeded() else {
            return .unavailable(reason: openFailureReason ?? "The SMC could not be opened.")
        }
        guard let count = readNumber("FNum") else {
            return .fans(reportedCount: 0, readings: [])
        }
        let fanCount = max(0, Int(count))
        var readings: [RawFanValue] = []
        for index in 0..<fanCount {
            guard let rpm = readNumber("F\(index)Ac"), rpm.isFinite, rpm >= 0 else { continue }
            readings.append(RawFanValue(
                index: index,
                rpm: rpm,
                minRPM: readNumber("F\(index)Mn"),
                maxRPM: readNumber("F\(index)Mx")
            ))
        }
        return .fans(reportedCount: fanCount, readings: readings)
    }

    // MARK: - Connection

    private func openIfNeeded() -> Bool {
        if connection != 0 { return true }
        if openFailureReason != nil { return false }

        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else {
            openFailureReason = "No AppleSMC service was found."
            return false
        }
        defer { IOObjectRelease(service) }

        var conn: io_connect_t = 0
        let result = IOServiceOpen(service, mach_task_self_, 0, &conn)
        guard result == kIOReturnSuccess, conn != 0 else {
            openFailureReason = "macOS denied access to the SMC (IOServiceOpen error \(String(format: "0x%08x", result))). This happens when the app is sandboxed."
            return false
        }
        connection = conn
        return true
    }

    private func call(_ input: inout Param) -> Param? {
        var output = Param()
        var outputSize = MemoryLayout<Param>.stride
        let result = IOConnectCallStructMethod(connection, 2, &input, MemoryLayout<Param>.stride, &output, &outputSize)
        guard result == kIOReturnSuccess, output.result == 0 else { return nil }
        return output
    }

    // MARK: - Key Access

    private func keyInfo(_ code: UInt32) -> KeyInfo? {
        if let cached = keyInfoCache[code] { return cached }
        var input = Param()
        input.key = code
        input.command = Command.keyInfo.rawValue
        guard let output = call(&input) else { return nil }
        keyInfoCache[code] = output.keyInfo
        return output.keyInfo
    }

    private func read(code: UInt32, info: KeyInfo) -> [UInt8]? {
        var input = Param()
        input.key = code
        input.keyInfo.dataSize = info.dataSize
        input.command = Command.readKey.rawValue
        guard let output = call(&input) else { return nil }
        let all = withUnsafeBytes(of: output.bytes) { Array($0) }
        return Array(all.prefix(Int(min(info.dataSize, 32))))
    }

    private func readNumber(_ key: String) -> Double? {
        let code = Self.fourCharCode(key)
        guard let info = keyInfo(code), let bytes = read(code: code, info: info) else { return nil }
        return Self.decode(type: info.dataType, bytes: bytes)
    }

    private func discoverTemperatureKeys() -> [DiscoveredKey] {
        guard let total = readNumber("#KEY"), total > 0 else { return [] }
        var keys: [DiscoveredKey] = []
        for index in 0..<UInt32(total) {
            var input = Param()
            input.command = Command.keyFromIndex.rawValue
            input.data32 = index
            guard let output = call(&input) else { continue }
            let name = Self.string(fromFourCharCode: output.key)
            guard let component = SensorClassifier.component(forSMCKey: name, isAppleSilicon: isAppleSilicon),
                  let info = keyInfo(output.key),
                  Self.isTemperatureType(info.dataType) else { continue }
            keys.append(DiscoveredKey(key: name, code: output.key, info: info, component: component))
        }
        return keys.sorted { $0.key < $1.key }
    }

    // MARK: - Decoding

    static func fourCharCode(_ string: String) -> UInt32 {
        string.utf8.prefix(4).reduce(0) { ($0 << 8) | UInt32($1) }
    }

    static func string(fromFourCharCode code: UInt32) -> String {
        let bytes = [UInt8(code >> 24 & 0xff), UInt8(code >> 16 & 0xff), UInt8(code >> 8 & 0xff), UInt8(code & 0xff)]
        return String(bytes: bytes, encoding: .ascii) ?? ""
    }

    private static func isTemperatureType(_ type: UInt32) -> Bool {
        let name = string(fromFourCharCode: type)
        return name == "flt " || name == "sp78"
    }

    /// Decodes SMC numeric types. `flt ` is native little-endian; integer and fixed-point types are big-endian.
    static func decode(type: UInt32, bytes: [UInt8]) -> Double? {
        switch string(fromFourCharCode: type) {
        case "flt ":
            guard bytes.count >= 4 else { return nil }
            let bits = UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
            return Double(Float32(bitPattern: bits))
        case "sp78":
            guard bytes.count >= 2 else { return nil }
            return Double(Int16(bitPattern: UInt16(bytes[0]) << 8 | UInt16(bytes[1]))) / 256.0
        case "fpe2":
            guard bytes.count >= 2 else { return nil }
            return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1])) / 4.0
        case "ui8 ":
            guard bytes.count >= 1 else { return nil }
            return Double(bytes[0])
        case "ui16":
            guard bytes.count >= 2 else { return nil }
            return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
        case "ui32":
            guard bytes.count >= 4 else { return nil }
            return Double(UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3]))
        default:
            return nil
        }
    }
}
