//
//  FileDropZoneView.swift
//  Borno Pulse
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

public struct FileDropZoneView: View {
    public let title: String
    public let subtitle: String
    public let icon: String
    public let allowedTypes: [UTType]
    public let allowsMultiple: Bool
    public let onFilesSelected: ([URL]) -> Void
    
    @State private var isTargeted = false
    @State private var rejectedMessage: String?
    
    public init(
        title: String = "Drag & Drop Files Here",
        subtitle: String = "or click Select Files to choose from your Mac",
        icon: String = "arrow.down.doc.fill",
        allowedTypes: [UTType] = [.item],
        allowsMultiple: Bool = true,
        onFilesSelected: @escaping ([URL]) -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.allowedTypes = allowedTypes
        self.allowsMultiple = allowsMultiple
        self.onFilesSelected = onFilesSelected
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundStyle(isTargeted ? AppTheme.electricCyan : AppTheme.electricBlue)
                .scaleEffect(isTargeted ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isTargeted)
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)

                if let rejectedMessage {
                    Label(rejectedMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.warningAmber)
                        .multilineTextAlignment(.center)
                }
            }
            
            Button("Select Files...") {
                openFileDialog()
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accentFill)
            .controlSize(.small)
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isTargeted ? AppTheme.selectionBackground : AppTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    isTargeted ? AppTheme.electricBlue : AppTheme.borderStrong,
                    style: StrokeStyle(lineWidth: isTargeted ? 2 : 1, dash: [6, 4])
                )
        )
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            let lock = NSLock()
            nonisolated(unsafe) var collected: [URL] = []
            let group = DispatchGroup()
            
            for provider in providers {
                group.enter()
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url = url {
                        lock.lock()
                        collected.append(url)
                        lock.unlock()
                    }
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                lock.lock()
                let result = collected
                lock.unlock()
                let accepted = result.filter(isAllowed)
                let rejected = result.filter { !isAllowed($0) }
                rejectedMessage = rejected.isEmpty ? nil : "Skipped unsupported file\(rejected.count == 1 ? "" : "s"): " + rejected.map(\.lastPathComponent).joined(separator: ", ")
                if !accepted.isEmpty {
                    onFilesSelected(allowsMultiple ? accepted : Array(accepted.prefix(1)))
                }
            }
            return true
        }
    }

    private func isAllowed(_ url: URL) -> Bool {
        Self.accepts(url, allowedTypes: allowedTypes)
    }

    static func accepts(_ url: URL, allowedTypes: [UTType]) -> Bool {
        if allowedTypes.contains(.item) || allowedTypes.isEmpty { return true }
        let type = (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType
            ?? UTType(filenameExtension: url.pathExtension)
        guard let type else { return false }
        return allowedTypes.contains { type.conforms(to: $0) }
    }
    
    private func openFileDialog() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = allowsMultiple
        openPanel.allowedContentTypes = allowedTypes
        openPanel.prompt = "Select"
        
        if openPanel.runModal() == .OK {
            rejectedMessage = nil
            onFilesSelected(openPanel.urls)
        }
    }
}
