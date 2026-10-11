//
//  MetricCard.swift
//  Naem Smart Tool
//

import SwiftUI

public struct MetricCard<TrailingContent: View>: View {
    public let title: String
    public let icon: String
    public let iconColor: Color
    public let value: String
    public let subtitle: String?
    public let trailing: TrailingContent
    
    public init(
        title: String,
        icon: String,
        iconColor: Color = AppTheme.electricBlue,
        value: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> TrailingContent
    ) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.value = value
        self.subtitle = subtitle
        self.trailing = trailing()
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(iconColor)
                        .frame(width: 24, height: 24)
                        .background(iconColor.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                Spacer()
                
                trailing
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }
        }
        .smartCard()
    }
}

public extension MetricCard where TrailingContent == EmptyView {
    init(
        title: String,
        icon: String,
        iconColor: Color = AppTheme.electricBlue,
        value: String,
        subtitle: String? = nil
    ) {
        self.init(title: title, icon: icon, iconColor: iconColor, value: value, subtitle: subtitle) {
            EmptyView()
        }
    }
}
