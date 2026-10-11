//
//  ScreenTimePDFReportGenerator.swift
//  Borno Pulse
//

import AppKit
import Foundation

/// Generates local vector PDF reports of Screen Time analytics using native CoreGraphics and AppKit.
public final class ScreenTimePDFReportGenerator: Sendable {
    public static let shared = ScreenTimePDFReportGenerator()

    // Fixed print colors: the report is always rendered on light paper, regardless of the app appearance.
    private static let printPrimaryText = NSColor(white: 0.10, alpha: 1.0)
    private static let printSecondaryText = NSColor(white: 0.38, alpha: 1.0)
    
    private init() {}
    
    @MainActor
    public func generatePDFReport(
        range: ScreenTimeRangeOption,
        stats: ScreenTimeStatistics,
        topApps: [AppUsageAggregate],
        categories: [CategoryBreakdownItem],
        to destinationURL: URL
    ) throws {
        let pageWidth: CGFloat = 612.0 // Standard Letter
        let pageHeight: CGFloat = 792.0
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        guard let consumer = CGDataConsumer(url: destinationURL as CFURL),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw NSError(domain: "ScreenTimePDF", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize PDF context"])
        }
        
        context.beginPage(mediaBox: &mediaBox)
        
        let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.current = nsContext
        
        // Background fill
        NSColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 1.0).setFill()
        context.fill(mediaBox)
        
        // Header Banner
        let headerRect = CGRect(x: 36, y: pageHeight - 110, width: pageWidth - 72, height: 74)
        let headerPath = NSBezierPath(roundedRect: headerRect, xRadius: 8, yRadius: 8)
        NSColor(red: 0.08, green: 0.55, blue: 1.0, alpha: 1.0).setFill()
        headerPath.fill()
        
