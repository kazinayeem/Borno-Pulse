//
//  LocalBackupHelperView.swift
//  Borno Pulse
//

import AppKit
import SwiftUI

public struct LocalBackupHelperView: View {
    @StateObject private var backupService = BackupEngineService.shared
    @State private var selectedTab: Int = 0 // 0: Profiles & Runs, 1: Restore & Inspect
    @State private var editingProfile: BackupProfile? = nil
    @State private var showingNewProfileSheet: Bool = false
    @State private var showingReportSheet: Bool = false
    
    // Restore states
    @State private var restoreSourceFolder: String = ""
    @State private var restoreItems: [URL] = []
    @State private var restoreStatusMessage: String = ""
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                headerView
                
                // Segmented picker
                Picker("", selection: $selectedTab) {
                    Text("Backup Profiles").tag(0)
                    Text("Restore & Inspect").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)
                
                if selectedTab == 0 {
                    profilesTab
                } else {
                    restoreTab
                }
            }
            .padding(24)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(item: $editingProfile) { profile in
            ProfileEditorSheet(profile: profile) { updated in
                backupService.saveProfile(updated)
                editingProfile = nil
            } onCancel: {
                editingProfile = nil
            }
        }
        .sheet(isPresented: $showingNewProfileSheet) {
            ProfileEditorSheet(profile: BackupProfile(name: "New Profile")) { newProfile in
                backupService.saveProfile(newProfile)
                showingNewProfileSheet = false
            } onCancel: {
                showingNewProfileSheet = false
            }
        }
        .sheet(isPresented: $showingReportSheet) {
            if let report = backupService.latestReport {
                BackupReportSheet(report: report) {
                    showingReportSheet = false
                }
            }
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "externaldrive.badge.timemachine")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                    Text("Local Backup Helper")
                        .font(.title.bold())
                }
                Text("Private, verifiable local and external folder backups with incremental sync and SHA-256 verification.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button {
                showingNewProfileSheet = true
            } label: {
                Label("New Profile", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(backupService.isRunning)
        }
    }
    
    // MARK: - Profiles Tab
    private var profilesTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Live run banner
            if backupService.isRunning {
                liveProgressBanner
            } else if let report = backupService.latestReport {
                latestReportBanner(report)
            }
            
            if backupService.profiles.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.gearshape")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No Backup Profiles Configured")
                        .font(.headline)
                    Text("Create a profile to periodically back up your important projects, documents, or media to local or external drives.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                    Button("Create First Profile") {
                        showingNewProfileSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(backupService.profiles) { profile in
                    profileCard(profile)
                }
            }
        }
    }
    
    // MARK: - Live Progress Banner
    private var liveProgressBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ProgressView()
                    .controlSize(.small)
                Text(backupService.currentStatusMessage)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Spacer()
                Button("Cancel Backup") {
                    backupService.cancel()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            ProgressView(value: backupService.currentProgress, total: 1.0)
                .progressViewStyle(.linear)
        }
        .padding(16)
        .background(Color.accentColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor.opacity(0.3), lineWidth: 1))
    }
    
    // MARK: - Latest Report Banner
    private func latestReportBanner(_ report: BackupRunReport) -> some View {
        HStack {
            Image(systemName: report.verificationPassed ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                .font(.title3)
                .foregroundStyle(report.verificationPassed ? .green : .orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Last Backup: \(report.profileName)")
                    .font(.subheadline.bold())
                Text("Copied \(report.filesCopied) files (\(Formatters.bytes(UInt64(report.totalBytesCopied)))) • \(String(format: "%.1f", report.durationSeconds))s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button("View Report") {
                showingReportSheet = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 1))
    }
    
    // MARK: - Profile Card
    private func profileCard(_ profile: BackupProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(profile.name)
                            .font(.headline)
                        
                        Text(profile.mode.rawValue)
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                        
                        if profile.verifyChecksums {
                            HStack(spacing: 3) {
                                Image(systemName: "checkmark.shield")
                                Text("SHA-256")
                            }
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                        }
                    }
                    
                    if let status = profile.lastStatus, let date = profile.lastRunDate {
                        Text("Last run: \(date.formatted(date: .abbreviated, time: .shortened)) (\(status))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Never run")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button {
                        editingProfile = profile
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                    .help("Edit profile")
                    
                    Button {
                        backupService.deleteProfile(id: profile.id)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.borderless)
                    .help("Delete profile")
                    
                    Button {
                        Task {
                            _ = await backupService.runBackup(profile: profile)
                            showingReportSheet = true
                        }
                    } label: {
                        Label("Run Backup", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(backupService.isRunning)
                }
            }
            
            Divider()
            
            // Paths overview
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 8) {
                    Text("Sources:")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(profile.sourcePaths, id: \.self) { path in
                            Text(path)
                                .font(.caption.monospaced())
                                .lineLimit(1)
                        }
                    }
                }
                
                HStack(alignment: .top, spacing: 8) {
                    Text("Destination:")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .leading)
                    Text(profile.destinationPath)
                        .font(.caption.monospaced())
                        .lineLimit(1)
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.15), lineWidth: 1))
    }
    
    // MARK: - Restore Tab
    private var restoreTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Restore Backup Safely")
                    .font(.headline)
                Text("Select an existing Smart Tool backup folder to inspect its backed-up contents and restore files safely to any target directory without accidental overwriting.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack {
                    Button("Select Backup Folder...") {
                        selectRestoreSource()
                    }
                    .buttonStyle(.bordered)
                    
                    if !restoreSourceFolder.isEmpty {
                        Text(restoreSourceFolder)
                            .font(.caption.monospaced())
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Button("Restore to Folder...") {
                            performRestore()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(restoreItems.isEmpty)
                    }
                }
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            if !restoreStatusMessage.isEmpty {
                Text(restoreStatusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
            
            if !restoreItems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Discovered Items (\(restoreItems.count)):")
                        .font(.subheadline.bold())
                    
                    List(restoreItems, id: \.self) { item in
                        HStack {
                            Image(systemName: "doc")
                                .foregroundStyle(.secondary)
                            Text(item.lastPathComponent)
                                .font(.caption)
                            Spacer()
                            if let attrs = try? FileManager.default.attributesOfItem(atPath: item.path),
                               let size = attrs[.size] as? UInt64 {
                                Text(Formatters.bytes(size))
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
    
    private func selectRestoreSource() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            restoreSourceFolder = url.path
            loadRestoreItems(from: url)
        }
    }
    
    private func loadRestoreItems(from url: URL) {
        let fm = FileManager.default
        if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
            var files: [URL] = []
            for case let fileURL as URL in enumerator {
                files.append(fileURL)
            }
            restoreItems = files
            restoreStatusMessage = "Loaded \(files.count) files ready for restore."
        }
    }
    
    private func performRestore() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.prompt = "Select Restore Destination"
        guard panel.runModal() == .OK, let destURL = panel.url else { return }
        
        let srcURL = URL(fileURLWithPath: restoreSourceFolder)
        let fm = FileManager.default
        var restoredCount = 0
        
        for file in restoreItems {
            let rel = file.path.replacingOccurrences(of: srcURL.path, with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let targetURL = destURL.appendingPathComponent(rel)
            let targetDir = targetURL.deletingLastPathComponent()
            try? fm.createDirectory(at: targetDir, withIntermediateDirectories: true)
            
            // Non-destructive: if exists, append _restored
            var finalTarget = targetURL
            if fm.fileExists(atPath: targetURL.path) {
                let name = targetURL.deletingPathExtension().lastPathComponent
                let ext = targetURL.pathExtension
                finalTarget = targetDir.appendingPathComponent("\(name)_restored.\(ext)")
            }
            
            do {
                try fm.copyItem(at: file, to: finalTarget)
                restoredCount += 1
            } catch {}
        }
        
        restoreStatusMessage = "Successfully restored \(restoredCount) files to \(destURL.path)."
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: destURL.path)
    }
}

// MARK: - Profile Editor Sheet
private struct ProfileEditorSheet: View {
    @State var profile: BackupProfile
    let onSave: (BackupProfile) -> Void
    let onCancel: () -> Void
    
    @State private var newExclusion: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(profile.sourcePaths.isEmpty ? "New Backup Profile" : "Edit Backup Profile")
                .font(.headline)
            
            Form {
                TextField("Profile Name:", text: $profile.name)
                
                Picker("Backup Mode:", selection: $profile.mode) {
                    ForEach(BackupMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                
                Text(profile.mode.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Toggle("Verify Checksums (SHA-256):", isOn: $profile.verifyChecksums)
                
                Divider()
                
                // Sources
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Source Folders:")
                            .font(.subheadline.bold())
                        Spacer()
                        Button("+ Add Source Folder") {
                            addSourceFolder()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    ForEach(profile.sourcePaths, id: \.self) { path in
                        HStack {
                            Text(path)
                                .font(.caption.monospaced())
                                .lineLimit(1)
                            Spacer()
                            Button {
                                profile.sourcePaths.removeAll { $0 == path }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                
                Divider()
                
                // Destination
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Destination Folder:")
                            .font(.subheadline.bold())
                        Spacer()
                        Button("Choose Destination...") {
                            chooseDestination()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    Text(profile.destinationPath.isEmpty ? "No destination selected" : profile.destinationPath)
                        .font(.caption.monospaced())
                        .foregroundStyle(profile.destinationPath.isEmpty ? .secondary : .primary)
                }
            }
            
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Save Profile") {
                    onSave(profile)
                }
                .buttonStyle(.borderedProminent)
                .disabled(profile.name.isEmpty || profile.sourcePaths.isEmpty || profile.destinationPath.isEmpty)
            }
            .padding(.top, 8)
        }
        .padding(20)
        .frame(width: 520)
    }
    
    private func addSourceFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            for url in panel.urls {
                if !profile.sourcePaths.contains(url.path) {
                    profile.sourcePaths.append(url.path)
                }
            }
        }
    }
    
    private func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            profile.destinationPath = url.path
        }
    }
}

