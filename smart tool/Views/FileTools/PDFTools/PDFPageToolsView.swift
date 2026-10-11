//
//  PDFPageToolsView.swift
//  Naem Smart Tool
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

public struct PDFPageToolsView: View {
    @ObservedObject var service = PDFPageToolsService.shared
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("PDF Page Organizer & Manipulator")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Rotate, reorder, and remove pages from a PDF document to generate an optimized copy without touching the original")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                // Drop Zone
                FileDropZoneView(
                    title: "Select or Drop PDF to Organize",
                    subtitle: "PDF documents with one or more pages",
                    icon: "square.stack.3d.up.fill",
                    allowedTypes: [.pdf]
                ) { urls in
                    if let first = urls.first {
                        service.loadDocument(url: first)
                    }
                }
                
                if let doc = service.document, let url = service.sourceURL {
                    // Document Overview & Page Controls
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(url.lastPathComponent)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text("Total Pages: \(doc.pageCount) • Selected: \(service.selectedPageIndices.count) • Deleted: \(service.deletedPageIndices.count)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                            
                            Spacer()
                            
                            // Batch Selection Buttons
                            Button("Select All") {
                                service.selectedPageIndices = Set(0..<doc.pageCount)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            
                            Button("Deselect All") {
                                service.selectedPageIndices.removeAll()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        
                        Divider()
                        
                        // Action Toolbar
                        HStack(spacing: 12) {
                            Button {
                                service.rotateSelectedPages(degrees: 90)
                            } label: {
                                Label("Rotate 90° Clockwise", systemImage: "rotate.right")
                            }
                            .buttonStyle(.bordered)
                            
                            Button {
                                service.deleteSelectedPages()
                            } label: {
                                Label("Remove Page(s)", systemImage: "trash")
                            }
                            .buttonStyle(.bordered)
                            .disabled(service.selectedPageIndices.isEmpty)
                            
                            if !service.deletedPageIndices.isEmpty {
                                Button("Restore Removed Pages") {
                                    service.restoreDeletedPages()
                                }
                                .buttonStyle(.bordered)
                                .foregroundStyle(AppTheme.matrixGreen)
                            }
                            
                            Spacer()
                            
                            Button {
                                _ = service.exportModifiedDocument()
                            } label: {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Export Modified Copy")
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(AppTheme.electricBlue)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .smartCard()
                    
                    // Grid of Pages
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Page Grid")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 14)], spacing: 14) {
                            ForEach(0..<doc.pageCount, id: \.self) { pageIndex in
                                pageCard(for: pageIndex)
                            }
                        }
                    }
                    .smartCard()
                }
                
                // Status message
                Text(service.statusMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(24)
        }
    }
    
    @ViewBuilder
    private func pageCard(for pageIndex: Int) -> some View {
        let isSelected = service.selectedPageIndices.contains(pageIndex)
        let isDeleted = service.deletedPageIndices.contains(pageIndex)
        let rotation = service.pageRotations[pageIndex] ?? 0
        
        Button {
            if isSelected {
                service.selectedPageIndices.remove(pageIndex)
            } else {
                service.selectedPageIndices.insert(pageIndex)
            }
        } label: {
            VStack(spacing: 8) {
                // Page visual indicator
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isDeleted ? AppTheme.dangerRed.opacity(0.15) : Color.white.opacity(0.06))
                        .aspectRatio(0.75, contentMode: .fit)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(
                                    isDeleted ? AppTheme.dangerRed :
                                    isSelected ? AppTheme.electricBlue : Color.white.opacity(0.12),
                                    lineWidth: isSelected ? 2 : 1
                                )
                        )
                    
                    VStack(spacing: 4) {
                        Image(systemName: isDeleted ? "xmark.bin.fill" : "doc.text")
                            .font(.system(size: 26))
                            .foregroundStyle(isDeleted ? AppTheme.dangerRed : (isSelected ? AppTheme.electricBlue : AppTheme.textSecondary))
                            .rotationEffect(.degrees(Double(rotation)))
                            .animation(.spring(response: 0.3), value: rotation)
                        
                        if rotation != 0 {
                            Text("\(rotation)°")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(AppTheme.neonCyan)
                        }
                    }
                }
                
                HStack {
                    Text("Page \(pageIndex + 1)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isDeleted ? AppTheme.dangerRed : AppTheme.textPrimary)
                    
                    Spacer()
                    
                    if isDeleted {
                        Text("DELETED")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(AppTheme.dangerRed)
                    } else if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.electricBlue)
                    }
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.02))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
