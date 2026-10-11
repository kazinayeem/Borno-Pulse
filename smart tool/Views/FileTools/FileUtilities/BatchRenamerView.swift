//
//  BatchRenamerView.swift
//  Borno Pulse
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

public struct BatchRenamerView: View {
    @ObservedObject var service = BatchRenamerService.shared
    @State private var showingConfirmation = false
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Batch File Renamer")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Rename dozens or hundreds of files consistently with find/replace, prefixes, sequences, and case transformations")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                // Drop Area
                FileDropZoneView(
                    title: "Drag & Drop Files to Rename",
                    subtitle: "Supports any file types or folders",
                    icon: "pencil.and.list.clipboard",
                    allowedTypes: [.item]
                ) { urls in
                    service.addFiles(urls: urls)
                }
                
                // Rule Configuration Card
                VStack(alignment: .leading, spacing: 14) {
                    Text("Renaming Rules")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    Picker("Rule Mode", selection: $service.mode) {
                        ForEach(RenamerMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: service.mode) {
                        service.updatePreview()
                    }
                    
                    switch service.mode {
                    case .replace:
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Find Text:")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppTheme.textSecondary)
                                TextField("Text to match...", text: $service.findText)
                                    .textFieldStyle(.roundedBorder)
                                    .onChange(of: service.findText) { service.updatePreview() }
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Replace With:")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppTheme.textSecondary)
                                TextField("Replacement...", text: $service.replaceText)
                                    .textFieldStyle(.roundedBorder)
                                    .onChange(of: service.replaceText) { service.updatePreview() }
                            }
                        }
                        
                    case .prefixSuffix:
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Add Prefix:")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppTheme.textSecondary)
                                TextField("Prefix...", text: $service.prefixText)
                                    .textFieldStyle(.roundedBorder)
                                    .onChange(of: service.prefixText) { service.updatePreview() }
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Add Suffix:")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppTheme.textSecondary)
                                TextField("Suffix...", text: $service.suffixText)
                                    .textFieldStyle(.roundedBorder)
                                    .onChange(of: service.suffixText) { service.updatePreview() }
                            }
                        }
                        
                    case .sequence:
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Base Name Prefix:")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppTheme.textSecondary)
                                TextField("Item_", text: $service.sequencePrefix)
                                    .textFieldStyle(.roundedBorder)
                                    .onChange(of: service.sequencePrefix) { service.updatePreview() }
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Start Index:")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppTheme.textSecondary)
                                Stepper("\(service.sequenceStart)", value: $service.sequenceStart, in: 0...9999)
                                    .onChange(of: service.sequenceStart) { service.updatePreview() }
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Padding Digits:")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppTheme.textSecondary)
                                Stepper("\(service.sequenceDigits)", value: $service.sequenceDigits, in: 1...6)
                                    .onChange(of: service.sequenceDigits) { service.updatePreview() }
                            }
                        }
                        
                    case .casing:
                        Picker("Select Case Transformation", selection: $service.selectedCasing) {
                            ForEach(CasingMode.allCases) { c in
                                Text(c.rawValue).tag(c)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        .onChange(of: service.selectedCasing) {
                            service.updatePreview()
                        }
                    }
                }
                .smartCard()
                
                // Preview Queue
                if !service.previewItems.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Rename Preview (\(service.previewItems.count) items)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                            
                            Spacer()
                            
                            if service.previewItems.contains(where: { $0.hasCollision }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(AppTheme.dangerRed)
                                    Text("Collision detected in new names!")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(AppTheme.dangerRed)
                                }
                            }
                            
                            Button("Clear All") {
                                service.clearFiles()
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(AppTheme.dangerRed)
                            .font(.system(size: 11))
                        }
                        
                        Divider()
                        
                        ForEach(service.previewItems) { item in
                            HStack(spacing: 12) {
                                Image(systemName: "doc")
                                    .foregroundStyle(AppTheme.electricBlue)
                                
                                Text(item.originalName)
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .lineLimit(1)
                                
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 10))
                                    .foregroundStyle(AppTheme.textTertiary)
                                
                                Text(item.newName)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(item.hasCollision ? AppTheme.dangerRed : AppTheme.matrixGreen)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .lineLimit(1)
                                
                                if item.hasCollision {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundStyle(AppTheme.dangerRed)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppTheme.insetBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                    }
                    .smartCard()
                    
                    // Action Confirmation Bar
                    HStack(spacing: 16) {
                        Button {
                            showingConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Apply Rename (\(service.previewItems.count) files)")
                            }
                            .font(.system(size: 13, weight: .semibold))
                        }
                        .buttonStyle(.themedPrimary(fill: AppTheme.successFill))
                        .disabled(service.isRenaming || service.previewItems.contains(where: { $0.hasCollision }))
                        
                        Spacer()
                        
                        Text(service.statusMessage)
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
            .padding(24)
        }
        .alert("Confirm Batch Rename", isPresented: $showingConfirmation) {
            Button("Rename Files", role: .destructive) {
                _ = service.executeRename()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to rename \(service.previewItems.count) file(s)? This action moves files directly on your disk.")
        }
    }
}
