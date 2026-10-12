//
//  BatteryDetailView.swift
//  Borno Pulse
//
//  Comprehensive real-time battery and power management dashboard.
//

import Charts
import SwiftUI

// MARK: - Power Chart Time Window
public enum BatteryPowerChartWindow: String, CaseIterable, Identifiable {
    case fiveMinutes = "5 Minutes"
    case fifteenMinutes = "15 Minutes"

    public var id: String { rawValue }
    public var seconds: TimeInterval {
        switch self {
        case .fiveMinutes: return 300
        case .fifteenMinutes: return 900
        }
    }
}

public struct BatteryDetailView: View {
    @ObservedObject var monitor = SystemMonitor.shared
    @ObservedObject var estimateService = BatteryEstimationService.shared
    @ObservedObject var powerService = BatteryPowerService.shared
    @ObservedObject var settings = AppSettings.shared

    @State private var selectedTimeRange: BatteryTimeRange = .oneHour
    @State private var selectedPowerChartRange: BatteryPowerChartWindow = .fifteenMinutes
    @State private var showingAlertSettingsSheet: Bool = false

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                headerView

                if monitor.snapshot.battery.hasBattery {
                    // Hero Estimation Card
                    heroEstimationCard

                    // Power Flow Presentation (Power Adapter -> Mac System -> Battery)
                    powerFlowCard

                    // Live Electrical Telemetry (Watts Grid)
                    livePowerGrid

                    // Live Power Rolling Graph (5m / 15m)
                    livePowerHistoryChart

                    // Battery Level & State Gauge
                    batteryStateCard

                    // Hardware Chemistry & Diagnostics
                    diagnosticsGrid

                    // Historical Level Charts
                    historySection
                } else {
                    // Desktop Mac Card
                    desktopMacCard
                }

