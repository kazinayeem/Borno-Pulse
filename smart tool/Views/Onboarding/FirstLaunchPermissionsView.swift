//
//  FirstLaunchPermissionsView.swift
//  Borno Pulse
//
//  First-run onboarding and permissions setup modal.
//  Accurately audits storage permissions, background services, and accessibility privileges,
//  clearly indicating recommended vs elevated system settings.
//

import AppKit
import ApplicationServices
import SwiftUI

public struct FirstLaunchPermissionsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var monitor = SystemMonitor.shared
    @ObservedObject var clamshell = ClamshellManager.shared
    
    @State private var fdaGranted: Bool = false
    @State private var axGranted: Bool = false
    @State private var auditItems: [PermissionAuditItem] = []
    
    public let onComplete: () -> Void
    
    public init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(AppTheme.electricBlue.opacity(0.12))
                        .frame(width: 58, height: 58)
                    
                    Image(systemName: "gauge.with.dots.needle.bottom.100percent")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(AppTheme.electricBlue)
                }
                
                Text("Welcome to Borno Pulse")
                    .font(AppTypography.font(size: 19, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                
                Text("Smart Mac Utilities & System Monitor • Provided by BornoSoft")
                    .font(AppTypography.font(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                
                Text("Configure background services and optional system permissions to unlock deep cache cleaning, global shortcuts, and lid-closed background operation.")
                    .font(AppTypography.font(size: 11.5))
                    .foregroundStyle(AppTheme.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            Divider()
            
            // Scrollable Permission Cards
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 14) {
                    // Card 1: Background Engine & Startup (Essential)
                    permissionCard(
                        icon: "gearshape.2.fill",
                        iconColor: AppTheme.electricBlue,
                        title: "Background Services & Menu Bar Engine",
                        badge: "Essential",
                        badgeColor: AppTheme.electricBlue,
                        description: "Keeps live CPU, RAM, and thermal metrics updated in the menu bar and allows Display-Off Awake mode to maintain background Docker, servers, and scripts.",
                        isConfigured: settings.launchAtLogin && monitor.isMonitoring
                    ) {
                        VStack(spacing: 8) {
                            Toggle("Launch at Login (Start Borno Pulse on Boot)", isOn: $settings.launchAtLogin)
                                .font(AppTypography.font(size: 12, weight: .medium))
                            
                            Toggle("Active Background Telemetry (Menu Bar Poll)", isOn: Binding(
                                get: { monitor.isMonitoring },
                                set: { if $0 { monitor.resumeMonitoring() } else { monitor.pauseMonitoring() } }
                            ))
                            .font(AppTypography.font(size: 12, weight: .medium))
                        }
                    }
                    
                    // Card 2: Storage & Full Disk Access (Recommended)
                    permissionCard(
                        icon: "internaldrive.fill",
                        iconColor: fdaGranted ? AppTheme.successGreen : AppTheme.warningAmber,
                        title: "Storage & Deep Cache Cleaning",
                        badge: fdaGranted ? "Granted" : "Recommended for Deep Clean",
                        badgeColor: fdaGranted ? AppTheme.successGreen : AppTheme.warningAmber,
                        description: "Standard user caches clean out-of-the-box. Full Disk Access (FDA) is required to inspect protected system caches, Time Machine snapshots, and complete storage treemaps.",
                        isConfigured: fdaGranted
                    ) {
                        HStack {
                            Text(fdaGranted
                                 ? "✓ Full Disk Access is active. All system caches and volumes can be cleaned."
                                 : "Standard User Scope active. Grant Full Disk Access for complete deep clean."
                            )
                            .font(AppTypography.font(size: 11))
                            .foregroundStyle(fdaGranted ? AppTheme.successGreen : AppTheme.textSecondary)
                            
                            Spacer()
                            
                            Button(fdaGranted ? "Settings" : "Grant in System Settings…") {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    
                    // Card 3: Accessibility Permissions (Optional)
                    permissionCard(
                        icon: "command",
                        iconColor: axGranted ? AppTheme.successGreen : AppTheme.purpleAccent,
                        title: "Accessibility & Global Hotkeys",
                        badge: axGranted ? "Granted" : "Optional Power Features",
                        badgeColor: axGranted ? AppTheme.successGreen : AppTheme.purpleAccent,
                        description: "Allows Borno Pulse to trigger the ⌘K Quick Launcher from any app, paste from the Clipboard history, and track active window focus for Screen Time analytics.",
                        isConfigured: axGranted
                    ) {
                        HStack {
                            Text(axGranted
                                 ? "✓ Accessibility privileges granted. Global ⌘K hotkey and window tracking active."
                                 : "Optional: Not granted. Quick Launcher works while Borno Pulse is active."
                            )
                            .font(AppTypography.font(size: 11))
                            .foregroundStyle(axGranted ? AppTheme.successGreen : AppTheme.textSecondary)
                            
                            Spacer()
                            
                            Button(axGranted ? "Settings" : "Grant in System Settings…") {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    
                    // Privacy Note
                    HStack(spacing: 8) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.successGreen)
                        
                        Text("100% Local-First Architecture: Borno Pulse collects zero telemetry, contacts no external tracking servers, and keeps all data strictly on your Mac.")
                            .font(AppTypography.font(size: 10.5))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(10)
                    .background(AppTheme.cardBackgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.cardBorder, lineWidth: 0.5))
                }
                .padding(20)
            }
            
            Divider()
            
            // Footer Action Buttons
            HStack(spacing: 12) {
                Button("Recheck Permissions") {
                    refreshAudit()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                
                Spacer()
                
                Button("Get Started") {
                    settings.hasCompletedOnboarding = true
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .tint(AppTheme.electricBlue)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(AppTheme.toolbarBackground)
        }
        .frame(width: 620, height: 600)
        .background(AppTheme.graphiteCanvas)
        .onAppear {
            refreshAudit()
        }
    }
    
    private func refreshAudit() {
        let items = PermissionAuditService.shared.performAudit()
        self.auditItems = items
        self.axGranted = AXIsProcessTrusted()
        
        let home = FileManager.default.homeDirectoryForCurrentUser
        let safariPath = home.appendingPathComponent("Library/Safari/Bookmarks.plist")
        self.fdaGranted = FileManager.default.isReadableFile(atPath: safariPath.path)
    }
    
    @ViewBuilder
    private func permissionCard<Content: View>(
        icon: String,
        iconColor: Color,
        title: String,
        badge: String,
        badgeColor: Color,
        description: String,
        isConfigured: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 24)
                
                Text(title)
                    .font(AppTypography.font(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                
                Spacer()
                
                Text(badge)
                    .font(AppTypography.font(size: 9.5, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(badgeColor.opacity(0.14))
                    .foregroundStyle(badgeColor)
                    .clipShape(Capsule())
            }
            
            Text(description)
                .font(AppTypography.font(size: 11))
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            
            Divider()
                .padding(.vertical, 2)
            
            content()
        }
        .padding(14)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isConfigured ? AppTheme.successGreen.opacity(0.3) : AppTheme.cardBorder, lineWidth: 0.6)
        )
    }
}
