//
//  SensorsDetailView.swift
//  Naem Smart Tool
//

import SwiftUI

public struct SensorsDetailView: View {
    @ObservedObject var monitor = SystemMonitor.shared
    @ObservedObject var settings = AppSettings.shared
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Temperature, Fans & Thermals")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Hardware thermal envelope monitoring and cooling subsystem")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    StatusBadge(
                        text: monitor.snapshot.sensors.thermalStateDescription.components(separatedBy: " ").first ?? "Nominal",
                        color: thermalColor(monitor.snapshot.sensors.thermalState)
                    )
                }
                
                // Thermal State Card
                VStack(alignment: .leading, spacing: 14) {
                    Label("macOS Thermal State Architecture", systemImage: "flame.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.orangeAccent)
                    
                    Text("The operating system dynamically modulates SoC clock frequencies and power delivery based on internal temperature sensors across CPU, GPU, Neural Engine, and power management ICs.")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    HStack(spacing: 12) {
                        thermalLevelCard(title: "Nominal", desc: "Optimal temperatures. Full performance unlocked.", active: monitor.snapshot.sensors.thermalState == .nominal, color: AppTheme.successGreen)
                        thermalLevelCard(title: "Fair", desc: "Elevated thermal load. Fans ramping up if equipped.", active: monitor.snapshot.sensors.thermalState == .fair, color: AppTheme.warningAmber)
                        thermalLevelCard(title: "Serious", desc: "High temperature. Proactive clock throttling active.", active: monitor.snapshot.sensors.thermalState == .serious, color: AppTheme.orangeAccent)
                        thermalLevelCard(title: "Critical", desc: "Severe heat. Maximum throttling to protect silicon.", active: monitor.snapshot.sensors.thermalState == .critical, color: AppTheme.dangerRed)
                    }
                }
                .smartCard()
                
                // Sensors & Cooling
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sensor Availability & Compatibility Matrix")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    StatRow(
                        label: "System Thermal Pressure",
                        value: monitor.snapshot.sensors.thermalStateDescription,
                        icon: "waveform.path.ecg"
                    )
                    
                    StatRow(
                        label: "Active Throttling Indicator",
                        value: monitor.snapshot.sensors.isThrottling ? "Active Throttling (Speed Reduced)" : "Optimal (No Throttling)",
                        icon: "bolt.shield.fill"
                    )
                    
                    StatRow(
                        label: "Diode Temperature Query",
                        value: monitor.snapshot.sensors.temperatureState.displayText,
                        icon: "thermometer",
                        hint: "On Apple Silicon, direct on-die micro-diode reads without a signed kernel extension are restricted by macOS sandbox security."
                    )
                    
                    StatRow(
                        label: "Fan Tachometer Telemetry",
                        value: monitor.snapshot.sensors.fansState.displayText,
                        icon: "fanblades",
                        hint: "Apple Silicon machines with passive cooling (e.g. MacBook Air) have no fans. Active cooling models delegate fan curve management exclusively to the Apple SMC coprocessor."
                    )
                }
                .smartCard()
            }
            .padding(20)
        }
    }
    
    private func thermalLevelCard(title: String, desc: String, active: Bool, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle().fill(active ? color : Color.gray.opacity(0.3)).frame(width: 8, height: 8)
                Text(title).font(.system(size: 13, weight: .bold)).foregroundStyle(active ? color : AppTheme.textSecondary)
            }
            Text(desc).font(.system(size: 10)).foregroundStyle(AppTheme.textTertiary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(active ? color.opacity(0.12) : Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(active ? color.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }
    
    private func thermalColor(_ state: ProcessInfo.ThermalState) -> Color {
        switch state {
        case .nominal: return AppTheme.successGreen
        case .fair: return AppTheme.warningAmber
        case .serious, .critical: return AppTheme.dangerRed
        @unknown default: return AppTheme.textSecondary
        }
    }
}
