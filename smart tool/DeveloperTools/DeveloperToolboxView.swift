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
            AdaptivePageHeader(
                title: "Developer Toolbox",
                icon: "wrench.and.screwdriver.fill",
                iconColor: AppTheme.electricBlue
            ) {
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
                            .background(activeTab == tab ? AppTheme.selectionBackground : Color.clear)
                            .foregroundStyle(AppTheme.selectableForeground(activeTab == tab))
                            .contentShape(RoundedRectangle(cornerRadius: 6))
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
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(AppTheme.toolbarBackground)
            
            Divider()
            
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
