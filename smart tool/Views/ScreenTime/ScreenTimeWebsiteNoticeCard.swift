//
//  ScreenTimeWebsiteNoticeCard.swift
//  Naem Smart Tool
//

import SwiftUI

public struct ScreenTimeWebsiteNoticeCard: View {
    @ObservedObject var tracker = ScreenTimeTrackerService.shared
    @State private var isExpanded: Bool = false
    
    public init() {}
    
    public var body: some View {
        let days = tracker.getDays(for: tracker.selectedRange)
        var combinedWebsites: [String: WebsiteUsageAggregate] = [:]
        for day in days {
            for (domain, web) in day.websiteBreakdown {
                if let existing = combinedWebsites[domain] {
                    var updated = existing
                    updated.totalDuration += web.totalDuration
                    updated.visitCount += web.visitCount
                    combinedWebsites[domain] = updated
                } else {
                    combinedWebsites[domain] = web
                }
            }
        }
        let topWebsites = combinedWebsites.values.sorted { $0.totalDuration > $1.totalDuration }
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "globe")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.electricCyan)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Native Web Domain Tracking & Privacy Boundaries")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    Text("Extension-free architecture • Zero history scraping")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                Spacer()
                
                Button {
                    isExpanded.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Text(isExpanded ? "Hide Details" : "Privacy & API Details")
                            .font(.system(size: 11, weight: .medium))
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9))
                    }
                    .foregroundStyle(AppTheme.electricCyan)
                }
                .buttonStyle(.plain)
            }
            
            // Status Banner
            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.successGreen)
                
                Text(tracker.websiteTrackingNotice)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            if !topWebsites.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Top Sampled Web Domains (\(tracker.selectedRange.rawValue))")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 8)], spacing: 8) {
                        ForEach(topWebsites.prefix(6)) { web in
                            HStack {
                                Image(systemName: "safari.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(AppTheme.electricCyan)
                                
                                Text(web.domain)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Text(Formatters.duration(web.totalDuration))
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.black.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                    }
                }
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .background(AppTheme.cardBorder)
                    
                    Text("Architectural & Privacy Guarantees:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    bulletPoint(
                        title: "No Browser Extensions Required",
                        desc: "Full browser foreground usage is measured natively via NSWorkspace. You never need to install third-party extension manifests."
                    )
                    bulletPoint(
                        title: "Safe Frontmost Domain Sampling",
                        desc: "When macOS Automation permission is granted, only the top-level host of the active window is queried via Apple Events. Query strings, full URLs, and page content are never captured."
                    )
                    bulletPoint(
                        title: "Zero Private Browsing Access",
                        desc: "Naem Smart Tool never opens browser SQLite databases, history caches, cookies, or incognito sessions."
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .smartCard()
    }
    
    private func bulletPoint(title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Circle()
                .fill(AppTheme.electricCyan)
                .frame(width: 4, height: 4)
                .padding(.top, 4)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(desc)
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
    }
}
