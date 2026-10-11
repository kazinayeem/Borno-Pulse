//
//  HistoricalStorageService.swift
//  Naem Smart Tool
//

import Combine
import Foundation

@MainActor
public final class HistoricalStorageService: ObservableObject {
    public static let shared = HistoricalStorageService()
    
    private let storageKey = "com.naem.smart-tool.storage-history"
    private let consentKey = "com.naem.smart-tool.storage-history-consent"
    
    @Published public var snapshots: [HistoricalStorageSnapshot] = []
    @Published public var isHistoryCollectionEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isHistoryCollectionEnabled, forKey: consentKey)
        }
    }
    
    public init() {
        self.isHistoryCollectionEnabled = UserDefaults.standard.bool(forKey: consentKey)
        loadSnapshots()
    }
    
    public func loadSnapshots() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let list = try? JSONDecoder().decode([HistoricalStorageSnapshot].self, from: data) else {
            self.snapshots = []
            return
        }
        self.snapshots = list.sorted { $0.timestamp < $1.timestamp }
    }
    
    public func recordSnapshot(
        volumeName: String,
        totalCapacity: UInt64,
        usedCapacity: UInt64,
        scannedBytes: UInt64,
        scannedFileCount: Int
    ) {
        guard isHistoryCollectionEnabled else { return }
        
        let newSnapshot = HistoricalStorageSnapshot(
            timestamp: Date(),
            volumeName: volumeName,
            totalCapacityBytes: totalCapacity,
            usedCapacityBytes: usedCapacity,
            scannedBytes: scannedBytes,
            scannedFileCount: scannedFileCount
        )
        
        var list = snapshots
        list.append(newSnapshot)
        
        // Keep maximum 60 historical points to preserve lightweight footprint
        if list.count > 60 {
            list.removeFirst(list.count - 60)
        }
        
        if let encoded = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
            self.snapshots = list
        }
    }
    
    public func clearHistory() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        self.snapshots = []
    }
}
