//
//  SystemCleanerView.swift
//  Borno Pulse
//
//  Advanced System Cleaner & Node.js Project Cleanup Interface
//  Inspired by CleanMyMac and CCleaner.
//

import SwiftUI
import AppKit

public struct SystemCleanerView: View {
    @ObservedObject var systemService = SystemCleanerService.shared
    @ObservedObject var nodeService = NodeModulesScannerService.shared
    
    public enum CleanerTab: String, CaseIterable, Identifiable {
        case systemCaches = "System & Developer Caches"
        case nodeModules = "Node.js Project Cleanup"
        
        public var id: String { rawValue }
        
        public var icon: String {
            switch self {
            case .systemCaches: return "sparkles"
            case .nodeModules: return "cube.box.fill"
            }
        }
    }
    
    @State private var activeTab: CleanerTab = .systemCaches
    @State private var reviewingCategory: SystemCleanupCategoryItem? = nil
    @State private var reviewingNodeProjects: Bool = false
    @State private var showConfirmSystemAlert: Bool = false
    @State private var showConfirmNodeAlert: Bool = false
    @State private var nodeSearchQuery: String = ""
    @State private var nodeSortBySize: Bool = true
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Adaptive Page Header
            AdaptivePageHeader(
                title: "Advanced System Cleaner",
                subtitle: "Safe disk space recovery, cache purging, and Node.js node_modules project cleanup",
                icon: "sparkles",
                iconColor: AppTheme.electricBlue
            ) {
                // Section Tab Switcher
                HStack(spacing: 4) {
                    ForEach(CleanerTab.allCases) { tab in
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
                VStack(spacing: 18) {
                    // Disk Space Overview Hero Banner
                    diskSpaceOverviewBanner
                    
                    // Main Content
                    switch activeTab {
                    case .systemCaches:
                        systemCachesTabContent
                    case .nodeModules:
                        nodeModulesTabContent
                    }
                }
                .padding(20)
            }
        }
        .background(AppTheme.graphiteCanvas)
        .onAppear {
            systemService.refreshDiskSpace()
            if systemService.categories.allSatisfy({ $0.fileCount == 0 && $0.estimatedSizeBytes == 0 }) {
                systemService.scanAll()
            }
        }
        .sheet(item: $reviewingCategory) { cat in
            inspectCategoryFilesSheet(cat)
        }
        .sheet(isPresented: $reviewingNodeProjects) {
            reviewNodeProjectsSheet
        }
        .alert("Confirm System Cache Purge", isPresented: $showConfirmSystemAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clean Now", role: .destructive) {
                systemService.executeClean(dryRun: false)
            }
            Button("Simulate (Dry Run)") {
                systemService.executeClean(dryRun: true)
            }
        } message: {
            Text("Are you sure you want to clean the selected categories (\(Formatters.bytes(systemService.selectedReclaimableBytes)))? Non-critical app caches will be deleted. Applications will automatically recreate required caches on launch.")
        }
        .alert("Confirm node_modules Deletion", isPresented: $showConfirmNodeAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Selected node_modules", role: .destructive) {
                nodeService.deleteSelectedNodeModules()
            }
        } message: {
            let selectedCount = nodeService.discoveredProjects.filter { $0.isSelected }.count
            let selectedSize = nodeService.discoveredProjects.filter { $0.isSelected }.reduce(0) { $0 + $1.sizeBytes }
            Text("You are about to delete \(selectedCount) node_modules directories (\(Formatters.bytes(selectedSize))).\n\n⚠️ Important: Project source code, package.json, and lockfiles are strictly preserved. To run your projects again, run 'npm install' or your package manager inside the project directory.")
        }
    }
    
    // MARK: - Disk Space Overview Banner
    private var diskSpaceOverviewBanner: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Macintosh HD Storage")
                        .font(AppTypography.font(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("\(Formatters.bytes(systemService.diskSpace.usedBytes)) Used • \(Formatters.bytes(systemService.diskSpace.availableBytes)) Available of \(Formatters.bytes(systemService.diskSpace.totalCapacityBytes))")
                        .font(AppTypography.font(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                Spacer()
                
                HStack(spacing: 18) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Potentially Reclaimable")
                            .font(AppTypography.font(size: 10))
                            .foregroundStyle(AppTheme.textTertiary)
                        Text(Formatters.bytes(systemService.totalReclaimableBytes))
                            .font(AppTypography.font(size: 15, weight: .bold))
                            .foregroundStyle(AppTheme.electricCyan)
                    }
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Selected for Clean")
                            .font(AppTypography.font(size: 10))
                            .foregroundStyle(AppTheme.textTertiary)
                        Text(Formatters.bytes(systemService.selectedReclaimableBytes))
                            .font(AppTypography.font(size: 16, weight: .bold))
                            .foregroundStyle(AppTheme.successGreen)
                    }
                }
            }
            
            // Storage Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppTheme.cardBorder)
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppTheme.electricBlue)
                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(systemService.diskSpace.usedPercentage))), height: 8)
                }
            }
            .frame(height: 8)
        }
        .smartCard(padding: 14)
    }
    
    // MARK: - 1. System Caches Tab Content
    private var systemCachesTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Mode Selector Bar
            HStack(spacing: 12) {
                Text("Cleanup Mode:")
                    .font(AppTypography.font(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                
                ForEach(CleanerMode.allCases) { mode in
                    Button {
                        systemService.applyModeSelection(mode: mode)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 10))
                            Text(mode.rawValue)
                                .font(AppTypography.font(size: 11, weight: systemService.selectedMode == mode ? .bold : .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(systemService.selectedMode == mode ? AppTheme.accentFill : AppTheme.cardBackgroundSecondary)
                        .foregroundStyle(systemService.selectedMode == mode ? Color.white : AppTheme.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                // Scan / Clean Action Buttons
                if systemService.isScanning {
                    Button("Cancel Scan") {
                        systemService.cancelScan()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    Button {
                        systemService.scanAll()
                    } label: {
                        Label("Re-Scan System", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                Button {
                    showConfirmSystemAlert = true
                } label: {
                    Label("Clean Selected (\(Formatters.bytes(systemService.selectedReclaimableBytes)))", systemImage: "trash.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accentFill)
                .controlSize(.small)
                .disabled(systemService.selectedReclaimableBytes == 0 || systemService.isCleaning)
            }
            
            // Progress or Action Text
            if systemService.isScanning || systemService.isCleaning {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: systemService.isScanning ? systemService.scanProgress : systemService.cleanProgress)
                        .progressViewStyle(.linear)
                    Text(systemService.currentActionText)
                        .font(AppTypography.font(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(10)
                .smartCard(padding: 10)
            }
            
            // Categories List
            VStack(spacing: 10) {
                ForEach(systemService.categories) { cat in
                    systemCategoryCard(cat)
                }
            }
        }
    }
    
    private func systemCategoryCard(_ cat: SystemCleanupCategoryItem) -> some View {
        ViewThatFits(in: .horizontal) {
            // Wide layout
            HStack(alignment: .center, spacing: 14) {
                Toggle("", isOn: Binding(
                    get: { cat.isSelected },
                    set: { _ in systemService.toggleCategory(id: cat.id) }
                ))
                .labelsHidden()
                
                Image(systemName: cat.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(cat.safety.badgeColor)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(cat.name)
                            .font(AppTypography.font(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        
                        Text(cat.safety.rawValue)
                            .font(AppTypography.font(size: 10, weight: .semibold))
                            .foregroundStyle(cat.safety.badgeColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(cat.safety.badgeColor.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    
                    Text(cat.reason)
                        .font(AppTypography.font(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(2)
                }
                
                Spacer(minLength: 16)
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Formatters.bytes(cat.estimatedSizeBytes))
                        .font(AppTypography.font(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("\(cat.fileCount) items")
                        .font(AppTypography.font(size: 10))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                
                Button("Inspect") {
                    reviewingCategory = cat
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            // Compact layout
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Toggle("", isOn: Binding(
                        get: { cat.isSelected },
                        set: { _ in systemService.toggleCategory(id: cat.id) }
                    ))
                    .labelsHidden()
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(cat.name)
                            .font(AppTypography.font(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(cat.reason)
                            .font(AppTypography.font(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                
                HStack {
                    Text(cat.safety.rawValue)
                        .font(AppTypography.font(size: 10, weight: .semibold))
                        .foregroundStyle(cat.safety.badgeColor)
                    
                    Spacer()
                    
                    Text("\(Formatters.bytes(cat.estimatedSizeBytes)) (\(cat.fileCount) items)")
                        .font(AppTypography.font(size: 12, weight: .semibold))
                    
                    Button("Inspect") {
                        reviewingCategory = cat
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .smartCard(padding: 12)
    }
    
    // MARK: - 2. Node.js Project Cleanup Tab
    private var nodeModulesTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Node Scanner Header Controls
            HStack(spacing: 12) {
                Button {
                    nodeService.startScan()
                } label: {
                    Label(nodeService.isScanning ? "Scanning..." : "Scan for Projects", systemImage: "magnifyingglass")
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accentFill)
                .controlSize(.small)
                .disabled(nodeService.isScanning)
                
                if nodeService.isScanning {
                    Button("Cancel") {
                        nodeService.cancelScan()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                Button {
                    selectCustomFolder()
                } label: {
                    Label("Add Folder...", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
                
                if !nodeService.discoveredProjects.isEmpty {
                    Button("Select All") {
                        nodeService.selectAll()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button("Deselect All") {
                        nodeService.deselectAll()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    let selCount = nodeService.discoveredProjects.filter { $0.isSelected }.count
                    let selSize = nodeService.discoveredProjects.filter { $0.isSelected }.reduce(0) { $0 + $1.sizeBytes }
                    
                    Button {
                        reviewingNodeProjects = true
                    } label: {
                        Label("Review & Delete (\(Formatters.bytes(selSize)))", systemImage: "trash.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.dangerFill)
                    .controlSize(.small)
                    .disabled(selCount == 0 || nodeService.isCleaning)
                }
            }
            
            // Scan progress text
            if nodeService.isScanning || nodeService.isCleaning {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: nodeService.isScanning ? nodeService.scanProgress : nodeService.cleanProgress)
                        .progressViewStyle(.linear)
                    Text(nodeService.currentStatusText)
                        .font(AppTypography.font(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(10)
                .smartCard(padding: 10)
            }
            
            // Search & Filter Bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppTheme.textTertiary)
                TextField("Filter projects by name or path...", text: $nodeSearchQuery)
                    .textFieldStyle(.plain)
                    .font(AppTypography.font(size: 12))
                
                if !nodeSearchQuery.isEmpty {
                    Button {
                        nodeSearchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .themedInputField()
            
            // Discovered Projects List
            let filtered = nodeService.discoveredProjects.filter {
                nodeSearchQuery.isEmpty ||
                $0.projectName.localizedCaseInsensitiveContains(nodeSearchQuery) ||
                $0.projectPath.localizedCaseInsensitiveContains(nodeSearchQuery)
            }
            
            if filtered.isEmpty && !nodeService.isScanning {
                VStack(spacing: 10) {
                    Image(systemName: "cube.box")
                        .font(.system(size: 36))
                        .foregroundStyle(AppTheme.textTertiary)
                    Text("No node_modules directories found.")
                        .font(AppTypography.font(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Click 'Scan for Projects' or 'Add Folder...' to locate Node.js projects on your Mac.")
                        .font(AppTypography.font(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
                .smartCard(padding: 24)
            } else {
                VStack(spacing: 8) {
                    ForEach(filtered) { project in
                        nodeProjectCard(project)
                    }
                }
            }
        }
    }
    
    private func nodeProjectCard(_ project: NodeProjectItem) -> some View {
        ViewThatFits(in: .horizontal) {
            // Wide project card
            HStack(alignment: .center, spacing: 14) {
                Toggle("", isOn: Binding(
                    get: { project.isSelected },
                    set: { _ in nodeService.toggleSelection(nodeModulesPath: project.nodeModulesPath) }
                ))
                .labelsHidden()
                
                Image(systemName: project.packageManager.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(AppTheme.electricCyan)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(project.projectName)
                            .font(AppTypography.font(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        
                        Text(project.packageManager.rawValue)
                            .font(AppTypography.font(size: 9.5, weight: .semibold))
                            .foregroundStyle(AppTheme.electricCyan)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.electricCyan.opacity(0.12))
                            .clipShape(Capsule())
                        
                        if project.isGitRepo {
                            Text("Git")
                                .font(AppTypography.font(size: 9.5, weight: .semibold))
                                .foregroundStyle(AppTheme.purpleAccent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.purpleAccent.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        
                        if project.isMonorepo {
                            Text("Monorepo")
                                .font(AppTypography.font(size: 9.5, weight: .semibold))
                                .foregroundStyle(AppTheme.warningAmber)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.warningAmber.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        
                        if project.isActivelyUsed {
                            Text("Active Recently")
                                .font(AppTypography.font(size: 9.5, weight: .semibold))
                                .foregroundStyle(AppTheme.orangeAccent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.orangeAccent.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text(project.projectPath)
                        .font(AppTypography.font(size: 10, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 16)
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Formatters.bytes(project.sizeBytes))
                        .font(AppTypography.font(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("\(project.fileCount) files")
                        .font(AppTypography.font(size: 10))
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }
            
            // Compact layout
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Toggle("", isOn: Binding(
                        get: { project.isSelected },
                        set: { _ in nodeService.toggleSelection(nodeModulesPath: project.nodeModulesPath) }
                    ))
                    .labelsHidden()
                    
                    Text(project.projectName)
                        .font(AppTypography.font(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    Spacer()
                    
                    Text(Formatters.bytes(project.sizeBytes))
                        .font(AppTypography.font(size: 13, weight: .bold))
                }
                
                Text(project.projectPath)
                    .font(AppTypography.font(size: 10, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .smartCard(padding: 12)
    }
    
    // MARK: - Review Node Projects Sheet
    private var reviewNodeProjectsSheet: some View {
        let selectedProjects = nodeService.discoveredProjects.filter { $0.isSelected }
        let totalBytes = selectedProjects.reduce(0) { $0 + $1.sizeBytes }
        
        return VStack(spacing: 0) {
            HStack {
                Text("Review node_modules Cleanup")
                    .font(AppTypography.font(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Button {
                    reviewingNodeProjects = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(AppTheme.toolbarBackground)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(AppTheme.warningAmber)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Reinstall Requirement Notice")
                            .font(AppTypography.font(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Deleting node_modules recovers significant disk space. To run or build these projects later, simply run the project's install command:")
                            .font(AppTypography.font(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .smartCard(padding: 12)
                
                Text("\(selectedProjects.count) Projects Selected • \(Formatters.bytes(totalBytes)) Total Space to Reclaim")
                    .font(AppTypography.font(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                
                List(selectedProjects) { p in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.projectName)
                                .font(AppTypography.font(size: 12, weight: .bold))
                            Text(p.projectPath)
                                .font(AppTypography.font(size: 10, design: .monospaced))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(Formatters.bytes(p.sizeBytes))
                                .font(AppTypography.font(size: 12, weight: .semibold))
                            Text("Reinstall: \(p.packageManager.reinstallCommand)")
                                .font(AppTypography.font(size: 9.5, design: .monospaced))
                                .foregroundStyle(AppTheme.electricCyan)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                HStack {
                    Button("Cancel") {
                        reviewingNodeProjects = false
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button {
                        reviewingNodeProjects = false
                        showConfirmNodeAlert = true
                    } label: {
                        Label("Proceed with Deletion", systemImage: "trash.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.dangerFill)
                }
            }
            .padding(18)
        }
        .frame(width: 620, height: 500)
    }
    
    // MARK: - Inspect Category Files Sheet
    private func inspectCategoryFilesSheet(_ cat: SystemCleanupCategoryItem) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(cat.name)
                    .font(AppTypography.font(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Button {
                    reviewingCategory = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(AppTheme.toolbarBackground)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                Text(cat.reason)
                    .font(AppTypography.font(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
                
                Text("\(cat.fileCount) Files Found • \(Formatters.bytes(cat.estimatedSizeBytes)) Total")
                    .font(AppTypography.font(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                
                List(cat.files) { f in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(f.name)
                                .font(AppTypography.font(size: 11, weight: .medium))
                            Text(f.path)
                                .font(AppTypography.font(size: 9.5, design: .monospaced))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                        Spacer()
                        Text(Formatters.bytes(f.sizeBytes))
                            .font(AppTypography.font(size: 11, design: .monospaced))
                    }
                }
            }
            .padding(16)
        }
        .frame(width: 580, height: 440)
    }
    
    private func selectCustomFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Scan Folder"
        panel.message = "Choose a workspace directory to scan for Node.js projects"
        
        if panel.runModal() == .OK, let url = panel.url {
            nodeService.addCustomScanRoot(url)
            nodeService.startScan()
        }
    }
}
