//
//  ComponentViews.swift
//  Naem Smart Tool
//

import SwiftUI

// MARK: - GaugeBar
public struct GaugeBar: View {
    public let value: Double // 0.0 to 1.0
    public let gradient: LinearGradient
    public let height: CGFloat
    
    public init(
        value: Double,
        gradient: LinearGradient = AppTheme.blueGradient,
        height: CGFloat = 8
    ) {
        self.value = min(max(value, 0.0), 1.0)
        self.gradient = gradient
        self.height = height
    }
    
    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: height)
                
                Capsule()
                    .fill(gradient)
                    .frame(width: max(proxy.size.width * CGFloat(value), 0), height: height)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: value)
            }
        }
        .frame(height: height)
    }
}

// MARK: - StatusBadge
public struct StatusBadge: View {
    public let text: String
    public let color: Color
    public let showDot: Bool
    
    public init(text: String, color: Color = AppTheme.electricBlue, showDot: Bool = true) {
        self.text = text
        self.color = color
        self.showDot = showDot
    }
    
    public var body: some View {
        HStack(spacing: 5) {
            if showDot {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                    .shadow(color: color.opacity(0.6), radius: 3)
            }
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}

// MARK: - StatRow
public struct StatRow: View {
    public let label: String
    public let value: String
    public let icon: String?
    public let hint: String?
    
    public init(label: String, value: String, icon: String? = nil, hint: String? = nil) {
        self.label = label
        self.value = value
        self.icon = icon
        self.hint = hint
    }
    
    public var body: some View {
        HStack(alignment: .center) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textTertiary)
                        .frame(width: 16)
                }
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                
                if let hint = hint {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textTertiary)
                        .help(hint)
                }
            }
            
            Spacer()
            
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(.vertical, 4)
    }
}
