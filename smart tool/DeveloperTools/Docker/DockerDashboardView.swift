//
//  DockerDashboardView.swift
//  Borno Pulse
//

import AppKit
import SwiftUI

public struct DockerDashboardView: View {
    @State private var summary: DockerSystemSummary? = nil
    @State private var containers: [DockerContainerItem] = []
    @State private var images: [DockerImageItem] = []
    @State private var isLoading: Bool = false
    
    @State private var showingLogsForContainer: DockerContainerItem? = nil
    @State private var containerLogs: String = ""
    @State private var confirmationTarget: (action: String, container: DockerContainerItem)? = nil
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 14) {
            // Header Bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Docker Containers & Images")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    Text(summary?.message ?? "Checking Docker daemon connection...")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                Spacer()
                
                Button {
                    refresh()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
                
                if FileManager.default.fileExists(atPath: "/Applications/Docker.app") {
                    Button {
                        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Docker.app"))
                    } label: {
                        Label("Open Docker Desktop", systemImage: "arrow.up.forward.app")
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            if let sum = summary, sum.isAvailable {
                // Metric Summary Grid
                HStack(spacing: 12) {
                    metricBadge(title: "Running Containers", value: "\(sum.runningContainersCount)", icon: "play.circle.fill", color: AppTheme.successGreen)
                    metricBadge(title: "Total Containers", value: "\(sum.totalContainersCount)", icon: "shippingbox.fill", color: AppTheme.electricBlue)
                    metricBadge(title: "Cached Images", value: "\(sum.imagesCount)", icon: "square.stack.3d.up.fill", color: AppTheme.purpleAccent)
                    metricBadge(title: "Engine Version", value: sum.engineVersion ?? "N/A", icon: "gearshape.2.fill", color: AppTheme.electricCyan)
                }
                
                // Containers Table
                VStack(alignment: .leading, spacing: 10) {
                    Text("Containers (\(containers.count))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    if containers.isEmpty {
                        Text("No containers present on this Docker daemon.")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textTertiary)
                            .frame(maxWidth: .infinity, minHeight: 120)
                            .smartCard()
                    } else {
                        ScrollView {
                            VStack(spacing: 6) {
                                ForEach(containers) { c in
                                    containerRow(c)
                                }
                            }
                        }
                        .frame(minHeight: 220)
                    }
                }
                .padding(14)
                .smartCard()
            } else {
                // Unavailable fallback
                unavailableStateView
            }
        }
        .padding(16)
        .onAppear {
            refresh()
        }
        .sheet(item: $showingLogsForContainer) { c in
            logsSheet(for: c)
        }
        .confirmationDialog(
            "Confirm Container Action",
            isPresented: Binding(
                get: { confirmationTarget != nil },
                set: { if !$0 { confirmationTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let target = confirmationTarget {
                Button("\(target.action.capitalized) Container", role: target.action == "stop" ? .destructive : .none) {
                    executeAction(action: target.action, container: target.container)
                }
                Button("Cancel", role: .cancel) {
                    confirmationTarget = nil
                }
            }
        } message: {
            if let target = confirmationTarget {
                Text("Are you sure you want to \(target.action) container '\(target.container.names)' (\(target.container.id))?")
            }
        }
    }
    
    // MARK: - Container Row
    private func containerRow(_ c: DockerContainerItem) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(c.isRunning ? AppTheme.successGreen : AppTheme.dangerRed)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(c.names)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                
                Text("\(c.image) • ID: \(c.id.prefix(12))")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .frame(width: 220, alignment: .leading)
            
            Text(c.status)
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.textTertiary)
                .lineLimit(1)
            
            Spacer()
            
            // Actions
            HStack(spacing: 6) {
                if c.isRunning {
                    Button("Stop") {
                        confirmationTarget = ("stop", c)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    Button("Start") {
                        confirmationTarget = ("start", c)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.matrixGreen)
                    .controlSize(.small)
                }
                
                Button("Restart") {
                    confirmationTarget = ("restart", c)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("Logs") {
                    viewLogs(for: c)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(8)
        .background(AppTheme.cardBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.cardBorder, lineWidth: 0.5))
    }
    
    // MARK: - Metric Badge
    private func metricBadge(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .smartCard()
    }
    
    // MARK: - Unavailable State View
    private var unavailableStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "shippingbox.and.arrow.backward")
                .font(.system(size: 34))
                .foregroundStyle(AppTheme.textTertiary)
            
            Text("Docker Not Connected")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            
            Text("The Docker engine CLI was not found or the daemon is currently not running on this Mac.\nBorno Pulse does not bundle or require Docker; start Docker Desktop to enable this optional workspace.")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            
            Button("Check Connection Again") {
                refresh()
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.electricBlue)
        }
        .frame(maxWidth: .infinity, minHeight: 280)
        .smartCard()
    }
    
    // MARK: - Logs Sheet
    private func logsSheet(for container: DockerContainerItem) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Logs: \(container.names)")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Button("Close") {
                    showingLogsForContainer = nil
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(14)
            .background(AppTheme.cardBackgroundSecondary)
            
            Divider()
            
            TextEditor(text: .constant(containerLogs))
                .font(.system(size: 11, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(AppTheme.inputBackground)
        }
        .frame(width: 620, height: 460)
    }
    
    // MARK: - Helpers
    private func refresh() {
        isLoading = true
        Task {
            let res = await DockerService.shared.fetchSummary()
            await MainActor.run {
                self.summary = res.summary
                self.containers = res.containers
                self.images = res.images
                self.isLoading = false
            }
        }
    }
    
    private func executeAction(action: String, container: DockerContainerItem) {
        Task {
            switch action {
            case "start":
                _ = await DockerService.shared.startContainer(id: container.id)
            case "stop":
                _ = await DockerService.shared.stopContainer(id: container.id)
            case "restart":
                _ = await DockerService.shared.restartContainer(id: container.id)
            default: break
            }
            confirmationTarget = nil
            refresh()
        }
    }
    
    private func viewLogs(for container: DockerContainerItem) {
        Task {
            let logs = await DockerService.shared.fetchContainerLogs(id: container.id)
            await MainActor.run {
                self.containerLogs = logs
                self.showingLogsForContainer = container
            }
        }
    }
}
