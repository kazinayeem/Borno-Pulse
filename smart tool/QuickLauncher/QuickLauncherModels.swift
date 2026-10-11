//
//  QuickLauncherModels.swift
//  Borno Pulse
//

import Foundation

public struct QuickLauncherItem: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let icon: String
    public let category: String
    public let section: NavigationSection
    public let keywords: [String]
    
    public init(
        id: String,
        title: String,
        subtitle: String,
        icon: String,
        category: String,
        section: NavigationSection,
        keywords: [String] = []
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.category = category
        self.section = section
        self.keywords = keywords
    }
}
