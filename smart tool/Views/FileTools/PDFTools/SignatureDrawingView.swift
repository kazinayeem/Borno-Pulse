//
//  SignatureDrawingView.swift
//  Borno Pulse
//
//  Interactive signature pad for trackpad or mouse drawing with image export.
//

import AppKit
import SwiftUI

public struct SignatureDrawingView: View {
    @Binding public var isPresented: Bool
    public var onSaveSignature: (NSImage) -> Void

    @State private var lines: [[CGPoint]] = []
    @State private var currentLine: [CGPoint] = []
    @State private var strokeColor: Color = .black
    @State private var strokeWidth: CGFloat = 3.0

    public init(isPresented: Binding<Bool>, onSaveSignature: @escaping (NSImage) -> Void) {
        self._isPresented = isPresented
        self.onSaveSignature = onSaveSignature
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Draw Digital Signature")
                    .font(.headline)
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Canvas
            ZStack(alignment: .bottomLeading) {
                // The canvas stands in for the white PDF page, so it stays paper-white in Dark Mode
                // and the default black ink remains visible.
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.borderStrong, lineWidth: 1))

                // Signature baseline guide
                Path { path in
                    path.move(to: CGPoint(x: 20, y: 150))
                    path.addLine(to: CGPoint(x: 440, y: 150))
                }
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(Color.black.opacity(0.25))

                // Stroke Paths
                Canvas { context, _ in
                    for line in lines {
                        var path = Path()
                        guard let first = line.first else { continue }
                        path.move(to: first)
                        for point in line.dropFirst() {
                            path.addLine(to: point)
                        }
                        context.stroke(path, with: .color(strokeColor), style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round))
                    }

                    var currentPath = Path()
                    if let first = currentLine.first {
                        currentPath.move(to: first)
                        for point in currentLine.dropFirst() {
                            currentPath.addLine(to: point)
                        }
                        context.stroke(currentPath, with: .color(strokeColor), style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round))
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            currentLine.append(value.location)
                        }
                        .onEnded { _ in
                            if !currentLine.isEmpty {
                                lines.append(currentLine)
                                currentLine = []
                            }
                        }
                )

                Text("Sign above this line using trackpad or mouse")
                    .font(.caption2)
                    .foregroundStyle(Color.black.opacity(0.5))
                    .padding(12)
            }
            .frame(width: 460, height: 200)

            // Toolbar Actions
            HStack(spacing: 12) {
                Button("Clear") {
                    lines.removeAll()
                    currentLine.removeAll()
                }
                .buttonStyle(.bordered)

                Button {
                    importSignatureFile()
                } label: {
                    Label("Import Image", systemImage: "photo")
                }
                .buttonStyle(.bordered)

                Picker("Ink", selection: $strokeColor) {
                    Text("Black").tag(Color.black)
                    Text("Blue").tag(Color(red: 0.05, green: 0.2, blue: 0.65))
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
                .help("Signature ink color")

                Spacer()

                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.plain)

                Button("Apply Signature") {
                    if let image = renderSignatureImage() {
                        onSaveSignature(image)
                        isPresented = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accentFill)
                .disabled(lines.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 500)
    }

    private func importSignatureFile() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.png, .jpeg, .tiff, .heic]
        openPanel.prompt = "Choose Signature"
        if openPanel.runModal() == .OK, let url = openPanel.url, let img = NSImage(contentsOf: url) {
            onSaveSignature(img)
            isPresented = false
        }
    }

    /// Renders the strokes cropped to their bounds at 3× resolution on a transparent background.
    private func renderSignatureImage() -> NSImage? {
        let allPoints = lines.flatMap { $0 }
        guard let first = allPoints.first else { return nil }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for point in allPoints {
            minX = min(minX, point.x); maxX = max(maxX, point.x)
            minY = min(minY, point.y); maxY = max(maxY, point.y)
        }
        let padding = strokeWidth * 2
        let crop = CGRect(x: minX - padding, y: minY - padding, width: maxX - minX + padding * 2, height: maxY - minY + padding * 2)
        let scale: CGFloat = 3
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: max(1, Int(crop.width * scale)),
            pixelsHigh: max(1, Int(crop.height * scale)),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        let cg = context.cgContext
        cg.clear(CGRect(x: 0, y: 0, width: rep.pixelsWide, height: rep.pixelsHigh))
        cg.scaleBy(x: scale, y: scale)

        NSColor(strokeColor).setStroke()
        for line in lines {
            guard let start = line.first else { continue }
            let bezier = NSBezierPath()
            bezier.lineWidth = strokeWidth
            bezier.lineCapStyle = .round
            bezier.lineJoinStyle = .round
            // Canvas points are y-down; the bitmap context is y-up.
            bezier.move(to: NSPoint(x: start.x - crop.minX, y: crop.maxY - start.y))
            for point in line.dropFirst() {
                bezier.line(to: NSPoint(x: point.x - crop.minX, y: crop.maxY - point.y))
            }
            if line.count == 1 {
                bezier.line(to: NSPoint(x: start.x - crop.minX + 0.5, y: crop.maxY - start.y))
            }
            bezier.stroke()
        }
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: crop.size)
        image.addRepresentation(rep)
        return image
    }
}