// MARK: - Backup Report Sheet
private struct BackupReportSheet: View {
    let report: BackupRunReport
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: report.verificationPassed ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.title)
                    .foregroundStyle(report.verificationPassed ? .green : .orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Backup Summary")
                        .font(.headline)
                    Text(report.profileName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button("Done") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
            }
            
            Divider()
            
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Date:")
                        .foregroundStyle(.secondary)
                    Text(report.date.formatted(date: .abbreviated, time: .standard))
                }
                GridRow {
                    Text("Mode:")
                        .foregroundStyle(.secondary)
                    Text(report.mode.rawValue)
                }
                GridRow {
                    Text("Files Considered:")
                        .foregroundStyle(.secondary)
                    Text("\(report.filesConsidered)")
                }
                GridRow {
                    Text("Files Copied:")
                        .foregroundStyle(.secondary)
                    Text("\(report.filesCopied)")
                }
                GridRow {
                    Text("Files Skipped (Unchanged):")
                        .foregroundStyle(.secondary)
                    Text("\(report.filesSkipped)")
                }
                GridRow {
                    Text("Files Failed:")
                        .foregroundStyle(.secondary)
                    Text("\(report.filesFailed)")
                        .foregroundStyle(report.filesFailed > 0 ? .red : .primary)
                }
                GridRow {
                    Text("Total Bytes Copied:")
                        .foregroundStyle(.secondary)
                    Text(Formatters.bytes(UInt64(report.totalBytesCopied)))
                }
                GridRow {
                    Text("Elapsed Time:")
                        .foregroundStyle(.secondary)
                    Text("\(String(format: "%.2f", report.durationSeconds))s")
                }
                GridRow {
                    Text("Integrity Verification:")
                        .foregroundStyle(.secondary)
                    Text(report.verificationPassed ? "Passed (SHA-256 match)" : "Mismatch or Skipped")
                        .foregroundStyle(report.verificationPassed ? .green : .orange)
                }
            }
            .font(.caption)
            
            HStack {
                Button("Reveal in Finder") {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: report.destinationPath)
                }
                .buttonStyle(.bordered)
                
                Spacer()
            }
            .padding(.top, 8)
        }
        .padding(20)
        .frame(width: 440)
    }
}
