//
//  ScreenTimeExclusionsSheet.swift
//  Borno Pulse
//

import AppKit
import SwiftUI

public struct ScreenTimeExclusionsSheet: View {
    @ObservedObject var tracker = ScreenTimeTrackerService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingClearConfirmation: Bool = false
    @State private var newAppBundleToExclude: String = ""
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Sheet Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "hand.raised.shield.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.matrixGreen)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Screen Time Privacy & App Exclusions")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Local-only data governance, exclusions, and history management")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accentFill)
            }
            .padding(18)
            .background(AppTheme.cardBackgroundSecondary)
            
            Divider()
                .background(AppTheme.cardBorder)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Privacy Safeguards Banner
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Privacy Safeguards & Local Storage")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        
                        privacyRow(
                            icon: "lock.shield.fill",
                            color: AppTheme.matrixGreen,
                            title: "100% On-Device & Zero Telemetry",
                            desc: "All usage logs are encoded into a local JSON database in Application Support. Nothing is sent to external servers or cloud services."
                        )
                        
                        privacyRow(
                            icon: "xmark.seal.fill",
                            color: AppTheme.electricCyan,
                            title: "Zero Content or Keystroke Recording",
                            desc: "We never inspect typed text, passwords, open document contents, webcam, or screenshots. Only window title/app bundle activation is captured."
                        )
                        
                        privacyRow(
                            icon: "macwindow.badge.plus",
                            color: AppTheme.purpleAccent,
                            title: "Permission Transparency",
                            desc: "Standard app switching uses NSWorkspace (no extra permissions needed). Standalone website inspection uses Apple Events without browser plugins."
                        )
                    }
                    .padding(14)
                    .smartCard()
                    
                    // Excluded Applications
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Excluded Applications")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text("Usage for these bundle identifiers will be ignored and not recorded")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            
                            Spacer()
                            
                            Text("\(tracker.excludedBundleIDs.count) excluded")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                        
                        // Add exclusion manual field
                        HStack {
                            TextField("Enter bundle ID (e.g. com.apple.loginwindow)", text: $newAppBundleToExclude)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12))
                                .padding(6)
                                .themedInputField()
                            
                            Button("Add") {
                                let trimmed = newAppBundleToExclude.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !trimmed.isEmpty {
                                    tracker.toggleExclusion(for: trimmed)
                                    newAppBundleToExclude = ""
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(newAppBundleToExclude.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        
                        // Excluded list
                        VStack(spacing: 4) {
                            ForEach(Array(tracker.excludedBundleIDs).sorted(), id: \.self) { bundleID in
                                HStack {
                                    Image(systemName: "eye.slash.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(AppTheme.warningAmber)
                                    
                                    Text(bundleID)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    
                                    Spacer()
                                    
                                    Button {
                                        tracker.toggleExclusion(for: bundleID)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 10))
                                            .foregroundStyle(AppTheme.dangerRed)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Remove from exclusion list")
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(AppTheme.insetBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                    }
                    .padding(14)
                    .smartCard()
                    
                    // Danger Zone: Clear History
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Data Retention & Reset")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.dangerRed)
                        
                        Text("Permanently delete all locally stored daily logs, app session aggregates, and timeline records from this Mac.")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                        
                        HStack {
                            Button("Erase All Screen Time Data", role: .destructive) {
                                showingClearConfirmation = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.dangerFill)
                            
                            Spacer()
                        }
                    }
                    .padding(14)
                    .smartCard()
                }
                .padding(18)
            }
        }
        .frame(width: 580, height: 600)
        .confirmationDialog(
            "Are you sure you want to delete all Screen Time data?",
            isPresented: $showingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete All History", role: .destructive) {
                tracker.clearAllHistory()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will wipe all locally stored application usage summaries, session timelines, and stats. This action cannot be undone.")
        }
    }
    
    private func privacyRow(icon: String, color: Color, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }
}
