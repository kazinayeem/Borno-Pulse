//
//  DeveloperToolboxView.swift
//  Borno Pulse
//

import SwiftUI

public struct DeveloperToolboxView: View {
    public enum DevToolTab: String, CaseIterable, Identifiable {
        case json = "JSON Tools"
        case jwt = "JWT Inspector"
        case api = "API Tester"
        case docker = "Docker"
        
        public var id: String { rawValue }
        
        public var icon: String {
            switch self {
            case .json: return "curlybraces"
            case .jwt: return "key.horizontal.fill"
            case .api: return "paperplane.fill"
            case .docker: return "shippingbox.fill"
            }
        }
    }
    
    @State private var activeTab: DevToolTab = .json
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Workspace Top Navigation Bar
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .foregroundStyle(AppTheme.electricBlue)
                    Text("Developer Toolbox")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                
                Spacer()
                
                // Segmented Tool Switcher
                HStack(spacing: 4) {
                    ForEach(DevToolTab.allCases) { tab in
                        Button {
                            activeTab = tab
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 11))
                                Text(tab.rawValue)
                                    .font(.system(size: 12, weight: activeTab == tab ? .semibold : .regular))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(activeTab == tab ? AppTheme.electricBlue.opacity(0.18) : Color.clear)
                            .foregroundStyle(activeTab == tab ? AppTheme.electricBlue : AppTheme.textSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.cardBorder, lineWidth: 0.5))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(AppTheme.cardBackgroundSecondary)
            
            Divider()
                .background(AppTheme.cardBorder)
            
            // Active Workspace Content
            Group {
                switch activeTab {
                case .json:
                    JSONToolsView()
                case .jwt:
                    JWTInspectorView()
                case .api:
                    APIRequestTesterView()
                case .docker:
                    DockerDashboardView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(AppTheme.graphiteCanvas)
    }
}
