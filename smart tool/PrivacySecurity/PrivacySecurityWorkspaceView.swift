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
            case .permissions: return "shield.lefthalf.filled"
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
            AdaptivePageHeader(
                title: "Privacy & Security",
                subtitle: "Offline verification, hashing, metadata, and permission audit",
                icon: "shield.lefthalf.filled",
                iconColor: AppTheme.matrixGreen
            ) {
                // Segmented tab navigation
                HStack(spacing: 4) {
                    ForEach(PrivacyTab.allCases) { tab in
                        Button {
                            activeTab = tab
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 11))
                                Text(tab.rawValue)
                                    .font(AppTypography.font(size: 11.5, weight: activeTab == tab ? .semibold : .regular))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(activeTab == tab ? AppTheme.selectionBackground : Color.clear)
                            .foregroundStyle(activeTab == tab ? AppTheme.selectionForeground : AppTheme.textSecondary)
                            .contentShape(RoundedRectangle(cornerRadius: 6))
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
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(AppTheme.toolbarBackground)
            
            Divider()
            
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
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
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
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(selectedAlgorithm.rawValue)
                        .font(AppTypography.font(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(selectedAlgorithm.securityAdvisory)
                        .font(AppTypography.font(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("⚠️ Notice: A hash match proves data integrity (byte-level equality). It does not guarantee a file is free from malware.")
                        .font(AppTypography.font(size: 10))
                        .foregroundStyle(AppTheme.warningAmber)
                }
            }
            .smartCard(padding: 12)
            
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
                .tint(AppTheme.accentFill)
                
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
                Image(systemName: "magnifyingglass")
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
            .themedInputField()
            
            // Results List
            if hashResults.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "number.square")
                        .font(.system(size: 32))
                        .foregroundStyle(AppTheme.textTertiary)
                    Text("Select a file to stream and compute its cryptographic digest.")
                        .font(AppTypography.font(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 180)
                .smartCard(padding: 18)
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
                    .font(AppTypography.font(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                
                Text("• \(Formatters.bytes(UInt64(res.fileSize)))")
                    .font(AppTypography.font(size: 11))
                    .foregroundStyle(AppTheme.textTertiary)
                
                Spacer()
                
                if let match = res.isMatch {
                    HStack(spacing: 4) {
                        Image(systemName: match ? "checkmark.circle.fill" : "xmark.octagon.fill")
                            .foregroundStyle(match ? AppTheme.successGreen : AppTheme.dangerRed)
                        Text(match ? "CHECKSUM MATCH" : "HASH MISMATCH")
                            .font(AppTypography.font(size: 9, weight: .bold))
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
                    .font(AppTypography.font(size: 10))
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
        .smartCard(padding: 14)
    }
    
    // MARK: - 2. Metadata Inspector Tab
    private var metadataInspectorTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button("Inspect File Metadata...") {
                    selectFileForMetadata()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.purpleFill)
                
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
                        .font(AppTypography.font(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 220)
                .smartCard(padding: 18)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Extracted Metadata Attributes")
                        .font(AppTypography.font(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    VStack(spacing: 4) {
                        ForEach(metadataAttributes, id: \.key) { attr in
                            HStack {
                                Text(attr.key)
                                    .font(AppTypography.font(size: 11, weight: .medium))
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
                .smartCard(padding: 14)
            }
        }
    }
    
    // MARK: - 3. Permission Audit Tab
    private var permissionAuditTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("macOS System Permissions & Sandbox Audit")
                    .font(AppTypography.font(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Button {
                    auditItems = PermissionAuditService.shared.performAudit()
                } label: {
                    Label("Re-scan Permissions", systemImage: "arrow.clockwise")
                        .font(AppTypography.font(size: 11))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(AppTheme.electricBlue)
            }
            
            VStack(spacing: 10) {
                ForEach(auditItems) { item in
                    permissionAuditCard(item)
                }
            }
        }
    }

    private func permissionAuditCard(_ item: PermissionAuditItem) -> some View {
        ViewThatFits(in: .horizontal) {
            // Wide card layout: Button on the right
            HStack(alignment: .center, spacing: 14) {
                permissionCardLeading(item)
                
                Spacer(minLength: 16)
                
                if let sysURL = item.systemSettingsURL, let u = URL(string: sysURL) {
                    Button("System Settings…") {
                        NSWorkspace.shared.open(u)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .fixedSize(horizontal: true, vertical: false)
                }
            }
            
            // Compact card layout: Button moves to bottom-right
            VStack(alignment: .leading, spacing: 10) {
                permissionCardLeading(item)
                
                if let sysURL = item.systemSettingsURL, let u = URL(string: sysURL) {
                    HStack {
                        Spacer()
                        Button("System Settings…") {
                            NSWorkspace.shared.open(u)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
        .smartCard(padding: 14)
    }

    private func permissionCardLeading(_ item: PermissionAuditItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.isGranted ? "checkmark.circle.fill" : "info.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(item.isGranted ? AppTheme.successGreen : AppTheme.warningAmber)
                .frame(width: 22, height: 22, alignment: .center)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(item.name)
                        .font(AppTypography.font(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    Text(item.statusText)
                        .font(AppTypography.font(size: 10.5, weight: .semibold))
                        .foregroundStyle(item.isGranted ? AppTheme.successGreen : AppTheme.warningAmber)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background((item.isGranted ? AppTheme.successGreen : AppTheme.warningAmber).opacity(0.12))
                        .clipShape(Capsule())
                }
                
                Text(item.featureImpact)
                    .font(AppTypography.font(size: 11.5))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
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
