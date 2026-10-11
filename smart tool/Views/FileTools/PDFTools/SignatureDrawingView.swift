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
        openPanel.allowedContentTypes = [.png, .jpeg, .tiff]
        openPanel.prompt = "Choose Signature"
        if openPanel.runModal() == .OK, let url = openPanel.url, let img = NSImage(contentsOf: url) {
            onSaveSignature(img)
            isPresented = false
        }
    }

    private func renderSignatureImage() -> NSImage? {
        let size = CGSize(width: 460, height: 200)
        let img = NSImage(size: size)
        img.lockFocus()

        // Transparent background
        NSColor.clear.setFill()
        CGRect(origin: .zero, size: size).fill()

        let nsStrokeColor = NSColor(strokeColor)
        nsStrokeColor.setStroke()

        for line in lines {
            guard let first = line.first else { continue }
            let bezier = NSBezierPath()
            bezier.lineWidth = strokeWidth
            bezier.lineCapStyle = .round
            bezier.lineJoinStyle = .round
            // Invert Y for macOS AppKit focus
            bezier.move(to: NSPoint(x: first.x, y: size.height - first.y))
            for pt in line.dropFirst() {
                bezier.line(to: NSPoint(x: pt.x, y: size.height - pt.y))
            }
            bezier.stroke()
        }

        img.unlockFocus()
        return img
    }
}
