//
//  LiveMetricChart.swift
//  Naem Smart Tool
//

import Charts
import SwiftUI

public struct LiveMetricChart: View {
    public let data: [Double]
    public let title: String?
    public let unit: String
    public let gradient: LinearGradient
    public let lineColor: Color
    public let maxValue: Double
    public let height: CGFloat
    
    public init(
        data: [Double],
        title: String? = nil,
        unit: String = "%",
        gradient: LinearGradient = AppTheme.blueGradient,
        lineColor: Color = AppTheme.electricBlue,
        maxValue: Double = 100.0,
        height: CGFloat = 80
    ) {
        self.data = data.isEmpty ? [0.0] : data
        self.title = title
        self.unit = unit
        self.gradient = gradient
        self.lineColor = lineColor
        self.maxValue = maxValue
        self.height = height
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title = title {
                HStack {
                    Text(title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    if let last = data.last {
                        Text("\(String(format: "%.1f", last))\(unit)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(lineColor)
                    }
                }
            }
            
            Chart {
                ForEach(Array(data.enumerated()), id: \.offset) { index, val in
                    AreaMark(
                        x: .value("Time", index),
                        y: .value("Value", val)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(gradient.opacity(0.22))
                    
                    LineMark(
                        x: .value("Time", index),
                        y: .value("Value", val)
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(lineColor)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, maxValue / 2, maxValue]) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                        .foregroundStyle(Color.white.opacity(0.06))
                    AxisValueLabel() {
                        if let intVal = value.as(Double.self) {
                            Text("\(Int(intVal))\(unit)")
                                .font(.system(size: 9, weight: .regular))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                    }
                }
            }
            .chartYScale(domain: 0...max(maxValue, (data.max() ?? maxValue) * 1.05))
            .frame(height: height)
        }
    }
}