        // Header Text
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 20),
            .foregroundColor: NSColor.white
        ]
        "BORNO PULSE — SCREEN TIME REPORT".draw(at: CGPoint(x: 52, y: pageHeight - 65), withAttributes: titleAttributes)
        
        let subTitleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.white.withAlphaComponent(0.85)
        ]
        let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
        "Range: \(range.rawValue)  •  Generated: \(dateStr)  •  Zero Telemetry Local Audit".draw(at: CGPoint(x: 52, y: pageHeight - 88), withAttributes: subTitleAttributes)
        
        // Summary Cards Section
        let cardY = pageHeight - 180
        let cardWidth: CGFloat = (pageWidth - 72 - 24) / 3
        let cardHeight: CGFloat = 56
        
        drawSummaryCard(context: context, rect: CGRect(x: 36, y: cardY, width: cardWidth, height: cardHeight), title: "ACTIVE USAGE", value: Formatters.duration(stats.todayActiveDuration, showSeconds: true))
        drawSummaryCard(context: context, rect: CGRect(x: 36 + cardWidth + 12, y: cardY, width: cardWidth, height: cardHeight), title: "7-DAY DAILY AVG", value: Formatters.duration(stats.dailyAverage7Days))
        drawSummaryCard(context: context, rect: CGRect(x: 36 + (cardWidth + 12) * 2, y: cardY, width: cardWidth, height: cardHeight), title: "TOP APP", value: stats.mostUsedAppToday?.name ?? (topApps.first?.appName ?? "N/A"))
        
        // Category Breakdown Header
        let catHeaderY = cardY - 32
        let sectionTitleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 13),
            .foregroundColor: NSColor(red: 0.15, green: 0.18, blue: 0.22, alpha: 1.0)
        ]
        "CATEGORY DISTRIBUTION".draw(at: CGPoint(x: 36, y: catHeaderY), withAttributes: sectionTitleAttrs)
        
        var catRowY = catHeaderY - 22
        let catLimit = min(5, categories.count)
        for i in 0..<catLimit {
            let cat = categories[i]
            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10, weight: .medium),
                .foregroundColor: NSColor.darkGray
            ]
            let valAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
                .foregroundColor: NSColor.black
            ]
            
            let labelText = "• \(cat.category.rawValue)"
            let valText = "\(Formatters.duration(cat.totalDuration)) (\(String(format: "%.1f%%", cat.percentage)))"
            
            labelText.draw(at: CGPoint(x: 44, y: catRowY), withAttributes: labelAttrs)
            valText.draw(at: CGPoint(x: 200, y: catRowY), withAttributes: valAttrs)
            
            catRowY -= 16
        }
        
        // Applications Table Header
        let tableHeaderY = catRowY - 24
        "TOP APPLICATION RANKING".draw(at: CGPoint(x: 36, y: tableHeaderY), withAttributes: sectionTitleAttrs)
        
        let colY = tableHeaderY - 20
        let colAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 9),
            .foregroundColor: Self.printSecondaryText
        ]
        "APPLICATION".draw(at: CGPoint(x: 44, y: colY), withAttributes: colAttrs)
        "CATEGORY".draw(at: CGPoint(x: 220, y: colY), withAttributes: colAttrs)
        "TOTAL TIME".draw(at: CGPoint(x: 370, y: colY), withAttributes: colAttrs)
        "ACTIVE TIME".draw(at: CGPoint(x: 450, y: colY), withAttributes: colAttrs)
        "ACTIVE %".draw(at: CGPoint(x: 520, y: colY), withAttributes: colAttrs)
        
        // Divider line
        context.setStrokeColor(NSColor.lightGray.withAlphaComponent(0.4).cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: 36, y: colY - 4))
        context.addLine(to: CGPoint(x: pageWidth - 36, y: colY - 4))
        context.strokePath()
        
        var rowY = colY - 18
        let appLimit = min(15, topApps.count)
        let rowAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: Self.printPrimaryText
        ]
        let rowSubAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: Self.printSecondaryText
        ]
        
        for i in 0..<appLimit {
            let app = topApps[i]
            
            let rowBox = CGRect(x: 36, y: rowY - 2, width: pageWidth - 72, height: 16)
            if i % 2 == 1 {
                NSColor.black.withAlphaComponent(0.02).setFill()
                context.fill(rowBox)
            }
            
            "\(i + 1). \(app.appName)".draw(at: CGPoint(x: 44, y: rowY), withAttributes: rowAttrs)
            app.category.rawValue.draw(at: CGPoint(x: 220, y: rowY), withAttributes: rowSubAttrs)
            Formatters.duration(app.totalDuration).draw(at: CGPoint(x: 370, y: rowY), withAttributes: rowAttrs)
            Formatters.duration(app.activeDuration).draw(at: CGPoint(x: 450, y: rowY), withAttributes: rowAttrs)
            String(format: "%.0f%%", app.activePercentage).draw(at: CGPoint(x: 520, y: rowY), withAttributes: rowAttrs)
            
            rowY -= 16
        }
        
        // Footer Privacy Notice
        let footerRect = CGRect(x: 36, y: 36, width: pageWidth - 72, height: 32)
        let footerPath = NSBezierPath(roundedRect: footerRect, xRadius: 6, yRadius: 6)
        NSColor(red: 0.93, green: 0.95, blue: 0.98, alpha: 1.0).setFill()
        footerPath.fill()
        
        let footerAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 8.5),
            .foregroundColor: NSColor.darkGray
        ]
        "🔒 PRIVACY VERIFIED: Processed entirely on-device by Borno Pulse. No keystroke recording, no screen capture, no cloud sync.".draw(at: CGPoint(x: 48, y: 47), withAttributes: footerAttrs)
        
        context.endPage()
        context.closePDF()
    }
    
    private func drawSummaryCard(context: CGContext, rect: CGRect, title: String, value: String) {
        let cardPath = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
        NSColor.white.setFill()
        cardPath.fill()
        
        context.setStrokeColor(NSColor.lightGray.withAlphaComponent(0.3).cgColor)
        context.setLineWidth(0.5)
        context.stroke(rect)
        
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 8, weight: .semibold),
            .foregroundColor: Self.printSecondaryText
        ]
        let valAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 14),
            .foregroundColor: Self.printPrimaryText
        ]
        
        title.draw(at: CGPoint(x: rect.minX + 10, y: rect.maxY - 18), withAttributes: titleAttrs)
        value.draw(at: CGPoint(x: rect.minX + 10, y: rect.minY + 10), withAttributes: valAttrs)
    }
}
