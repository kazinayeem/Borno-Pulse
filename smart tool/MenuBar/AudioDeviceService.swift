//
//  AudioDeviceService.swift
//  Borno Pulse
//
//  Native CoreAudio hardware device and application audio management service.
//

import AppKit
import CoreAudio
import Foundation

public struct AudioDeviceItem: Identifiable, Hashable, Sendable {
    public let id: AudioDeviceID
    public let name: String
    public let isInput: Bool
    public let isOutput: Bool
    public let transportType: String

    public init(id: AudioDeviceID, name: String, isInput: Bool, isOutput: Bool, transportType: String = "Built-in") {
        self.id = id
        self.name = name
        self.isInput = isInput
        self.isOutput = isOutput
        self.transportType = transportType
    }
}

public struct RunningAudioAppItem: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let icon: NSImage?
    public let pid: pid_t
    public var volume: Float
    public var isMuted: Bool
    public let isScriptable: Bool
    public let routingDescription: String

    public init(
        id: String,
        name: String,
        icon: NSImage? = nil,
        pid: pid_t,
        volume: Float = 1.0,
        isMuted: Bool = false,
        isScriptable: Bool = false,
        routingDescription: String = "Default Output"
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.pid = pid
        self.volume = volume
        self.isMuted = isMuted
        self.isScriptable = isScriptable
        self.routingDescription = routingDescription
    }
}

@MainActor
public final class AudioDeviceService: ObservableObject {
    public static let shared = AudioDeviceService()

    @Published public private(set) var outputDevices: [AudioDeviceItem] = []
    @Published public private(set) var inputDevices: [AudioDeviceItem] = []
    @Published public private(set) var defaultOutputDeviceID: AudioDeviceID = 0
    @Published public private(set) var defaultInputDeviceID: AudioDeviceID = 0
    @Published public var outputVolume: Float = 0.5
    @Published public var isOutputMuted: Bool = false
    @Published public var inputLevel: Float = 0.5
    @Published public var isInputMuted: Bool = false
    @Published public var systemAlertVolume: Float = 0.7
    @Published public private(set) var runningAudioApps: [RunningAudioAppItem] = []

    private var isUpdatingInternally: Bool = false

    public init() {
        refreshAll()
        setupListeners()
    }

    // MARK: - Refresh All Telemetry
    public func refreshAll() {
        refreshDevices()
        refreshVolume()
        refreshRunningApps()
    }

