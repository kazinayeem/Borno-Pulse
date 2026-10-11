//
//  ProcessMonitorView.swift
//  Naem Smart Tool
//

import SwiftUI

public struct ProcessMonitorView: View {
    @ObservedObject var service = ProcessMonitorService.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Top Toolbar
            HStack(spacing: 12) {
                // Search Field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(AppTheme.textTertiary)
                    TextField("Search processes by name or PID...", text: $service.searchText)
                        .textFieldStyle(.plain)
                    if !service.searchText.isEmpty {
                        Button {
                            service.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                
                // Sort Picker
                Picker("Sort by", selection: $service.sortField) {
                    ForEach(ProcessSortField.allCases) { field in
                        Text(field.rawValue).tag(field)
                    }
                }
                .frame(width: 130)
                
                // Sort Order Toggle
                Button {
                    service.sortAscending.toggle()
                } label: {
                    Image(systemName: service.sortAscending ? "arrow.up" : "arrow.down")
                }
                .help("Toggle ascending / descending order")
                
                // Refresh Button
                Button {
                    service.refreshProcesses()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(AppTheme.cardBackgroundSecondary)
            
            // Process Table Header
            HStack {
                Text("Process Name").font(.system(size: 11, weight: .bold)).foregroundStyle(AppTheme.textTertiary).frame(maxWidth: .infinity, alignment: .leading)
                Text("PID").font(.system(size: 11, weight: .bold)).foregroundStyle(AppTheme.textTertiary).frame(width: 70, alignment: .trailing)
                Text("CPU %").font(.system(size: 11, weight: .bold)).foregroundStyle(AppTheme.textTertiary).frame(width: 80, alignment: .trailing)
                Text("Memory").font(.system(size: 11, weight: .bold)).foregroundStyle(AppTheme.textTertiary).frame(width: 90, alignment: .trailing)
                Text("Threads").font(.system(size: 11, weight: .bold)).foregroundStyle(AppTheme.textTertiary).frame(width: 65, alignment: .trailing)
                Text("User").font(.system(size: 11, weight: .bold)).foregroundStyle(AppTheme.textTertiary).frame(width: 80, alignment: .leading)
                Text("Action").font(.system(size: 11, weight: .bold)).foregroundStyle(AppTheme.textTertiary).frame(width: 65, alignment: .center)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.2))
            
            // Process List
            let list = service.filteredProcesses
            if list.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "cpu")
                        .font(.system(size: 32))
                        .foregroundStyle(AppTheme.textTertiary)
                    Text("No processes match the query.")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                }
            } else {
                List(list) { process in
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: process.isCurrentProcess ? "app.badge.fill" : "gearshape.2")
                                .foregroundStyle(process.isCurrentProcess ? AppTheme.electricBlue : AppTheme.textTertiary)
                            Text(process.name)
                                .font(.system(size: 12, weight: process.isCurrentProcess ? .bold : .medium))
                                .foregroundStyle(AppTheme.textPrimary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("\(process.pid)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(width: 70, alignment: .trailing)
                        
                        Text(Formatters.percentage(process.cpuPercentage, decimals: 1))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(process.cpuPercentage > 50 ? AppTheme.dangerRed : (process.cpuPercentage > 15 ? AppTheme.warningAmber : AppTheme.textPrimary))
                            .frame(width: 80, alignment: .trailing)
                        
                        Text(Formatters.bytes(process.residentMemoryBytes))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(width: 90, alignment: .trailing)
                        
                        Text("\(process.threadCount)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(width: 65, alignment: .trailing)
                        
                        Text(process.user)
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textTertiary)
                            .lineLimit(1)
                            .frame(width: 80, alignment: .leading)
                        
                        Button {
                            service.promptTermination(for: process)
                        } label: {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.dangerRed)
                        }
                        .buttonStyle(.plain)
                        .disabled(process.isCurrentProcess)
                        .frame(width: 65, alignment: .center)
                        .help("Stop process")
                    }
                    .padding(.vertical, 3)
                }
                .listStyle(.inset)
            }
        }
        .sheet(isPresented: $service.showTerminationConfirmDialog) {
            terminationConfirmationSheet
        }
    }
    
    private var terminationConfirmationSheet: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 38))
                .foregroundStyle(AppTheme.dangerRed)
            
            Text("Terminate Process?")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            
            if let p = service.selectedProcessForTermination {
                Text("Are you sure you want to quit **\(p.name)** (PID: \(p.pid))?\n\nTerminating a process can cause unsaved data to be lost. If this is a critical system service, your Mac may become unresponsive.")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }
            
            if let errorMsg = service.terminationErrorMessage {
                Text(errorMsg)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.dangerRed)
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    service.showTerminationConfirmDialog = false
                    service.selectedProcessForTermination = nil
                    service.terminationErrorMessage = nil
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Quit (SIGTERM)") {
                    service.terminateProcess(force: false)
                }
                .buttonStyle(.bordered)
                
                Button("Force Quit (SIGKILL)") {
                    service.terminateProcess(force: true)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.dangerRed)
            }
            .padding(.top, 8)
        }
        .padding(24)
        .frame(width: 440)
    }
}
