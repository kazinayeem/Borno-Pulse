//
//  JSONToolsView.swift
//  Borno Pulse
//

import AppKit
import SwiftUI

public struct JSONToolsView: View {
    public enum JSONTab: String, CaseIterable, Identifiable {
        case format = "Format & Minify"
        case tree = "Tree Explorer"
        case csv = "JSON to CSV"
        case diff = "JSON Diff"
        
        public var id: String { rawValue }
    }
    
    @State private var selectedTab: JSONTab = .format
    @State private var inputJSON: String = ""
    @State private var outputText: String = ""
    @State private var statusMessage: String? = nil
    @State private var validationResult: JSONValidationResult? = nil
    @State private var indentSpaces: Int = 2
    
    // Tree Explorer state
    @State private var treeNodes: [JSONTreeNode] = []
    @State private var treeSearchText: String = ""
    @State private var expandedNodeIDs: Set<String> = []
    
    // Diff state
    @State private var diffJSONA: String = ""
    @State private var diffJSONB: String = ""
    @State private var diffResults: [JSONDiffItem] = []
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 14) {
            // Tab Selector Bar
            ViewThatFits(in: .horizontal) {
                HStack {
                    Picker("Tool", selection: $selectedTab) {
                        ForEach(JSONTab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 460)
                    
                    Spacer()
                    
                    Button {
                        loadSampleData()
                    } label: {
                        Label("Sample JSON", systemImage: "sparkles")
                    }
                    .buttonStyle(.bordered)
                    
                    Button {
                        clearAll()
                    } label: {
                        Label("Clear", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Tool", selection: $selectedTab) {
                        ForEach(JSONTab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    HStack {
                        Button {
                            loadSampleData()
                        } label: {
                            Label("Sample JSON", systemImage: "sparkles")
                        }
                        .buttonStyle(.bordered)
                        
                        Button {
                            clearAll()
                        } label: {
                            Label("Clear", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                    }
                }
            }
            
            // Tab Content
            switch selectedTab {
            case .format:
                formatAndMinifyView
            case .tree:
                treeExplorerView
            case .csv:
                jsonToCSVView
            case .diff:
                jsonDiffView
            }
        }
        .padding(16)
    }
    
    // MARK: - Format & Minify View
    private var formatAndMinifyView: some View {
        VStack(spacing: 12) {
            // Action Controls Bar
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    Picker("Indent", selection: $indentSpaces) {
                        Text("2 Spaces").tag(2)
                        Text("4 Spaces").tag(4)
                    }
                    .frame(width: 120)
                    
                    Button("Beautify / Format") {
                        formatJSON()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accentFill)
                    
                    Button("Minify (Compact)") {
                        minifyJSON()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Validate Syntax") {
                        validateJSON()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    if let val = validationResult {
                        validationIndicator(val)
                    }
                    
                    if !outputText.isEmpty {
                        copyOutputButton
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Picker("Indent", selection: $indentSpaces) {
                            Text("2 Spaces").tag(2)
                            Text("4 Spaces").tag(4)
                        }
                        .frame(width: 120)
                        
                        Button("Beautify / Format") {
                            formatJSON()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accentFill)
                        
                        Button("Minify (Compact)") {
                            minifyJSON()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Validate Syntax") {
                            validateJSON()
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    HStack(spacing: 8) {
                        if let val = validationResult {
                            validationIndicator(val)
                        }
                        Spacer()
                        if !outputText.isEmpty {
                            copyOutputButton
                        }
                    }
                }
            }
            
            // Dual Panes: Input & Output
            AdaptiveTwoColumnLayout(spacing: 12) {
                // Input Pane
                VStack(alignment: .leading, spacing: 6) {
                    Text("Input JSON")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    TextEditor(text: $inputJSON)
                        .font(.system(size: 12, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .themedInputField()
                        .frame(minHeight: 280)
                }
            } right: {
                // Output Pane
                VStack(alignment: .leading, spacing: 6) {
                    Text("Formatted Output")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    TextEditor(text: $outputText)
                        .font(.system(size: 12, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .themedInputField()
                        .frame(minHeight: 280)
                }
            }
        }
    }
    
    @ViewBuilder
    private func validationIndicator(_ val: JSONValidationResult) -> some View {
        HStack(spacing: 6) {
            Image(systemName: val.isValid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(val.isValid ? AppTheme.successGreen : AppTheme.dangerRed)
            Text(val.isValid ? "Valid JSON" : "Syntax Error (Line \(val.line ?? 1), Col \(val.column ?? 1))")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(val.isValid ? AppTheme.successGreen : AppTheme.dangerRed)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background((val.isValid ? AppTheme.successGreen : AppTheme.dangerRed).opacity(0.12))
        .clipShape(Capsule())
        .overlay(Capsule().stroke((val.isValid ? AppTheme.successGreen : AppTheme.dangerRed).opacity(0.35), lineWidth: 0.5))
    }
    
    private var copyOutputButton: some View {
        Button {
            copyToClipboard(outputText)
        } label: {
            Label("Copy Output", systemImage: "doc.on.doc")
        }
        .buttonStyle(.bordered)
    }
    
    // MARK: - Tree Explorer View
    private var treeExplorerView: some View {
        VStack(spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    Button("Parse Into Tree") {
                        parseTree()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.infoFill)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textTertiary)
                        TextField("Search keys or values...", text: $treeSearchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .themedInputField()
                    .frame(maxWidth: 300)
                    
                    Spacer()
                    
                    Button("Expand All") {
                        expandAllNodes(nodes: treeNodes)
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Collapse All") {
                        expandedNodeIDs.removeAll()
                    }
                    .buttonStyle(.bordered)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Button("Parse Into Tree") {
                            parseTree()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.infoFill)
                        
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.textTertiary)
                            TextField("Search keys or values...", text: $treeSearchText)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .themedInputField()
                    }
                    
                    HStack {
                        Button("Expand All") {
                            expandAllNodes(nodes: treeNodes)
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Collapse All") {
                            expandedNodeIDs.removeAll()
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                    }
                }
            }
            
            if treeNodes.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                        .font(.system(size: 32))
                        .foregroundStyle(AppTheme.textTertiary)
                    Text("Paste JSON in the Input editor and click 'Parse Into Tree' to explore its structure.")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 340)
                .smartCard()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(filteredTreeNodes) { node in
                            JSONTreeNodeRowView(
                                node: node,
                                depth: 0,
                                expandedNodeIDs: $expandedNodeIDs,
                                onCopy: { copyToClipboard($0) }
                            )
                        }
                    }
                    .padding(12)
                }
                .frame(minHeight: 380)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.cardBorder, lineWidth: 1))
            }
        }
    }

    
    // MARK: - JSON to CSV View
    private var jsonToCSVView: some View {
        VStack(spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    Button("Convert JSON to CSV") {
                        convertToCSV()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.successFill)
                    
                    Spacer()
                    
                    if !outputText.isEmpty {
                        Button("Export CSV File") {
                            exportCSVFile()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Copy CSV") {
                            copyToClipboard(outputText)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Button("Convert JSON to CSV") {
                        convertToCSV()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.successFill)
                    
                    if !outputText.isEmpty {
                        HStack {
                            Button("Export CSV File") {
                                exportCSVFile()
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Copy CSV") {
                                copyToClipboard(outputText)
                            }
                            .buttonStyle(.bordered)
                            
                            Spacer()
                        }
                    }
                }
            }
            
            AdaptiveTwoColumnLayout(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Source JSON Array")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    TextEditor(text: $inputJSON)
                        .font(.system(size: 12, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .themedInputField()
                        .frame(minHeight: 280)
                }
            } right: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Resulting CSV Table")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    TextEditor(text: $outputText)
                        .font(.system(size: 12, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .themedInputField()
                        .frame(minHeight: 280)
                }
            }
        }
    }
    
    // MARK: - JSON Diff View
    private var jsonDiffView: some View {
        VStack(spacing: 12) {
            HStack {
                Button("Compare JSON Documents") {
                    runDiff()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.purpleFill)
                
                Spacer()
                
                Text("\(diffResults.count) differences found")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(diffResults.isEmpty ? AppTheme.textSecondary : AppTheme.warningAmber)
            }
            
            AdaptiveTwoColumnLayout(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Document A (Original)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    TextEditor(text: $diffJSONA)
                        .font(.system(size: 12, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .themedInputField()
                        .frame(minHeight: 180)
                }
            } right: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Document B (Modified)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    TextEditor(text: $diffJSONB)
                        .font(.system(size: 12, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .themedInputField()
                        .frame(minHeight: 180)
                }
            }
            
            // Diff Results Table
            VStack(alignment: .leading, spacing: 6) {
                Text("Field-by-Field Differences")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                
                if diffResults.isEmpty {
                    Text("No differences or compare not yet run.")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textTertiary)
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .smartCard()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(diffResults) { item in
                                HStack(spacing: 8) {
                                    diffBadge(for: item.changeType)
                                    
                                    Text(item.path)
                                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    
                                    Spacer()
                                    
                                    if let old = item.oldValue {
                                        Text("Old: \(old)")
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(AppTheme.dangerRed)
                                    }
                                    
                                    if let new = item.newValue {
                                        Text("New: \(new)")
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(AppTheme.successGreen)
                                    }
                                }
                                .padding(8)
                                .background(AppTheme.cardBackgroundSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppTheme.cardBorder, lineWidth: 0.5))
                            }
                        }
                    }
                    .frame(height: 160)
                }
            }
        }
    }
    
    // MARK: - Actions
    private func formatJSON() {
        do {
            let res = try JSONFormatterService.shared.prettyPrint(inputJSON, spaces: indentSpaces)
            outputText = res
            validationResult = JSONValidationResult(isValid: true)
        } catch {
            validationResult = JSONFormatterService.shared.validate(inputJSON)
        }
    }
    
    private func minifyJSON() {
        do {
            let res = try JSONFormatterService.shared.minify(inputJSON)
            outputText = res
            validationResult = JSONValidationResult(isValid: true)
        } catch {
            validationResult = JSONFormatterService.shared.validate(inputJSON)
        }
    }
    
    private func validateJSON() {
        validationResult = JSONFormatterService.shared.validate(inputJSON)
    }
    
    private func parseTree() {
        do {
            treeNodes = try JSONFormatterService.shared.buildTree(from: inputJSON)
            expandAllNodes(nodes: treeNodes)
            validationResult = JSONValidationResult(isValid: true)
        } catch {
            validationResult = JSONFormatterService.shared.validate(inputJSON)
        }
    }
    
    private func convertToCSV() {
        do {
            outputText = try JSONFormatterService.shared.convertToCSV(inputJSON)
            validationResult = JSONValidationResult(isValid: true)
        } catch {
            outputText = "Error: \(error.localizedDescription)"
        }
    }
    
    private func runDiff() {
        do {
            diffResults = try JSONFormatterService.shared.compare(jsonA: diffJSONA, jsonB: diffJSONB)
        } catch {
            statusMessage = "Diff error: \(error.localizedDescription)"
        }
    }
    
    private func exportCSVFile() {
        let savePanel = NSSavePanel()
        savePanel.title = "Export CSV"
        savePanel.nameFieldStringValue = "Exported_Data.csv"
        savePanel.allowedContentTypes = [.commaSeparatedText]
        if savePanel.runModal() == .OK, let url = savePanel.url {
            try? outputText.write(to: url, atomically: true, encoding: .utf8)
        }
    }
    
    private func loadSampleData() {
        inputJSON = """
        [
          {
            "id": 101,
            "name": "Borno Pulse",
            "category": "System Utilities",
            "active": true,
            "version": 1.0,
            "tags": ["macOS", "SwiftUI", "Native"]
          },
          {
            "id": 102,
            "name": "Xcode Developer Suite",
            "category": "Developer Tools",
            "active": true,
            "version": 16.2,
            "tags": ["IDE", "Apple"]
          }
        ]
        """
        diffJSONA = """
        { "name": "Borno Pulse", "version": 1.0, "status": "active" }
        """
        diffJSONB = """
        { "name": "Borno Pulse", "version": 1.1, "status": "active", "pro": true }
        """
    }
    
    private func clearAll() {
        inputJSON = ""
        outputText = ""
        treeNodes.removeAll()
        diffResults.removeAll()
        validationResult = nil
    }
    
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
    
    private func expandAllNodes(nodes: [JSONTreeNode]) {
        for n in nodes {
            expandedNodeIDs.insert(n.id)
            expandAllNodes(nodes: n.children)
        }
    }
    
    private var filteredTreeNodes: [JSONTreeNode] {
        guard !treeSearchText.trimmingCharacters(in: .whitespaces).isEmpty else { return treeNodes }
        let query = treeSearchText.lowercased()
        return filterNodesRecursively(nodes: treeNodes, query: query)
    }
    
    private func filterNodesRecursively(nodes: [JSONTreeNode], query: String) -> [JSONTreeNode] {
        var results: [JSONTreeNode] = []
        for n in nodes {
            let match = n.key.lowercased().contains(query) || n.displayValue.lowercased().contains(query)
            let matchingChildren = filterNodesRecursively(nodes: n.children, query: query)
            if match || !matchingChildren.isEmpty {
                var copy = n
                copy.children = matchingChildren
                results.append(copy)
            }
        }
        return results
    }
    
    private func valueColor(for type: JSONValueType) -> Color {
        switch type {
        case .string: return AppTheme.matrixGreen
        case .number: return AppTheme.warningAmber
        case .boolean: return AppTheme.purpleAccent
        case .null: return AppTheme.textTertiary
        case .object, .array: return AppTheme.textSecondary
        }
    }
    
    private func diffBadge(for change: JSONDiffChangeType) -> some View {
        let (color, text) = {
            switch change {
            case .added: return (AppTheme.matrixGreen, "ADDED")
            case .removed: return (AppTheme.dangerRed, "REMOVED")
            case .modified: return (AppTheme.warningAmber, "MODIFIED")
            }
        }()
        return Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

// MARK: - Dedicated Tree Node Row View
public struct JSONTreeNodeRowView: View {
    public let node: JSONTreeNode
    public let depth: Int
    @Binding public var expandedNodeIDs: Set<String>
    public let onCopy: (String) -> Void
    
    public var body: some View {
        let isExpanded = expandedNodeIDs.contains(node.id)
        let hasChildren = !node.children.isEmpty
        
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                // Indent padding
                Spacer().frame(width: CGFloat(depth * 18))
                
                if hasChildren {
                    Button {
                        if isExpanded {
                            expandedNodeIDs.remove(node.id)
                        } else {
                            expandedNodeIDs.insert(node.id)
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(width: 14, height: 14)
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer().frame(width: 14)
                }
                
                // Key Label
                Text(node.key)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppTheme.electricCyan)
                
                Text(":")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AppTheme.textTertiary)
                
                // Value Label
                Text(node.displayValue)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(valueColor(for: node.type))
                    .lineLimit(1)
                
                // Type badge
                Text(node.type.rawValue)
                    .font(.system(size: 9))
                    .foregroundStyle(AppTheme.textTertiary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(AppTheme.subtleFill)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                
                Spacer()
                
                // Quick copy button
                Button {
                    onCopy(node.displayValue)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 9))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Copy value")
            }
            .padding(.vertical, 2)
            
            if isExpanded && hasChildren {
                ForEach(node.children) { child in
                    JSONTreeNodeRowView(
                        node: child,
                        depth: depth + 1,
                        expandedNodeIDs: $expandedNodeIDs,
                        onCopy: onCopy
                    )
                }
            }
        }
    }
    
    private func valueColor(for type: JSONValueType) -> Color {
        switch type {
        case .string: return AppTheme.matrixGreen
        case .number: return AppTheme.warningAmber
        case .boolean: return AppTheme.purpleAccent
        case .null: return AppTheme.textTertiary
        case .object, .array: return AppTheme.textSecondary
        }
    }
}