                // Energy Optimization Tips
                energyTipsCard
            }
            .padding(24)
        }
        .background(AppTheme.contentBackground)
        .sheet(isPresented: $showingAlertSettingsSheet) {
            BatterySettingsSheet()
        }
    }

    // MARK: - Header
    private var headerView: some View {
        AdaptivePageHeader(
            title: "Battery & Power Management",
            subtitle: monitor.snapshot.battery.hasBattery ? "Real-time electrical power telemetry, Li-ion workload analysis, and charger distribution" : "Desktop Mac AC power supply with unrestricted performance envelope",
            leadingExtra: {
                Image(systemName: monitor.snapshot.battery.hasBattery ? (monitor.snapshot.battery.isCharging ? "bolt.batteryblock.fill" : "battery.100") : "desktopcomputer")
                    .font(.title2)
                    .foregroundStyle(headerColor)
            }
        ) {
            HStack(spacing: 12) {
                if monitor.snapshot.battery.hasBattery {
                    Button {
                        showingAlertSettingsSheet = true
                    } label: {
                        Label("Alerts & Thresholds", systemImage: "bell.badge")
                    }
                    .buttonStyle(.bordered)

                    // Status Badge
                    HStack(spacing: 6) {
                        Circle()
                            .fill(headerColor)
                            .frame(width: 8, height: 8)
                        Text(statusBadgeText)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(headerColor)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(headerColor.opacity(0.12))
                    .clipShape(Capsule())
                } else {
                    StatusBadge(text: "AC Powered", color: AppTheme.successGreen)
                }
            }
        }
    }

    private var headerColor: Color {
        let b = monitor.snapshot.battery
        if !b.hasBattery { return AppTheme.electricBlue }
        if b.isCharging { return AppTheme.successGreen }
        if b.percentage <= 10 { return AppTheme.dangerRed }
        if b.percentage <= 20 { return AppTheme.warningAmber }
        return AppTheme.successGreen
    }

    private var statusBadgeText: String {
        let b = monitor.snapshot.battery
        if b.isFullyCharged { return "100% Fully Charged" }
        if b.isCharging { return "\(b.percentage)% Charging" }
        if b.isPluggedIn { return "\(b.percentage)% On AC Power" }
        return "\(b.percentage)% Discharging"
    }

    // MARK: - Hero Estimation Card
    private var heroEstimationCard: some View {
        let b = monitor.snapshot.battery

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(b.isCharging ? "ESTIMATED TIME UNTIL FULL CHARGE" : "ESTIMATED TIME REMAINING")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)

                    Text(b.formattedTimeRemaining)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)

                    HStack(spacing: 8) {
                        confidenceBadge(b.estimateConfidence)

                        Text("•")
                            .foregroundStyle(.secondary)

                        Text("Updated \(b.lastUpdated.formatted(date: .omitted, time: .standard))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Live rate and wattage stats
                VStack(alignment: .trailing, spacing: 8) {
                    if let rate = b.ratePercentagePerHour {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Observed Rate")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%@%.1f%% / hr", rate > 0 ? "+" : "", rate))
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundStyle(rate > 0 ? AppTheme.successGreen : (rate < -25 ? AppTheme.warningAmber : AppTheme.textPrimary))
                        }
                    }

                    if let chargeWatts = b.chargingWatts {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Charging Power")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(String(format: "+%.1f W", chargeWatts))
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppTheme.successGreen)
                        }
                    } else if let dischargeWatts = b.dischargingWatts {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Discharging Power")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(String(format: "-%.1f W", dischargeWatts))
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppTheme.electricCyan)
                        }
                    } else if b.isPluggedIn {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Battery Power")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("0.0 W (Holding)")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    } else if let watts = b.wattage {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Net Wattage")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.1f W", abs(watts)))
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppTheme.electricCyan)
                        }
                    }
                }
            }

            Divider().opacity(0.15)

            Text(estimationExplanationText(b))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(headerColor.opacity(0.25), lineWidth: 1)
                )
        )
    }

    private func confidenceBadge(_ confidence: BatteryEstimateConfidence) -> some View {
        HStack(spacing: 4) {
            Image(systemName: confidenceIcon(confidence))
                .font(.caption2)
            Text(confidence.rawValue)
                .font(.caption2.bold())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(confidenceColor(confidence).opacity(0.15))
        .foregroundStyle(confidenceColor(confidence))
        .clipShape(Capsule())
    }

    private func confidenceIcon(_ confidence: BatteryEstimateConfidence) -> String {
        switch confidence {
        case .high: return "checkmark.shield.fill"
        case .medium: return "shield.fill"
        case .low: return "exclamationmark.shield.fill"
        case .calculating: return "hourglass"
        case .unavailable: return "questionmark.circle"
        }
    }

    private func confidenceColor(_ confidence: BatteryEstimateConfidence) -> Color {
        switch confidence {
        case .high: return AppTheme.successGreen
        case .medium: return AppTheme.electricBlue
        case .low: return AppTheme.warningAmber
        case .calculating: return AppTheme.neonCyan
        case .unavailable: return .secondary
        }
    }

    private func estimationExplanationText(_ b: BatteryMetrics) -> String {
        if b.isFullyCharged {
            return "Battery is saturated at maximum charge. Power adapter is supplying direct system power."
        }
        if b.isCharging {
            return "Charging estimates incorporate dynamic Li-ion saturation curve tapering between 80% and 100%."
        }
        return "Discharge estimates calculate remaining runtime based on active electrical consumption and rolling workload history."
    }

    // MARK: - Power Flow Presentation Card
    private var powerFlowCard: some View {
        let b = monitor.snapshot.battery

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Power Flow Distribution")
                        .font(.headline)
                    Text("Live electrical routing across charger, logic board, and battery cells")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(b.isPluggedIn ? AppTheme.successGreen : AppTheme.electricCyan)
                        .frame(width: 8, height: 8)
                    Text(b.isPluggedIn ? "External AC Power Active" : "Internal Battery Power Active")
                        .font(.caption.bold())
                        .foregroundStyle(b.isPluggedIn ? AppTheme.successGreen : AppTheme.electricCyan)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background((b.isPluggedIn ? AppTheme.successGreen : AppTheme.electricCyan).opacity(0.12))
                .clipShape(Capsule())
            }

            // Horizontal Interactive Flow Diagram
            HStack(spacing: 10) {
                if b.isPluggedIn {
                    // Node 1: Power Adapter
                    powerFlowNode(
                        title: "Power Adapter",
                        icon: "powerplug.fill",
                        primaryValue: b.adapterRatedWatts.map { "\($0) W Rated" } ?? "Connected",
                        secondaryValue: b.adapterInputWatts.map { String(format: "Inflow: %.1f W", $0) } ?? (b.adapterName ?? "USB-C PD Supply"),
                        accentColor: AppTheme.electricBlue
                    )

                    // Directional Arrow 1
                    powerFlowArrow(label: "Powers System\n& Charges", color: AppTheme.electricBlue)

                    // Node 2: Mac System
                    powerFlowNode(
                        title: "Mac System",
                        icon: "macbook.and.iphone",
                        primaryValue: b.systemPowerWatts.map { String(format: "%.1f W", $0) } ?? "Active Load",
                        secondaryValue: "CPU, GPU, RAM & Display",
                        accentColor: AppTheme.purpleAccent
                    )

                    // Directional Arrow 2
                    powerFlowArrow(label: b.isCharging ? "Charges\nCells" : "Bypassed\n(Hold)", color: b.isCharging ? AppTheme.successGreen : .secondary)

                    // Node 3: Internal Battery
                    powerFlowNode(
                        title: "Internal Battery",
                        icon: b.isCharging ? "bolt.batteryblock.fill" : "battery.100",
                        primaryValue: b.chargingWatts.map { String(format: "+%.1f W", $0) } ?? "\(b.percentage)%",
                        secondaryValue: b.isCharging ? "Absorbing Charge" : (b.isFullyCharged ? "Fully Charged (100%)" : "Charge Held (\(b.percentage)%)"),
                        accentColor: b.isCharging ? AppTheme.successGreen : AppTheme.textPrimary
                    )
                } else {
                    // Discharging Flow: Battery -> Mac System -> Adapter Disconnected
                    powerFlowNode(
                        title: "Internal Battery",
                        icon: "battery.100",
                        primaryValue: b.dischargingWatts.map { String(format: "-%.1f W", $0) } ?? "\(b.percentage)%",
                        secondaryValue: "Cell Discharge",
                        accentColor: AppTheme.electricCyan
                    )

                    powerFlowArrow(label: "Powering\nEntire Mac", color: AppTheme.electricCyan)

                    powerFlowNode(
                        title: "Mac System",
                        icon: "macbook.and.iphone",
                        primaryValue: b.systemPowerWatts.map { String(format: "%.1f W", $0) } ?? "Active Workload",
                        secondaryValue: "CPU, GPU, RAM & Display",
                        accentColor: AppTheme.purpleAccent
                    )

                    powerFlowArrow(label: "No External\nInflow", color: .secondary.opacity(0.4))

                    powerFlowNode(
                        title: "Power Adapter",
                        icon: "powerplug.slash",
                        primaryValue: "Disconnected",
                        secondaryValue: "Operating on Battery",
                        accentColor: .secondary
                    )
                }
            }
            .padding(.vertical, 4)

            // Educational Callout Box
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.caption)
                    .foregroundStyle(AppTheme.electricBlue)
                    .padding(.top, 1)
                Text("Adapter rated wattage (e.g. 30 W), system power draw, and battery charging power are independent electrical measurements. When connected, the adapter powers the Mac system and recharges the battery simultaneously. A 30 W adapter does not mean the Mac is continuously drawing 30 W.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(AppTheme.electricBlue.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(18)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func powerFlowNode(title: String, icon: String, primaryValue: String, secondaryValue: String, accentColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(accentColor)
                Text(title)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }
            Text(primaryValue)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .lineLimit(1)
            Text(secondaryValue)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(accentColor.opacity(0.2), lineWidth: 1))
    }

    private func powerFlowArrow(label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(color)
                .multilineTextAlignment(.center)
            Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(color)
        }
        .frame(width: 68)
    }

    // MARK: - Live Electrical Telemetry Grid (Watts)
    private var livePowerGrid: some View {
        let b = monitor.snapshot.battery

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Live Electrical Telemetry (Watts)")
                    .font(.headline)
                Spacer()
                Text("Real-time measured IOKit sensors")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            AdaptiveCardGrid(minColumnWidth: 165, spacing: 12) {
                // 1. Battery Power
                livePowerCard(
                    title: b.isCharging ? "Battery Charging" : (b.isPluggedIn ? "Battery Inflow" : "Battery Discharge"),
                    value: batteryPowerDisplayString(b),
                    subtitle: b.isMeasuredWattage ? "Measured (V × I)" : "Estimated (capacity delta)",
                    icon: b.isCharging ? "bolt.batteryblock.fill" : (b.isPluggedIn ? "powerplug.fill" : "battery.100"),
                    color: b.isCharging ? AppTheme.successGreen : (b.isPluggedIn ? AppTheme.electricBlue : AppTheme.electricCyan),
                    helpText: "Electrical power transferred to or from battery cells. Calculated from measured voltage × current."
                )

                // 2. System Power Draw
                livePowerCard(
                    title: "System Power Draw",
                    value: b.systemPowerWatts.map { String(format: "%.1f W", $0) } ?? "Unavailable on this Mac",
                    subtitle: "Logic board & SoC consumption",
                    icon: "cpu",
                    color: AppTheme.purpleAccent,
                    helpText: "Active power demanded by CPU, GPU, neural engine, display, and peripherals."
                )

                // 3. Adapter Input Power
                livePowerCard(
                    title: "Adapter Input Power",
                    value: b.isPluggedIn ? (b.adapterInputWatts.map { String(format: "%.1f W", $0) } ?? "Connected") : "Disconnected",
                    subtitle: b.isPluggedIn ? (b.adapterName ?? "USB-C Power Delivery") : "Running on battery",
                    icon: "cable.connector",
                    color: b.isPluggedIn ? AppTheme.electricBlueLight : .secondary,
                    helpText: "Instantaneous electrical power supplied by the connected charger into the Mac."
                )

                // 4. Adapter Rated Capacity
                livePowerCard(
                    title: "Adapter Rated Power",
                    value: b.isPluggedIn ? (b.adapterRatedWatts.map { "\($0) W" } ?? "Connected") : "Disconnected",
                    subtitle: "Maximum charger capacity",
                    icon: "bolt.shield.fill",
                    color: b.isPluggedIn ? AppTheme.orangeAccent : .secondary,
                    helpText: "Maximum continuous output capability advertised by the power adapter through USB-PD."
                )
            }
        }
    }

    private func batteryPowerDisplayString(_ b: BatteryMetrics) -> String {
        if let c = b.chargingWatts {
            if c > 0.05 { return String(format: "+%.1f W", c) }
            if b.isPluggedIn { return "0.0 W (Holding)" }
        }
        if let d = b.dischargingWatts {
            return String(format: "-%.1f W", d)
        }
        if b.isPluggedIn {
            return "0.0 W (AC Hold)"
        }
        if let w = b.wattage {
            return String(format: "%.1f W", abs(w))
        }
        return "Unavailable on this Mac"
    }

    private func livePowerCard(title: String, value: String, subtitle: String, icon: String, color: Color, helpText: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .lineLimit(1)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .help(helpText)
    }

    // MARK: - Live Power Rolling Graph
    private var livePowerHistoryChart: some View {
        let samples = powerService.samples(for: selectedPowerChartRange.seconds)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Live Power History (Watts)")
                        .font(.headline)
                    Text("Instantaneous electrical power trends over the rolling window")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Picker("", selection: $selectedPowerChartRange) {
                    ForEach(BatteryPowerChartWindow.allCases) { window in
                        Text(window.rawValue).tag(window)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
            }

            if samples.count >= 2 {
                VStack(spacing: 12) {
                    Chart {
                        ForEach(samples) { item in
                            if let charge = item.chargingWatts {
                                LineMark(
                                    x: .value("Time", item.timestamp),
                                    y: .value("Watts", charge)
                                )
                                .foregroundStyle(by: .value("Metric", "Battery Charging (W)"))
                                .lineStyle(StrokeStyle(lineWidth: 2))
                            } else if let discharge = item.dischargingWatts {
                                LineMark(
                                    x: .value("Time", item.timestamp),
                                    y: .value("Watts", discharge)
                                )
                                .foregroundStyle(by: .value("Metric", "Battery Discharge (W)"))
                                .lineStyle(StrokeStyle(lineWidth: 2))
                            }

                            if let sysW = item.systemPowerWatts {
                                LineMark(
                                    x: .value("Time", item.timestamp),
                                    y: .value("Watts", sysW)
                                )
                                .foregroundStyle(by: .value("Metric", "System Load (W)"))
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 2]))
                            }
                        }
                    }
                    .chartForegroundStyleScale([
                        "Battery Charging (W)": AppTheme.successGreen,
                        "Battery Discharge (W)": AppTheme.electricCyan,
                        "System Load (W)": AppTheme.purpleAccent
                    ])
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(anchor: .trailing) {
                                if let val = value.as(Double.self) {
                                    Text("\(Int(val)) W")
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(anchor: .top, format: .dateTime.minute().second())
                        }
                    }
                    .frame(height: 180)

                    HStack(spacing: 16) {
                        legendItem(label: "Battery Power", color: monitor.snapshot.battery.isCharging ? AppTheme.successGreen : AppTheme.electricCyan, isDashed: false)
                        if monitor.snapshot.battery.systemPowerWatts != nil {
                            legendItem(label: "System Load", color: AppTheme.purpleAccent, isDashed: true)
                        }
                        Spacer()
                        Text("Units: Watts (W) • Sampled every second")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "bolt.horizontal")
                        .font(.system(size: 28))
                        .foregroundStyle(AppTheme.electricBlue)
                    Text("Collecting Live Power Telemetry...")
                        .font(.subheadline.bold())
                    Text("Live electrical samples are being recorded. Chart trajectory appears after a few seconds of monitoring.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(32)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func legendItem(label: String, color: Color, isDashed: Bool) -> some View {
        HStack(spacing: 6) {
            if isDashed {
                HStack(spacing: 2) {
                    Rectangle().fill(color).frame(width: 4, height: 2)
                    Rectangle().fill(color).frame(width: 4, height: 2)
                }
            } else {
                Rectangle().fill(color).frame(width: 12, height: 2)
            }
            Text(label)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Battery State & Gauge Card
    private var batteryStateCard: some View {
        let b = monitor.snapshot.battery

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(b.powerSource, systemImage: b.isPluggedIn ? "powerplug.fill" : "battery.100")
                    .font(.subheadline.bold())

                Spacer()

                Text("\(b.percentage)%")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(headerColor)
            }

            GaugeBar(
                value: Double(b.percentage) / 100.0,
                gradient: LinearGradient(colors: [headerColor, headerColor.opacity(0.7)], startPoint: .leading, endPoint: .trailing),
                height: 14
            )

            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Text("State:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(b.stateOfCharge.rawValue)
                        .font(.caption.bold())
                }

                HStack(spacing: 6) {
                    Text("Health:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(b.healthPercentage != nil ? "\(b.healthPercentage!)%" : "Normal")
                        .font(.caption.bold())
                }

                HStack(spacing: 6) {
                    Text("Condition:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(b.condition)
                        .font(.caption.bold())
                }

                Spacer()
            }
        }
        .padding(18)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Diagnostics Grid
    private var diagnosticsGrid: some View {
        let b = monitor.snapshot.battery

        return VStack(alignment: .leading, spacing: 12) {
            Text("Battery Chemistry & Telemetry")
                .font(.headline)

            AdaptiveCardGrid(minColumnWidth: 165, spacing: 12) {
                diagnosticCard(
                    title: "Cycle Count",
                    value: b.cycleCount != nil ? "\(b.cycleCount!) / 1000" : "Unavailable",
                    subtitle: "Rated for 1,000 full cycles",
                    icon: "arrow.triangle.2.circlepath",
                    color: AppTheme.electricBlue
                )

                diagnosticCard(
                    title: "Maximum Capacity",
                    value: b.healthPercentage != nil ? "\(b.healthPercentage!)%" : "Normal",
                    subtitle: "Original battery capacity",
                    icon: "heart.fill",
                    color: AppTheme.successGreen
                )

                diagnosticCard(
                    title: "Voltage",
                    value: b.voltageVolts != nil ? String(format: "%.2f V", b.voltageVolts!) : "Unavailable on this Mac",
                    subtitle: "DC cell voltage",
                    icon: "bolt.fill",
                    color: AppTheme.electricCyan
                )

                diagnosticCard(
                    title: "Current (Amperage)",
                    value: b.amperageAmps != nil ? String(format: "%.2f A", b.amperageAmps!) : "Unavailable on this Mac",
                    subtitle: b.isCharging ? "Charge inflow" : (b.isPluggedIn ? "AC bypass" : "Discharge outflow"),
                    icon: "waveform.path.ecg",
                    color: AppTheme.neonCyan
                )

                batteryTemperatureCard

                diagnosticCard(
                    title: "Low Battery Target",
                    value: "\(settings.batteryAlertThreshold)%",
                    subtitle: "Depletion safety reserve",
                    icon: "bell.fill",
                    color: AppTheme.warningAmber
                )
            }
        }
    }

    /// Battery temperature comes only from a battery-attributed sensor; it is never inferred
    /// from charge level, charging state or power draw.
    private var batteryTemperatureCard: some View {
        let sensors = monitor.snapshot.sensors
        let unit = settings.temperatureUnit
        return TimelineView(.periodic(from: .now, by: 5)) { context in
            if let reading = sensors.batteryTemperature {
                let stale = reading.isStale(at: context.date, maxAge: monitor.sensorStaleAfter)
                diagnosticCard(
                    title: "Temperature",
                    value: Formatters.temperature(reading.celsius, unit: unit) + (stale ? " (stale)" : ""),
                    subtitle: "\(reading.source.displayName) · updated \(Formatters.readingAge(since: reading.timestamp, now: context.date))",
                    icon: "thermometer.medium",
                    color: stale ? AppTheme.warningAmber : AppTheme.orangeAccent
                )
            } else {
                diagnosticCard(
                    title: "Temperature",
                    value: "Unavailable",
                    subtitle: sensors.state(for: .battery).displayText,
                    icon: "thermometer.medium",
                    color: AppTheme.textTertiary
                )
            }
        }
    }

    private func diagnosticCard(title: String, value: String, subtitle: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - History Section
    private var historySection: some View {
        let samples = estimateService.samples(for: selectedTimeRange)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Battery Level History & Trend")
                        .font(.headline)
                    Text("Observed charge level and workload trajectory")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Picker("", selection: $selectedTimeRange) {
                    ForEach(BatteryTimeRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)
            }

            if samples.count >= 2 {
                VStack(spacing: 16) {
                    // Battery Level Chart
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Battery Level (%)")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)

                        Chart(samples) { item in
                            AreaMark(
                                x: .value("Time", item.timestamp),
                                y: .value("Battery %", item.percentage)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [headerColor.opacity(0.35), headerColor.opacity(0.05)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                            LineMark(
                                x: .value("Time", item.timestamp),
                                y: .value("Battery %", item.percentage)
                            )
                            .foregroundStyle(headerColor)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                        }
                        .chartYScale(domain: 0...100)
                        .frame(height: 180)
                    }
                }
                .padding(16)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("Collecting Battery Telemetry...")
                        .font(.subheadline.bold())
                    Text("History builds automatically as you use your Mac. Observations are persisted locally for up to 7 days.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 360)
                }
                .frame(maxWidth: .infinity)
                .padding(36)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Desktop Mac Card
    private var desktopMacCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 36))
                    .foregroundStyle(AppTheme.electricBlue)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Desktop Mac — Continuous AC Power Supply")
                        .font(.headline)
                    Text("Connected to AC wall power with unrestricted thermal and computing budgets.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Text("This computer (Mac mini, Mac Studio, Mac Pro, or iMac) operates exclusively on AC wall power and contains no chemical battery cells. System performance, background processes, and storage subsystems run without battery conservation constraints.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Energy Tips Card
    private var energyTipsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Power Efficiency Guidelines", systemImage: "leaf.fill")
                .font(.subheadline.bold())
                .foregroundStyle(AppTheme.successGreen)

            VStack(alignment: .leading, spacing: 8) {
                tipRow(icon: "sun.max.fill", text: "Display brightness typically accounts for 30% to 50% of active power drain on portable Macs.")
                tipRow(icon: "bolt.badge.clock.fill", text: "macOS Low Power Mode limits peak clock speeds and reduces background daemon activity.")
                tipRow(icon: "cpu", text: "Closing unused background developer tools and high-energy processes substantially extends battery life.")
            }
        }
        .padding(18)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(AppTheme.successGreen)
                .frame(width: 16)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Battery Settings Sheet
private struct BatterySettingsSheet: View {
    @ObservedObject var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Battery Notifications & Thresholds")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }

            Divider()

            Form {
                Section("Low Battery Alert") {
                    Toggle("Notify on Low Battery", isOn: $settings.notifyLowBattery)

                    Picker("Alert Threshold:", selection: $settings.batteryAlertThreshold) {
                        Text("10% Remaining").tag(10)
                        Text("15% Remaining").tag(15)
                        Text("20% Remaining").tag(20)
                        Text("25% Remaining").tag(25)
                    }
                    .disabled(!settings.notifyLowBattery)
                }

                Section("Power State Alerts") {
                    Toggle("Notify when Fully Charged (100%)", isOn: $settings.notifyFullyCharged)
                    Toggle("Notify when Disconnected from Power", isOn: $settings.notifyPowerDisconnected)
                }

                Section("Unusual Activity") {
                    Toggle("Notify on Rapid Battery Discharge", isOn: $settings.notifyRapidDischarge)

                    Picker("Rapid Discharge Rate:", selection: $settings.rapidDischargeThresholdRatePerHour) {
                        Text("> 20% per hour").tag(20.0)
                        Text("> 25% per hour").tag(25.0)
                        Text("> 30% per hour").tag(30.0)
                        Text("> 40% per hour").tag(40.0)
                    }
                    .disabled(!settings.notifyRapidDischarge)
                }
            }
        }
        .padding(22)
        .frame(width: 450)
    }
}