    // MARK: - Query Audio Devices
    public func refreshDevices() {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size) == 0 else { return }

        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var devIDs = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &devIDs) == 0 else { return }

        var outs: [AudioDeviceItem] = []
        var ins: [AudioDeviceItem] = []

        for id in devIDs {
            var nameAddr = AudioObjectPropertyAddress(
                mSelector: kAudioObjectPropertyName,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var cfName: CFString? = nil
            var nameSize = UInt32(MemoryLayout<CFString?>.size)
            var devName = "Audio Device \(id)"
            let status = withUnsafeMutablePointer(to: &cfName) { ptr in
                AudioObjectGetPropertyData(id, &nameAddr, 0, nil, &nameSize, ptr)
            }
            if status == 0, let str = cfName as String? {
                devName = str
            }

            var streamAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            var streamSize: UInt32 = 0
            let isOut = (AudioObjectGetPropertyDataSize(id, &streamAddr, 0, nil, &streamSize) == 0 && streamSize > 0)

            streamAddr.mScope = kAudioObjectPropertyScopeInput
            streamSize = 0
            let isIn = (AudioObjectGetPropertyDataSize(id, &streamAddr, 0, nil, &streamSize) == 0 && streamSize > 0)

            let item = AudioDeviceItem(id: id, name: devName, isInput: isIn, isOutput: isOut)
            if isOut { outs.append(item) }
            if isIn { ins.append(item) }
        }

        self.outputDevices = outs
        self.inputDevices = ins

        // Current Default Output Device
        var defOutAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var defOutID: AudioDeviceID = 0
        var devSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        if AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &defOutAddr, 0, nil, &devSize, &defOutID) == 0 {
            self.defaultOutputDeviceID = defOutID
        }

        // Current Default Input Device
        var defInAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var defInID: AudioDeviceID = 0
        devSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        if AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &defInAddr, 0, nil, &devSize, &defInID) == 0 {
            self.defaultInputDeviceID = defInID
        }
    }

    // MARK: - Query Volumes
    public func refreshVolume() {
        guard !isUpdatingInternally else { return }

        // Output Volume
        if defaultOutputDeviceID != 0 {
            var vol: Float32 = 0.0
            var volSize = UInt32(MemoryLayout<Float32>.size)
            var found = false

            for element in [kAudioObjectPropertyElementMain, 1, 2] {
                var addr = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyVolumeScalar,
                    mScope: kAudioDevicePropertyScopeOutput,
                    mElement: element
                )
                if AudioObjectHasProperty(defaultOutputDeviceID, &addr) {
                    if AudioObjectGetPropertyData(defaultOutputDeviceID, &addr, 0, nil, &volSize, &vol) == 0 {
                        self.outputVolume = max(0.0, min(1.0, vol))
                        found = true
                        break
                    }
                }
            }

            if !found {
                // Keep current or sensible default
            }

            // Output Mute
            var mute: UInt32 = 0
            var muteSize = UInt32(MemoryLayout<UInt32>.size)
            var muteAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            if AudioObjectHasProperty(defaultOutputDeviceID, &muteAddr) {
                if AudioObjectGetPropertyData(defaultOutputDeviceID, &muteAddr, 0, nil, &muteSize, &mute) == 0 {
                    self.isOutputMuted = (mute != 0)
                }
            }
        }

        // Input Volume / Gain
        if defaultInputDeviceID != 0 {
            var vol: Float32 = 0.0
            var volSize = UInt32(MemoryLayout<Float32>.size)
            for element in [kAudioObjectPropertyElementMain, 1, 2] {
                var addr = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyVolumeScalar,
                    mScope: kAudioObjectPropertyScopeInput,
                    mElement: element
                )
                if AudioObjectHasProperty(defaultInputDeviceID, &addr) {
                    if AudioObjectGetPropertyData(defaultInputDeviceID, &addr, 0, nil, &volSize, &vol) == 0 {
                        self.inputLevel = max(0.0, min(1.0, vol))
                        break
                    }
                }
            }

            // Input Mute
            var mute: UInt32 = 0
            var muteSize = UInt32(MemoryLayout<UInt32>.size)
            var muteAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            if AudioObjectHasProperty(defaultInputDeviceID, &muteAddr) {
                if AudioObjectGetPropertyData(defaultInputDeviceID, &muteAddr, 0, nil, &muteSize, &mute) == 0 {
                    self.isInputMuted = (mute != 0)
                }
            }
        }
    }

    // MARK: - Adjust Output Volume
    public func setOutputVolume(_ newVolume: Float) {
        guard defaultOutputDeviceID != 0 else { return }
        isUpdatingInternally = true
        defer { isUpdatingInternally = false }

        self.outputVolume = max(0.0, min(1.0, newVolume))
        var vol = self.outputVolume
        let volSize = UInt32(MemoryLayout<Float32>.size)

        for element in [kAudioObjectPropertyElementMain, 1, 2] {
            var addr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: element
            )
            if AudioObjectHasProperty(defaultOutputDeviceID, &addr) {
                _ = AudioObjectSetPropertyData(defaultOutputDeviceID, &addr, 0, nil, volSize, &vol)
            }
        }

        // If unmuted and volume > 0, ensure unmuted
        if vol > 0.0 && isOutputMuted {
            setOutputMute(false)
        }
    }

    public func setOutputMute(_ muted: Bool) {
        guard defaultOutputDeviceID != 0 else { return }
        self.isOutputMuted = muted
        var val: UInt32 = muted ? 1 : 0
        let valSize = UInt32(MemoryLayout<UInt32>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectHasProperty(defaultOutputDeviceID, &addr) {
            _ = AudioObjectSetPropertyData(defaultOutputDeviceID, &addr, 0, nil, valSize, &val)
        }
    }

    // MARK: - Adjust Input Volume
    public func setInputVolume(_ newVolume: Float) {
        guard defaultInputDeviceID != 0 else { return }
        self.inputLevel = max(0.0, min(1.0, newVolume))
        var vol = self.inputLevel
        let volSize = UInt32(MemoryLayout<Float32>.size)

        for element in [kAudioObjectPropertyElementMain, 1, 2] {
            var addr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioObjectPropertyScopeInput,
                mElement: element
            )
            if AudioObjectHasProperty(defaultInputDeviceID, &addr) {
                _ = AudioObjectSetPropertyData(defaultInputDeviceID, &addr, 0, nil, volSize, &vol)
            }
        }
    }

    public func setInputMute(_ muted: Bool) {
        guard defaultInputDeviceID != 0 else { return }
        self.isInputMuted = muted
        var val: UInt32 = muted ? 1 : 0
        let valSize = UInt32(MemoryLayout<UInt32>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectHasProperty(defaultInputDeviceID, &addr) {
            _ = AudioObjectSetPropertyData(defaultInputDeviceID, &addr, 0, nil, valSize, &val)
        }
    }

    // MARK: - Change Devices
    public func setDefaultOutputDevice(id: AudioDeviceID) {
        var devID = id
        let size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, size, &devID)
        if status == 0 {
            self.defaultOutputDeviceID = id
            refreshVolume()
        }
    }

    public func setDefaultInputDevice(id: AudioDeviceID) {
        var devID = id
        let size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, size, &devID)
        if status == 0 {
            self.defaultInputDeviceID = id
            refreshVolume()
        }
    }

    // MARK: - Running Audio Applications
    public func refreshRunningApps() {
        let running = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        var audioApps: [RunningAudioAppItem] = []

        let defaultDevName = outputDevices.first(where: { $0.id == defaultOutputDeviceID })?.name ?? "System Output"

        let targetBundleIDs: Set<String> = [
            "com.apple.Music",
            "com.spotify.client",
            "com.apple.QuickTimePlayerX",
            "com.apple.Safari",
            "com.google.Chrome",
            "company.thebrowser.Browser",
            "org.mozilla.firefox",
            "com.tinyspeck.slackmacgap",
            "us.zoom.xos",
            "com.hnc.Discord",
            "org.videolan.vlc",
            "com.colliderli.iina",
            "com.apple.podcasts",
            "com.apple.tv"
        ]

        for app in running {
            guard let bid = app.bundleIdentifier else { continue }
            let name = app.localizedName ?? bid
            let isTargeted = targetBundleIDs.contains(bid) || (app.isActive && app.bundleIdentifier != Bundle.main.bundleIdentifier)

            if isTargeted {
                let isScriptable = (bid == "com.apple.Music" || bid == "com.spotify.client")
                let item = RunningAudioAppItem(
                    id: bid,
                    name: name,
                    icon: app.icon,
                    pid: app.processIdentifier,
                    volume: self.outputVolume,
                    isMuted: false,
                    isScriptable: isScriptable,
                    routingDescription: defaultDevName
                )
                audioApps.append(item)
            }
        }

        // Sort: active/media first
        audioApps.sort { $0.isScriptable && !$1.isScriptable }
        self.runningAudioApps = audioApps
    }

    // MARK: - CoreAudio Event Listeners
    private func setupListeners() {
        var outAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &outAddr, DispatchQueue.main) { [weak self] _, _ in
            Task { @MainActor in
                self?.refreshDevices()
                self?.refreshVolume()
            }
        }

        var inAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &inAddr, DispatchQueue.main) { [weak self] _, _ in
            Task { @MainActor in
                self?.refreshDevices()
                self?.refreshVolume()
            }
        }
    }
}
