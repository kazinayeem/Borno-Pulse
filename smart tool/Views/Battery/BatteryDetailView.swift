//
//  BatteryDetailView.swift
//  Naem Smart Tool
//

import SwiftUI

public struct BatteryDetailView: View {
    @ObservedObject var monitor = SystemMonitor.shared
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Battery & Power Management")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(monitor.snapshot.battery.hasBattery ? "Lithium-polymer battery health and power subsystem" : "Desktop Mac AC wall power supply")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    if monitor.snapshot.battery.hasBattery {
                        Text("\(monitor.snapshot.battery.percentage)%")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.successGreen)
                    } else {
                        StatusBadge(text: "AC Powered", color: AppTheme.successGreen)
                    }
                }
                
                if monitor.snapshot.battery.hasBattery {
                    // Battery Status Card
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Label(monitor.snapshot.battery.isCharging ? "Charging" : (monitor.snapshot.battery.isPluggedIn ? "Power Adapter Connected" : "Running on Battery"), systemImage: monitor.snapshot.battery.isCharging ? "bolt.fill" : "powerplug")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppTheme.successGreen)
                            Spacer()
                            Text(monitor.snapshot.battery.condition)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.successGreen)
                        }
                        
                        GaugeBar(
                            value: Double(monitor.snapshot.battery.percentage) / 100.0,
                            gradient: LinearGradient(colors: [AppTheme.successGreen, AppTheme.electricCyan], startPoint: .leading, endPoint: .trailing),
                            height: 12
                        )
                        
                        if let remaining = monitor.snapshot.battery.timeToEmptyMinutes {
                            Text("Estimated battery life remaining: \(remaining / 60)h \(remaining % 60)m")
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    .smartCard()
                    
                    // Health & Cycle Info
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Battery Chemistry & Health Diagnostics")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                        
                        if let cycles = monitor.snapshot.battery.cycleCount {
                            StatRow(
                                label: "Cycle Count",
                                value: "\(cycles) cycles (rated for 1,000)",
                                icon: "arrow.triangle.2.circlepath"
                            )
                        }
                        
                        if let health = monitor.snapshot.battery.healthPercentage {
                            StatRow(
                                label: "Maximum Capacity (Health)",
                                value: "\(health)%",
                                icon: "heart.fill"
                            )
                        }
                        
                        StatRow(
                            label: "Power Source Mode",
                            value: monitor.snapshot.battery.powerSource,
                            icon: "powerplug"
                        )
                        
                        StatRow(
                            label: "Telemetry API",
                            value: "IOKit.ps (IOPowerSources) & AppleSmartBattery",
                            icon: "checkmark.shield.fill"
                        )
                    }
                    .smartCard()
                } else {
                    // Desktop Mac Info
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Desktop Power Management", systemImage: "desktopcomputer")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.electricBlue)
                        
                        Text("This Mac does not have an internal rechargeable battery. It operates continuously on AC wall power with unrestricted thermal and computing budgets.")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .smartCard()
                }
                
                // Energy Efficiency Recommendations
                VStack(alignment: .leading, spacing: 12) {
                    Label("Energy Optimization Best Practices", systemImage: "leaf.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.successGreen)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        tipRow(icon: "sun.max.fill", text: "Display brightness accounts for up to 40% of peak energy consumption on portable Macs.")
                        tipRow(icon: "bolt.badge.clock.fill", text: "Low Power Mode reduces background tasks and lowers CPU clocks during portable operation.")
                        tipRow(icon: "sparkles", text: "Closing unused browser tabs and intensive background renderer tasks dramatically extends battery life.")
                    }
                }
                .smartCard()
            }
            .padding(20)
        }
    }
    
    private func tipRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.successGreen)
                .frame(width: 18)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textSecondary)
        }
    }
}
