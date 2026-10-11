//
//  CacheCleanerView.swift
//  Borno Pulse
//

import SwiftUI

public struct CacheCleanerView: View {
    @ObservedObject var service = CacheCleanupService.shared
    @State private var reviewingCategory: CleanupCategory? = nil
    @State private var showConfirmAlert = false
    @State private var executeDryRun = false
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Banner
                headerBanner
                
                // Safety Advisory Card
                safetyAdvisoryCard
                
                // Control Bar
                controlBar
                
                // Categories List
                categoriesList
                
                // Clean Action Section
                actionSection
            }
            .padding(20)
        }
        .onAppear {
            if service.categories.allSatisfy({ $0.fileCount == 0 && $0.estimatedSizeBytes == 0 }) {
                service.scanAll()
            }
        }
        .sheet(item: $reviewingCategory) { cat in
            reviewFilesSheet(cat)
        }
        .alert(executeDryRun ? "Execute Dry-Run Simulation?" : "Confirm Cache Cleanup", isPresented: $showConfirmAlert) {
            Button("Cancel", role: .cancel) {}
            Button(executeDryRun ? "Simulate" : "Clean Now", role: executeDryRun ? .none : .destructive) {
                service.executeCleanup(dryRun: executeDryRun)
            }
        } message: {
            if executeDryRun {
                Text("Dry-run mode calculates exact files without deleting any data from your storage.")
            } else {
                Text("Are you sure you want to clean the selected cache categories? Application caches will be deleted. Applications will safely recreate cache data as needed.")
            }
        }
    }
    
    // MARK: - Header Banner
    private var headerBanner: some View {
        let totalSelected = service.categories.filter { $0.isSelected }.reduce(0) { $0 + $1.estimatedSizeBytes }
        return AdaptivePageHeader(
            title: "Safe Cache & Storage Cleaner",
            subtitle: "Reclaim user-level cached files, temporary build artifacts, and expired diagnostics",
            icon: "sparkles",
            iconColor: AppTheme.electricBlue
        ) {
            VStack(alignment: .trailing, spacing: 2) {
                Text("Selected for Reclaim")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textTertiary)
                Text(Formatters.bytes(totalSelected))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.electricBlue)
            }
        }
    }
    
    // MARK: - Safety Advisory
    private var safetyAdvisoryCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 20))
                .foregroundStyle(AppTheme.successGreen)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Safety Guarantee & System Integrity")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Borno Pulse operates strictly in user space without requiring administrator credentials (sudo). Protected system files, personal documents, photos, keychains, and source code are strictly excluded.")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
                Text("Note: Clearing application caches may cause affected apps to rebuild cached assets or take slightly longer on their first launch.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .padding(12)
        .background(AppTheme.cardBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 0.5))
    }
    
    // MARK: - Control Bar
    private var controlBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                Button {
                    service.scanAll()
                } label: {
                    Label("Scan Now", systemImage: "arrow.clockwise")
                }
                .disabled(service.isScanning || service.isCleaning)
                
                Button("Select All Safe") {
                    service.selectAllSafe()
                }
                .buttonStyle(.bordered)
                .disabled(service.isScanning || service.isCleaning)
                
                Button("Deselect All") {
                    service.deselectAll()
                }
                .buttonStyle(.bordered)
                .disabled(service.isScanning || service.isCleaning)
                
                Spacer()
                
                statusIndicators
            }
            
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Button {
                        service.scanAll()
                    } label: {
                        Label("Scan Now", systemImage: "arrow.clockwise")
                    }
                    .disabled(service.isScanning || service.isCleaning)
                    
                    Button("Select All Safe") {
                        service.selectAllSafe()
                    }
                    .buttonStyle(.bordered)
                    .disabled(service.isScanning || service.isCleaning)
                    
                    Button("Deselect All") {
                        service.deselectAll()
                    }
                    .buttonStyle(.bordered)
                    .disabled(service.isScanning || service.isCleaning)
                }
                
                statusIndicators
            }
        }
    }
    
    @ViewBuilder
    private var statusIndicators: some View {
        if service.isScanning {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(service.currentActionText)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
                Button("Cancel") {
                    service.cancelScan()
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.dangerRed)
            }
        } else if service.isCleaning {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(service.currentActionText)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
                Button("Cancel") {
                    service.cancelClean()
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.dangerRed)
            }
        }
    }
    
    // MARK: - Categories List
    private var categoriesList: some View {
        VStack(spacing: 12) {
            ForEach(service.categories) { cat in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 12) {
                        Toggle("", isOn: Binding(
                            get: { cat.isSelected },
                            set: { _ in service.toggleCategory(id: cat.id) }
                        ))
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                        
                        Image(systemName: cat.icon)
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.electricBlue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(cat.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                if cat.type == .trash {
                                    StatusBadge(text: "Permanent Deletion", color: AppTheme.dangerRed)
                                }
                            }
                            Text(cat.path)
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.textTertiary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(Formatters.bytes(cat.estimatedSizeBytes))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("\(cat.fileCount) items")
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        
                        Button("Review Files") {
                            reviewingCategory = cat
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(cat.files.isEmpty)
                    }
                    
                    Text(cat.explanation)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.leading, 36)
                }
                .smartCard()
            }
        }
    }
    
    // MARK: - Action Section
    private var actionSection: some View {
        HStack(spacing: 16) {
            if let result = service.lastResult {
                HStack(spacing: 8) {
                    Image(systemName: result.isDryRun ? "eye.fill" : "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.successGreen)
                    Text(result.isDryRun
                        ? "Dry-Run simulated: \(result.deletedCount) files (\(Formatters.bytes(result.totalFreedBytes)))"
                        : "Reclaimed \(Formatters.bytes(result.totalFreedBytes)) across \(result.deletedCount) files"
                    )
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                }
            }
            
            Spacer()
            
            // Dry run button
            Button {
                executeDryRun = true
                showConfirmAlert = true
            } label: {
                Label("Dry-Run Simulation", systemImage: "eye")
            }
            .buttonStyle(.bordered)
            .disabled(service.isScanning || service.isCleaning || !service.categories.contains { $0.isSelected })
            
            // Execute clean button
            Button {
                executeDryRun = false
                showConfirmAlert = true
            } label: {
                Label("Clean Selected Items", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.electricBlue)
            .disabled(service.isScanning || service.isCleaning || !service.categories.contains { $0.isSelected })
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Review Sheet
    private func reviewFilesSheet(_ cat: CleanupCategory) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(cat.title, systemImage: cat.icon)
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Button("Done") {
                    reviewingCategory = nil
                }
            }
            
            Text("Reviewing \(cat.files.count) items found in \(cat.path)")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textSecondary)
            
            List(cat.files) { file in
                HStack {
                    Image(systemName: "doc")
                        .foregroundStyle(AppTheme.textTertiary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.name)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                        Text(file.path)
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.textTertiary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(Formatters.bytes(file.sizeBytes))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(.vertical, 2)
            }
            .listStyle(.inset)
            .frame(height: 350)
        }
        .padding(20)
        .frame(width: 580)
    }
}
