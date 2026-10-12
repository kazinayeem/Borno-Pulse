//
//  SensorsDetailView.swift
//  Borno Pulse
//

import Charts
import SwiftUI

public struct SensorsDetailView: View {
    @ObservedObject var monitor = SystemMonitor.shared
    @ObservedObject var settings = AppSettings.shared
    
    public init() {}

    private var sensors: SensorMetrics { monitor.snapshot.sensors }
    private var unit: TemperatureUnit { settings.temperatureUnit }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                AdaptivePageHeader(
                    title: "Temperature & Fans",
                    subtitle: "Per-component sensor readings, fan speed and macOS thermal pressure"
                ) {
                    Picker("Unit", selection: $settings.temperatureUnit) {
                        Text("°C").tag(TemperatureUnit.celsius)
                        Text("°F").tag(TemperatureUnit.fahrenheit)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 90)
                }

                componentSummary
                historyCard
                thermalPressureCard
                fansCard
                allSensorsCard
                sourcesCard
            }
            .padding(20)
        }
    }

    // MARK: - Component Summary

    private var componentSummary: some View {
        AdaptiveCardGrid(minColumnWidth: 200, spacing: 12) {
            ForEach(ThermalComponent.headline) { component in
                componentCard(component)
            }
        }
    }

    private func componentCard(_ component: ThermalComponent) -> some View {
        let value = sensors.temperature(for: component)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(component.displayName, systemImage: component.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.orangeAccent)
                Spacer()
                if value != nil {
                    ReadingFreshnessBadge(timestamp: value?.timestamp, staleAfter: monitor.sensorStaleAfter)
                }
            }

            if let value {
                Text(Formatters.temperature(value.celsius, unit: unit))
                    .font(AppTypography.monospaced(size: 26, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(value.sensorCount > 1
                     ? "Average of \(value.sensorCount) sensors · peak \(Formatters.temperature(value.maximumCelsius, unit: unit))"
                     : "Single sensor")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
                Text("\(value.source.displayName) · \(value.identification.displayName)")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textTertiary)
            } else {
                Text("Unavailable")
                    .font(AppTypography.monospaced(size: 20, weight: .bold))
                    .foregroundStyle(AppTheme.textTertiary)
                Text(sensors.state(for: component).displayText)
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .smartCard()
    }

    // MARK: - History

    private var historyCard: some View {
        let series = ThermalComponent.headline.compactMap { component -> (ThermalComponent, [TemperatureHistoryPoint])? in
            guard let points = sensors.history[component], points.contains(where: { $0.celsius != nil }) else { return nil }
            return (component, points)
        }

        return VStack(alignment: .leading, spacing: 12) {
            Text("Temperature History")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)

            if series.isEmpty {
                Text("No temperature history yet. History is recorded only for components with a real sensor reading; gaps mark polls where a sensor was missing or stale.")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textTertiary)
            } else {
                Chart {
                    ForEach(series, id: \.0) { component, points in
                        ForEach(Self.segments(of: points), id: \.offset) { segment in
                            ForEach(segment.element) { point in
                                LineMark(
                                    x: .value("Time", point.timestamp),
                                    y: .value("Temperature", unit.convert(fromCelsius: point.celsius ?? 0)),
                                    series: .value("Segment", "\(component.rawValue)-\(segment.offset)")
                                )
                                .foregroundStyle(by: .value("Component", component.displayName))
                                .interpolationMethod(.monotone)
                            }
                        }
                    }
                }
                .chartYAxisLabel(unit.symbol)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.hour().minute().second(), anchor: .top)
                    }
                }
                .frame(height: 180)

                Text("Each line is one component's own sensors. Breaks in a line are polls where that sensor was unavailable or stale.")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .smartCard()
    }

    /// Splits a series at nil points so missing readings render as gaps instead of interpolated lines.
    static func segments(of points: [TemperatureHistoryPoint]) -> [(offset: Int, element: [TemperatureHistoryPoint])] {
        var result: [[TemperatureHistoryPoint]] = []
        var current: [TemperatureHistoryPoint] = []
        for point in points {
            if point.celsius == nil {
                if !current.isEmpty { result.append(current); current = [] }
            } else {
                current.append(point)
            }
        }
        if !current.isEmpty { result.append(current) }
        return Array(result.enumerated())
    }

    // MARK: - Thermal Pressure

    private var thermalPressureCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("System Thermal State", systemImage: "flame.fill")
                    .font(AppTypography.font(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.orangeAccent)
                Spacer()
                StatusBadge(text: sensors.thermalState.shortLabel, color: thermalStateColor(sensors.thermalState))
            }

            Text("macOS reports a thermal pressure level (ProcessInfo.thermalState), not a temperature. It indicates how strongly the system is limiting performance to manage heat.")
                .font(AppTypography.font(size: 12))
                .foregroundStyle(AppTheme.textSecondary)

            AdaptiveCardGrid(minColumnWidth: 140, spacing: 10) {
                thermalLevelCard(title: "Nominal", desc: "No thermal pressure.", active: sensors.thermalState == .nominal, color: AppTheme.successGreen)
                thermalLevelCard(title: "Fair", desc: "Elevated pressure. Fans may ramp up if equipped.", active: sensors.thermalState == .fair, color: AppTheme.warningAmber)
                thermalLevelCard(title: "Serious", desc: "Performance is being reduced.", active: sensors.thermalState == .serious, color: AppTheme.orangeAccent)
                thermalLevelCard(title: "Critical", desc: "Maximum performance reduction.", active: sensors.thermalState == .critical, color: AppTheme.dangerRed)
            }
        }
        .smartCard()
    }

    private func thermalLevelCard(title: String, desc: String, active: Bool, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle().fill(active ? color : AppTheme.disabledText).frame(width: 8, height: 8)
                Text(title).font(.system(size: 13, weight: .bold)).foregroundStyle(active ? color : AppTheme.textSecondary)
            }
            Text(desc).font(.system(size: 10)).foregroundStyle(AppTheme.textTertiary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(active ? color.opacity(0.12) : AppTheme.insetBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(active ? color.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }

    // MARK: - Fans

    private var fansCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Fans", systemImage: "fanblades.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)

            if sensors.fanSpeeds.isEmpty {
                StatRow(label: "Fan Speed", value: "Unavailable", icon: "fanblades", hint: sensors.fansState.displayText)
                Text(sensors.fansState.displayText)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textTertiary)
            } else {
                ForEach(sensors.fanSpeeds) { fan in
                    VStack(alignment: .leading, spacing: 4) {
                        StatRow(label: fan.name, value: Formatters.rpm(fan.speedRPM), icon: "fanblades")
                        if let max = fan.maxRPM {
                            GaugeBar(value: fan.speedRPM / max, gradient: AppTheme.warningGradient, height: 5)
                            Text("Range \(Formatters.rpm(fan.minRPM ?? 0)) – \(Formatters.rpm(max))")
                                .font(.system(size: 10))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                    }
                }
            }
        }
        .smartCard()
    }

    // MARK: - All Sensors

    private var allSensorsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("All Available Sensors")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                ReadingFreshnessBadge(timestamp: sensors.sampledAt, staleAfter: monitor.sensorStaleAfter)
            }

            if sensors.readings.isEmpty {
                Text(sensors.temperatureState.displayText)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textTertiary)
            } else {
                ForEach(ThermalComponent.allCases) { component in
                    let group = sensors.readings(for: component)
                    if !group.isEmpty {
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(component.groupDescription)
                                    .font(.system(size: 10))
                                    .foregroundStyle(AppTheme.textTertiary)
                                    .padding(.bottom, 4)
                                ForEach(group) { reading in
                                    HStack {
                                        Text(reading.name)
                                            .font(.system(size: 11))
                                            .foregroundStyle(AppTheme.textPrimary)
                                        Spacer()
                                        Text(Formatters.temperature(reading.celsius, unit: unit))
                                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(AppTheme.textPrimary)
                                    }
                                    .help("\(reading.source.displayName) · \(reading.key)")
                                }
                            }
                            .padding(.top, 4)
                        } label: {
                            HStack {
                                Label(component.displayName, systemImage: component.icon)
                                    .font(.system(size: 12, weight: .semibold))
                                Spacer()
                                Text("\(group.count) sensor\(group.count == 1 ? "" : "s") · \(group.first?.source.displayName ?? "")")
                                    .font(.system(size: 10))
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                        }
                    }
                }
            }
        }
        .smartCard()
    }

    // MARK: - Sources & Limitations

    private var sourcesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sensor Sources & Limitations")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)

            if sensors.sourceStatuses.isEmpty {
                StatRow(label: "Hardware Sensors", value: "Off", icon: "switch.2", hint: sensors.temperatureState.displayText)
            }
            ForEach(sensors.sourceStatuses) { status in
                StatRow(
                    label: status.source.displayName,
                    value: status.state.isAvailable ? "\(status.sensorCount) sensors" : "Unavailable",
                    icon: status.state.isAvailable ? "checkmark.circle" : "xmark.circle",
                    hint: status.state.isAvailable ? status.source.interfaceDescription : status.state.displayText
                )
            }

            Text("""
            • CPU, GPU, battery and SSD temperatures are each computed only from sensors attributed to that component. Unattributed sensors (such as power-management die sensors) are listed under their own names and never reported as CPU or GPU temperature.
            • Sensors named by macOS (IOHID) are preferred. Otherwise SMC keys are attributed by their naming convention, which is community-documented rather than Apple-documented.
            • Values are rounded to whole degrees; these sensors are not accurate to fractions of a degree.
            • Thermal state, fan speed and power draw are separate measurements and are never used as temperatures.
            """)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .smartCard()
    }
}
