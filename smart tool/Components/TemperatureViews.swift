//
//  TemperatureViews.swift
//  Borno Pulse
//
//  Shared presentation of component temperatures so every page renders the same reading,
//  unavailable reason and stale warning for a given component.
//

import SwiftUI

/// A `StatRow` for one component's temperature. Re-evaluates freshness periodically so a
/// reading that stops updating is flagged even when no new snapshot arrives.
public struct ComponentTemperatureRow: View {
    public let component: ThermalComponent
    public let sensors: SensorMetrics
    public let unit: TemperatureUnit
    public let staleAfter: TimeInterval
    public let label: String?

    public init(
        component: ThermalComponent,
        sensors: SensorMetrics,
        unit: TemperatureUnit,
        staleAfter: TimeInterval,
        label: String? = nil
    ) {
        self.component = component
        self.sensors = sensors
        self.unit = unit
        self.staleAfter = staleAfter
        self.label = label
    }

    public var body: some View {
        TimelineView(.periodic(from: .now, by: 5)) { context in
            StatRow(
                label: label ?? "\(component.displayName) Temperature",
                value: valueText(now: context.date),
                icon: "thermometer.medium",
                hint: hintText(now: context.date)
            )
        }
    }

    private func valueText(now: Date) -> String {
        guard let value = sensors.temperature(for: component) else { return "Unavailable" }
        let formatted = Formatters.temperature(value.celsius, unit: unit)
        return value.isStale(at: now, maxAge: staleAfter) ? "\(formatted) (stale)" : formatted
    }

    private func hintText(now: Date) -> String {
        guard let value = sensors.temperature(for: component) else {
            return sensors.state(for: component).displayText
        }
        return TemperatureDescription.detail(for: value, unit: unit, now: now)
    }
}

public enum TemperatureDescription {
    /// e.g. "Average of 70 sensors via Apple SMC (SMC key convention). Peak 83 °C. Updated 2s ago."
    public static func detail(for value: ComponentTemperature, unit: TemperatureUnit, now: Date = Date()) -> String {
        let sensorsText = value.sensorCount == 1 ? "1 sensor" : "Average of \(value.sensorCount) sensors"
        var text = "\(sensorsText) via \(value.source.displayName) (\(value.identification.displayName))."
        if value.sensorCount > 1 {
            text += " Peak \(Formatters.temperature(value.maximumCelsius, unit: unit))."
        }
        text += " Updated \(Formatters.readingAge(since: value.timestamp, now: now))."
        return text
    }
}

/// Small badge showing how fresh a reading is; turns amber when stale.
public struct ReadingFreshnessBadge: View {
    public let timestamp: Date?
    public let staleAfter: TimeInterval

    public init(timestamp: Date?, staleAfter: TimeInterval) {
        self.timestamp = timestamp
        self.staleAfter = staleAfter
    }

    public var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if let timestamp {
                let stale = context.date.timeIntervalSince(timestamp) > staleAfter
                Text(stale ? "Stale · \(Formatters.readingAge(since: timestamp, now: context.date))" : "Updated \(Formatters.readingAge(since: timestamp, now: context.date))")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(stale ? AppTheme.warningAmber : AppTheme.textTertiary)
            } else {
                Text("No reading")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
    }
}

public func thermalStateColor(_ state: ProcessInfo.ThermalState) -> Color {
    switch state {
    case .nominal: return AppTheme.successGreen
    case .fair: return AppTheme.warningAmber
    case .serious, .critical: return AppTheme.dangerRed
    @unknown default: return AppTheme.textSecondary
    }
}
