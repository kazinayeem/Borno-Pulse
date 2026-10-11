//
//  APIRequestTesterView.swift
//  Borno Pulse
//

import AppKit
import SwiftUI

public struct APIRequestTesterView: View {
    public enum RequestTab: String, CaseIterable, Identifiable {
        case headers = "Headers"
        case params = "Params"
        case body = "Body"
        case auth = "Auth"
        
        public var id: String { rawValue }
    }
    
    @State private var urlString: String = "https://httpbin.org/get"
    @State private var method: HTTPMethod = .get
    @State private var requestTab: RequestTab = .headers
    
    @State private var headers: [HTTPHeaderItem] = [
        HTTPHeaderItem(key: "Accept", value: "application/json"),
        HTTPHeaderItem(key: "User-Agent", value: "BornoPulse/1.0 (Macintosh)")
    ]
    @State private var queryParams: [HTTPQueryParam] = []
    @State private var bodyString: String = "{\n  \"message\": \"Hello from Borno Pulse\"\n}"
    @State private var bearerToken: String = ""
    
    @State private var isLoading: Bool = false
    @State private var response: APIResponse? = nil
    @State private var errorMessage: String? = nil
    
    @State private var showingHistorySheet: Bool = false
    @State private var historyItems: [APIRequestHistoryItem] = []
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 14) {
            // Top Request Bar
            HStack(spacing: 8) {
                // Method Picker
                Picker("Method", selection: $method) {
                    ForEach(HTTPMethod.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 105)
                
                // URL Bar
                TextField("Enter URL (e.g. https://api.example.com/v1)...", text: $urlString)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .padding(7)
                    .themedInputField()
                
                // Send Button
                Button {
                    sendRequest()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: isLoading ? "arrow.triangle.2.circlepath" : "paperplane.fill")
                        Text(isLoading ? "Sending..." : "Send")
                    }
                    .frame(width: 80)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.electricBlue)
                .disabled(isLoading || urlString.trimmingCharacters(in: .whitespaces).isEmpty)
                
                // History Button
                Button {
                    historyItems = APIRequestService.shared.loadHistory()
                    showingHistorySheet = true
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .buttonStyle(.bordered)
                .help("Request History")
            }
            
            // Dual Workspace Layout
            HStack(alignment: .top, spacing: 14) {
                // Left: Request Configuration
                requestConfigPane
                    .frame(maxWidth: .infinity)
                
                // Right: Response Inspector
                responseInspectorPane
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .sheet(isPresented: $showingHistorySheet) {
            historySheetView
        }
    }
    
    // MARK: - Request Config Pane
    private var requestConfigPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Section", selection: $requestTab) {
                ForEach(RequestTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            
            switch requestTab {
            case .headers:
                headersEditorView
            case .params:
                paramsEditorView
            case .body:
                bodyEditorView
            case .auth:
                authEditorView
            }
        }
        .padding(14)
        .smartCard()
    }
    
    // MARK: - Headers Editor
    private var headersEditorView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("HTTP Headers")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Button("+ Add Header") {
                    headers.append(HTTPHeaderItem(key: "", value: ""))
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.electricCyan)
            }
            
            ScrollView {
                VStack(spacing: 6) {
                    ForEach($headers) { $item in
                        HStack(spacing: 6) {
                            Toggle("", isOn: $item.isEnabled)
                                .labelsHidden()
                                .toggleStyle(.checkbox)
                            
                            TextField("Header Name", text: $item.key)
                                .textFieldStyle(.plain)
                                .font(.system(size: 11, design: .monospaced))
                                .padding(5)
                                .themedInputField(cornerRadius: 4)
                                .frame(width: 140)
                            
                            TextField("Value", text: $item.value)
                                .textFieldStyle(.plain)
                                .font(.system(size: 11, design: .monospaced))
                                .padding(5)
                                .themedInputField(cornerRadius: 4)
                            
                            Button {
                                headers.removeAll { $0.id == item.id }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 10))
                                    .foregroundStyle(AppTheme.dangerRed)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .frame(height: 220)
        }
    }
    
    // MARK: - Params Editor
    private var paramsEditorView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Query Parameters")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Button("+ Add Param") {
                    queryParams.append(HTTPQueryParam(key: "", value: ""))
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.electricCyan)
            }
            
            ScrollView {
                VStack(spacing: 6) {
                    ForEach($queryParams) { $item in
                        HStack(spacing: 6) {
                            Toggle("", isOn: $item.isEnabled)
                                .labelsHidden()
                                .toggleStyle(.checkbox)
                            
                            TextField("Param Name", text: $item.key)
                                .textFieldStyle(.plain)
                                .font(.system(size: 11, design: .monospaced))
                                .padding(5)
                                .themedInputField(cornerRadius: 4)
                                .frame(width: 140)
                            
                            TextField("Value", text: $item.value)
                                .textFieldStyle(.plain)
                                .font(.system(size: 11, design: .monospaced))
                                .padding(5)
                                .themedInputField(cornerRadius: 4)
                            
                            Button {
                                queryParams.removeAll { $0.id == item.id }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 10))
                                    .foregroundStyle(AppTheme.dangerRed)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .frame(height: 220)
        }
    }
    
    // MARK: - Body Editor
    private var bodyEditorView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Request Payload (JSON or Plain Text)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Button("Format JSON") {
                    if let pretty = try? JSONFormatterService.shared.prettyPrint(bodyString) {
                        bodyString = pretty
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.electricCyan)
            }
            
            TextEditor(text: $bodyString)
                .font(.system(size: 11, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(height: 210)
                .themedInputField()
        }
    }
    
    // MARK: - Auth Editor
    private var authEditorView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Authorization Header Shortcut")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
            
            Text("Bearer Token:")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textTertiary)
            
            SecureField("Paste Bearer Token...", text: $bearerToken)
                .textFieldStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
                .padding(7)
                .themedInputField()
            
            Button("Apply to Headers") {
                if !bearerToken.isEmpty {
                    headers.removeAll { $0.key.lowercased() == "authorization" }
                    headers.insert(HTTPHeaderItem(key: "Authorization", value: "Bearer \(bearerToken)"), at: 0)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.purpleAccent)
            
            Spacer()
        }
        .frame(height: 230)
    }
    
    // MARK: - Response Inspector Pane
    private var responseInspectorPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Response Inspector")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                
                Spacer()
                
                if let r = response {
                    HStack(spacing: 10) {
                        // Status Badge
                        Text("\(r.statusCode) \(r.statusDescription)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(r.isSuccess ? AppTheme.successGreen : AppTheme.dangerRed)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background((r.isSuccess ? AppTheme.successGreen : AppTheme.dangerRed).opacity(0.12))
                            .clipShape(Capsule())
                        
                        // Latency
                        Text("\(Int(r.durationMillis)) ms")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(AppTheme.electricCyan)
                        
                        // Size
                        Text(Formatters.bytes(UInt64(r.byteCount)))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
            
            if let err = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.octagon.fill")
                        .foregroundStyle(AppTheme.dangerRed)
                    Text(err)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.dangerRed)
                }
                .padding(10)
                .background(AppTheme.dangerRed.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            if let r = response {
                TextEditor(text: .constant(r.formattedBody))
                    .font(.system(size: 11, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(height: 240)
                    .themedInputField()
            } else if !isLoading {
                VStack(spacing: 8) {
                    Image(systemName: "network")
                        .font(.system(size: 28))
                        .foregroundStyle(AppTheme.textTertiary)
                    Text("Click 'Send' to dispatch request and inspect headers, status, and payload.")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .frame(maxWidth: .infinity, minHeight: 240)
            }
        }
        .padding(14)
        .smartCard()
    }
    
    // MARK: - History Sheet
    private var historySheetView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Recent API Requests")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Button("Clear History") {
                    APIRequestService.shared.clearHistory()
                    historyItems.removeAll()
                }
                .buttonStyle(.bordered)
                Button("Close") {
                    showingHistorySheet = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
            .background(AppTheme.cardBackgroundSecondary)
            
            Divider()
            
            ScrollView {
                VStack(spacing: 4) {
                    if historyItems.isEmpty {
                        Text("No request history recorded yet.")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textTertiary)
                            .padding(20)
                    } else {
                        ForEach(historyItems) { item in
                            Button {
                                urlString = item.urlString
                                method = item.method
                                showingHistorySheet = false
                            } label: {
                                HStack {
                                    Text(item.method.rawValue)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(AppTheme.electricCyan)
                                        .frame(width: 45, alignment: .leading)
                                    
                                    Text(item.urlString)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(AppTheme.textPrimary)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    Text("\(item.statusCode)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(item.statusCode < 400 ? AppTheme.successGreen : AppTheme.dangerRed)
                                    
                                    Text("\(Int(item.durationMillis))ms")
                                        .font(.system(size: 10))
                                        .foregroundStyle(AppTheme.textTertiary)
                                }
                                .padding(8)
                                .background(AppTheme.subtleFill)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(14)
            }
        }
        .frame(width: 520, height: 400)
    }
    
    private func sendRequest() {
        isLoading = true
        errorMessage = nil
        response = nil
        
        Task {
            do {
                let res = try await APIRequestService.shared.execute(
                    urlString: urlString,
                    method: method,
                    headers: headers,
                    queryParams: queryParams,
                    bodyString: bodyString
                )
                await MainActor.run {
                    self.response = res
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}
