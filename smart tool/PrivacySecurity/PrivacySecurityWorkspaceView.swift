//
//  PrivacySecurityWorkspaceView.swift
//  Borno Pulse
//

import AppKit
import SwiftUI

public struct PrivacySecurityWorkspaceView: View {
    public enum PrivacyTab: String, CaseIterable, Identifiable {
        case hashing = "File Hasher"
        case metadata = "Metadata Inspector"
        case permissions = "Permission Audit"
        
        public var id: String { rawValue }
        
        public var icon: String {
            switch self {
            case .hashing: return "number.square.fill"
            case .metadata: return "info.circle.fill"
            case .permissions: return "hand.raised.shield.fill"
            }
        }
    }
    
    @State private var activeTab: PrivacyTab = .hashing
    
    // Hash state
    @State private var selectedAlgorithm: HashAlgorithmKind = .sha256
    @State private var hashResults: [FileHashResult] = []
    @State private var isComputingHash: Bool = false
    @State private var manualExpectedHash: String = ""
    
    // Metadata state
    @State private var selectedMetadataURL: URL? = nil
    @State private var metadataAttributes: [(key: String, value: String)] = []
    
    // Permissions state
    @State private var auditItems: [PermissionAuditItem] = []
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Workspace Header
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "shield.lefthalf.filled")
                        .foregroundStyle(AppTheme.matrixGreen)
                    Text("Privacy & Security Workspace")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                
                Spacer()
                
                // Tabs
                HStack(spacing: 4) {
                    ForEach(PrivacyTab.allCases) { tab in
                        Button {
                            activeTab = tab
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 11))
                                Text(tab.rawValue)
                                    .font(.system(size: 12, weight: activeTab == tab ? .semibold : .regular))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(activeTab == tab ? AppTheme.matrixGreen.opacity(0.18) : Color.clear)
                            .foregroundStyle(activeTab == tab ? AppTheme.matrixGreen : AppTheme.textSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.cardBorder, lineWidth: 0.5))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(AppTheme.cardBackgroundSecondary)
            
            Divider()
                .background(AppTheme.cardBorder)
            
            ScrollView {
                VStack(spacing: 16) {
                    switch activeTab {
                    case .hashing:
                        fileHashingTabContent
                    case .metadata:
                        metadataInspectorTabContent
                    case .permissions:
                        permissionAuditTabContent
                    }
                }
                .padding(18)
            }
        }
        .background(AppTheme.graphiteCanvas)
        .onAppear {
            auditItems = PermissionAuditService.shared.performAudit()
        }
    }
    
    // MARK: - 1. File Hashing Tab
    private var fileHashingTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Advisory Card
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(AppTheme.electricCyan)
                    .font(.system(size: 14))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedAlgorithm.rawValue)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(selectedAlgorithm.securityAdvisory)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("⚠️ Notice: A hash match proves data integrity (byte-level equality). It does not guarantee a file is free from malware.")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.warningAmber)
                }
            }
            .padding(12)
            .smartCard()
            
            // Algorithm & Action Bar
            HStack(spacing: 12) {
                Picker("Algorithm", selection: $selectedAlgorithm) {
                    ForEach(HashAlgorithmKind.allCases) { alg in
                        Text(alg.rawValue).tag(alg)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 250)
                
                Button {
                    selectFilesToHash()
                } label: {
                    Label("Select Files to Hash...", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.electricBlue)
                
                Spacer()
                
                if !hashResults.isEmpty {
                    Button("Clear") {
                        hashResults.removeAll()
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            // Expected Hash Comparator Input
            HStack(spacing: 8) {
                Image(systemName: "checkmark.magnifyingglass")
                    .foregroundStyle(AppTheme.textTertiary)
                
                TextField("Paste expected checksum to compare (optional)...", text: $manualExpectedHash)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .onChange(of: manualExpectedHash) { _, newVal in
                        for i in 0..<hashResults.count {
                            hashResults[i].expectedHash = newVal
                        }
                    }
                
                if !manualExpectedHash.isEmpty {
                    Button {
                        manualExpectedHash = ""
                        for i in 0..<hashResults.count {
                            hashResults[i].expectedHash = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.cardBorder, lineWidth: 1))
            
            // Results List
            if hashResults.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "number.square")
                        .font(.system(size: 32))
                        .foregroundStyle(AppTheme.textTertiary)
                    Text("Select a file to stream and compute its cryptographic digest.")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 180)
                .smartCard()
            } else {
                VStack(spacing: 8) {
                    ForEach(hashResults) { res in
                        hashResultCard(res)
                    }
                }
            }
        }
    }
    
    private func hashResultCard(_ res: FileHashResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(res.filename)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                
                Text("• \(Formatters.bytes(UInt64(res.fileSize)))")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textTertiary)
                
                Spacer()
                
                if let match = res.isMatch {
                    HStack(spacing: 4) {
                        Image(systemName: match ? "checkmark.circle.fill" : "xmark.octagon.fill")
                            .foregroundStyle(match ? AppTheme.successGreen : AppTheme.dangerRed)
                        Text(match ? "CHECKSUM MATCH" : "HASH MISMATCH")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(match ? AppTheme.successGreen : AppTheme.dangerRed)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((match ? AppTheme.successGreen : AppTheme.dangerRed).opacity(0.12))
                    .clipShape(Capsule())
                }
                
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(res.computedHashHex, forType: .string)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy")
                    }
                    .font(.system(size: 10))
                }
                .buttonStyle(.bordered)
            }
            
            Text(res.computedHashHex)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(AppTheme.electricCyan)
                .textSelection(.enabled)
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.cardBackgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppTheme.cardBorder, lineWidth: 0.5))
        }
        .padding(12)
        .smartCard()
    }
    
    // MARK: - 2. Metadata Inspector Tab
    private var metadataInspectorTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button("Inspect File Metadata...") {
                    selectFileForMetadata()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.purpleAccent)
                
                Spacer()
                
                if let url = selectedMetadataURL {
                    Text(url.lastPathComponent)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.textPrimary)
                }
            }
            
            if metadataAttributes.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "magnifyingglass.circle")
                        .font(.system(size: 32))
                        .foregroundStyle(AppTheme.textTertiary)
                    Text("Select an image, PDF, or document to inspect and safely scrub embedded metadata.")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 220)
                .smartCard()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Extracted Metadata Attributes")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    VStack(spacing: 4) {
                        ForEach(metadataAttributes, id: \.key) { attr in
                            HStack {
                                Text(attr.key)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .frame(width: 180, alignment: .leading)
                                
                                Text(attr.value)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(AppTheme.textPrimary)
                                
                                Spacer()
                            }
                            .padding(8)
                            .background(AppTheme.cardBackgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppTheme.cardBorder, lineWidth: 0.5))
                        }
                    }
                }
                .padding(14)
                .smartCard()
            }
        }
    }
    
    // MARK: - 3. Permission Audit Tab
    private var permissionAuditTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("macOS System Permissions & Sandbox Audit")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            
            VStack(spacing: 8) {
                ForEach(auditItems) { item in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: item.isGranted ? "checkmark.circle.fill" : "info.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(item.isGranted ? AppTheme.successGreen : AppTheme.warningAmber)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(item.name)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                
                                Text("• \(item.statusText)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(item.isGranted ? AppTheme.successGreen : AppTheme.warningAmber)
                            }
                            
                            Text(item.featureImpact)
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        
                        Spacer()
                        
                        if let sysURL = item.systemSettingsURL, let u = URL(string: sysURL) {
                            Button("System Settings...") {
                                NSWorkspace.shared.open(u)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(12)
                    .smartCard()
                }
            }
        }
    }
    
    // MARK: - Actions
    private func selectFilesToHash() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select Files for Cryptographic Hashing"
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseFiles = true
        
        if openPanel.runModal() == .OK {
            isComputingHash = true
            Task {
                var newResults: [FileHashResult] = []
                for url in openPanel.urls {
                    let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
                    let size = attrs?[.size] as? Int64 ?? 0
                    
                    if let hex = try? FileHashCalculatorService.shared.computeHash(for: url, algorithm: selectedAlgorithm) {
                        newResults.append(FileHashResult(
                            filename: url.lastPathComponent,
                            fileURL: url,
                            fileSize: size,
                            algorithm: selectedAlgorithm,
                            computedHashHex: hex,
                            expectedHash: manualExpectedHash.isEmpty ? nil : manualExpectedHash
                        ))
                    }
                }
                
                await MainActor.run {
                    self.hashResults.append(contentsOf: newResults)
                    self.isComputingHash = false
                }
            }
        }
    }
    
    private func selectFileForMetadata() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select File for Metadata Inspection"
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseFiles = true
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            selectedMetadataURL = url
            var attrs: [(key: String, value: String)] = []
            
            // Standard FS Attributes
            if let fs = try? FileManager.default.attributesOfItem(atPath: url.path) {
                attrs.append(("File Size", Formatters.bytes(UInt64(fs[.size] as? Int64 ?? 0))))
                if let created = fs[.creationDate] as? Date {
                    attrs.append(("Creation Date", created.formatted()))
                }
                if let mod = fs[.modificationDate] as? Date {
                    attrs.append(("Last Modified", mod.formatted()))
                }
                if let posix = fs[.posixPermissions] as? NSNumber {
                    attrs.append(("POSIX Mode", String(format: "%o", posix.intValue)))
                }
            }
            
            // UTI / Content Type
            if let resVals = try? url.resourceValues(forKeys: [.contentTypeKey]),
               let contentType = resVals.contentType {
                attrs.append(("Uniform Type Identifier (UTI)", contentType.identifier))
            }
            
            self.metadataAttributes = attrs
        }
    }
}
