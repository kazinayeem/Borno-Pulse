//
//  NetworkToolkitView.swift
//  Borno Pulse
//

import SwiftUI

public struct NetworkToolkitView: View {
    public enum NetworkTab: String, CaseIterable, Identifiable {
        case connectivity = "Connectivity"
        case ping = "Ping"
        case dns = "DNS Lookup"
        case ssl = "SSL Certificate"
        
        public var id: String { rawValue }
        
        public var icon: String {
            switch self {
            case .connectivity: return "network"
            case .ping: return "waveform.path.ecg"
            case .dns: return "magnifyingglass"
            case .ssl: return "lock.shield.fill"
            }
        }
    }
    
    @State private var activeTab: NetworkTab = .connectivity
    
    // Connectivity State
    @State private var interfaces: [NetworkInterfaceDetail] = []
    
    // Ping State
    @State private var pingHost: String = "1.1.1.1"
    @State private var pingPackets: [PingPacket] = []
    @State private var isPinging: Bool = false
    @State private var pingTask: Task<Void, Never>? = nil
    
    // DNS State
    @State private var dnsHost: String = "apple.com"
    @State private var dnsType: DNSRecordType = .a
    @State private var dnsRecords: [DNSRecordItem] = []
    @State private var dnsDuration: Double = 0
    @State private var dnsLoading: Bool = false
    @State private var dnsError: String? = nil
    
    // SSL State
    @State private var sslHost: String = "apple.com"
    @State private var sslPort: Int = 443
    @State private var sslCert: SSLCertificateDetails? = nil
    @State private var sslLoading: Bool = false
    @State private var sslError: String? = nil
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Workspace Header Bar
            AdaptivePageHeader(
                title: "Network Toolkit",
                icon: "antenna.radiowaves.left.and.right",
                iconColor: AppTheme.electricCyan
            ) {
                // Tab Switcher
                HStack(spacing: 4) {
                    ForEach(NetworkTab.allCases) { tab in
                        Button {
                            activeTab = tab
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 11))
                                Text(tab.rawValue)
                                    .font(.system(size: 12, weight: activeTab == tab ? .semibold : .regular))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(activeTab == tab ? AppTheme.selectionBackground : Color.clear)
                            .foregroundStyle(AppTheme.selectableForeground(activeTab == tab))
                            .contentShape(RoundedRectangle(cornerRadius: 6))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.cardBorder, lineWidth: 0.5))
            }
            
            Divider()
                .background(AppTheme.cardBorder)
            
            // Tab Content
            ScrollView {
                VStack(spacing: 14) {
                    switch activeTab {
                    case .connectivity:
                        connectivityTabContent
                    case .ping:
                        pingTabContent
                    case .dns:
                        dnsTabContent
                    case .ssl:
                        sslTabContent
                    }
                }
                .padding(18)
            }
        }
        .background(AppTheme.graphiteCanvas)
        .onAppear {
            refreshInterfaces()
        }
    }
    
    // MARK: - 1. Connectivity Tab
    private var connectivityTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Reachability Banner
            let isOnline = NetworkConnectivityService.shared.isInternetReachable
            HStack(spacing: 12) {
                Image(systemName: isOnline ? "globe.americas.fill" : "globe.slash")
                    .font(.system(size: 24))
                    .foregroundStyle(isOnline ? AppTheme.successGreen : AppTheme.dangerRed)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(isOnline ? "Internet Reachable" : "Internet Disconnected")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Primary Route: \(NetworkConnectivityService.shared.currentInterfaceType)")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                Spacer()
                
                Button("Refresh Interfaces") {
                    refreshInterfaces()
                }
                .buttonStyle(.bordered)
            }
            .padding(14)
            .smartCard()
            
            // Interfaces List
            VStack(alignment: .leading, spacing: 10) {
                Text("Local Network Interfaces (\(interfaces.count))")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                
                VStack(spacing: 6) {
                    ForEach(interfaces) { iface in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(iface.isUp ? AppTheme.successGreen : AppTheme.textTertiary)
                                .frame(width: 7, height: 7)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(iface.displayName)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                
                                HStack(spacing: 8) {
                                    if let ip = iface.ipv4 {
                                        Text("IPv4: \(ip)")
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(AppTheme.electricCyan)
                                    }
                                    if let ip6 = iface.ipv6 {
                                        Text("IPv6: \(ip6)")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(AppTheme.textSecondary)
                                            .textSelection(.enabled)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            Text(iface.isUp ? "UP" : "DOWN")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(iface.isUp ? AppTheme.successGreen : AppTheme.textSecondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background((iface.isUp ? AppTheme.successGreen : AppTheme.textSecondary).opacity(0.12))
                                .clipShape(Capsule())
                        }
                        .padding(10)
                        .background(AppTheme.cardBackgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.cardBorder, lineWidth: 0.5))
                    }
                }
            }
            .padding(14)
            .smartCard()
        }
    }
    
    // MARK: - 2. Ping Tab
    private var pingTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Control Bar
            HStack(spacing: 10) {
                TextField("Destination Host or IP (e.g. 1.1.1.1, apple.com)...", text: $pingHost)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .padding(7)
                    .themedInputField()
                
                if isPinging {
                    Button("Stop Ping") {
                        stopPing()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.dangerRed)
                } else {
                    Button("Start Ping") {
                        startPing()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.electricBlue)
                    .disabled(pingHost.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            
            // Ping Statistics Ribbon
            if !pingPackets.isEmpty {
                let successPackets = pingPackets.filter { $0.isSuccess }
                let rtts = successPackets.map { $0.rttMs }
                let minRtt = rtts.min() ?? 0
                let maxRtt = rtts.max() ?? 0
                let avgRtt = rtts.isEmpty ? 0 : (rtts.reduce(0, +) / Double(rtts.count))
                let loss = pingPackets.isEmpty ? 0.0 : (Double(pingPackets.count - successPackets.count) / Double(pingPackets.count)) * 100.0
                
                AdaptiveCardGrid(minColumnWidth: 140, spacing: 10) {
                    statCard(title: "Avg Latency", value: String(format: "%.1f ms", avgRtt), tint: AppTheme.electricCyan)
                    statCard(title: "Min Latency", value: String(format: "%.1f ms", minRtt), tint: AppTheme.successGreen)
                    statCard(title: "Max Latency", value: String(format: "%.1f ms", maxRtt), tint: AppTheme.warningAmber)
                    statCard(title: "Packet Loss", value: String(format: "%.0f%%", loss), tint: loss == 0 ? AppTheme.successGreen : AppTheme.dangerRed)
                }
            }
            
            // Packets Stream Table
            VStack(alignment: .leading, spacing: 8) {
                Text("Packets Response Log")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                
                if pingPackets.isEmpty {
                    Text("Enter a host and click 'Start Ping' to measure round-trip latency.")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textTertiary)
                        .frame(maxWidth: .infinity, minHeight: 140)
                        .smartCard()
                } else {
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(pingPackets.reversed()) { pkt in
                                HStack {
                                    Text("#\(pkt.seq)")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(AppTheme.textSecondary)
                                        .frame(width: 35, alignment: .leading)
                                    
                                    Image(systemName: pkt.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(pkt.isSuccess ? AppTheme.successGreen : AppTheme.dangerRed)
                                        .font(.system(size: 11))
                                    
                                    Text(pkt.isSuccess ? "Reply from \(pingHost)" : (pkt.errorMessage ?? "Request Timeout"))
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    
                                    Spacer()
                                    
                                    if pkt.isSuccess {
                                        Text(String(format: "%.1f ms", pkt.rttMs))
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundStyle(AppTheme.electricCyan)
                                    }
                                }
                                .padding(7)
                                .background(AppTheme.cardBackgroundSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppTheme.cardBorder, lineWidth: 0.5))
                            }
                        }
                    }
                    .frame(height: 220)
                }
            }
            .padding(14)
            .smartCard()
        }
    }
    
    // MARK: - 3. DNS Tab
    private var dnsTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                TextField("Domain name (e.g. apple.com)...", text: $dnsHost)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .padding(7)
                    .themedInputField()
                
                Picker("Type", selection: $dnsType) {
                    ForEach(DNSRecordType.allCases) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 100)
                
                Button("Lookup") {
                    runDNSLookup()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.electricCyan)
                .disabled(dnsLoading || dnsHost.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            
            if dnsDuration > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .foregroundStyle(AppTheme.electricCyan)
                    Text("Resolved in \(Int(dnsDuration)) ms")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            
            if let err = dnsError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppTheme.dangerRed)
                    Text(err)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.dangerRed)
                }
                .padding(10)
                .background(AppTheme.dangerRed.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            // DNS Records Table
            VStack(alignment: .leading, spacing: 8) {
                Text("Resolved Records (\(dnsRecords.count))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                
                if dnsRecords.isEmpty {
                    Text("No DNS records resolved or search not executed.")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textTertiary)
                        .frame(maxWidth: .infinity, minHeight: 140)
                        .smartCard()
                } else {
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(dnsRecords) { r in
                                HStack {
                                    Text(r.type.rawValue)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(AppTheme.purpleAccent)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(AppTheme.purpleAccent.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 3))
                                    
                                    Text(r.name)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(AppTheme.textSecondary)
                                    
                                    Spacer()
                                    
                                    Text(r.value)
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    
                                    if let ttl = r.ttl {
                                        Text("TTL: \(ttl)s")
                                            .font(.system(size: 10))
                                            .foregroundStyle(AppTheme.textTertiary)
                                    }
                                }
                                .padding(8)
                                .background(AppTheme.cardBackgroundSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppTheme.cardBorder, lineWidth: 0.5))
                            }
                        }
                    }
                    .frame(height: 220)
                }
            }
            .padding(14)
            .smartCard()
        }
    }
    
    // MARK: - 4. SSL Tab
    private var sslTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                TextField("Hostname (e.g. apple.com)...", text: $sslHost)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .padding(7)
                    .themedInputField()
                
                Button("Inspect TLS Certificate") {
                    inspectSSL()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.matrixGreen)
                .disabled(sslLoading || sslHost.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            
            if let err = sslError {
                HStack {
                    Image(systemName: "lock.slash.fill")
                        .foregroundStyle(AppTheme.dangerRed)
                    Text(err)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.dangerRed)
                }
                .padding(10)
                .background(AppTheme.dangerRed.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            if let cert = sslCert {
                // Trust Banner
                HStack(spacing: 10) {
                    Image(systemName: cert.isTrusted && !cert.isExpired ? "checkmark.seal.fill" : "exclamationmark.shield.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(cert.isTrusted && !cert.isExpired ? AppTheme.successGreen : AppTheme.dangerRed)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cert.isTrusted && !cert.isExpired ? "Valid & Trusted TLS Certificate" : "Certificate Warning or Untrusted")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        
                        Text(cert.isExpired ? "Certificate is expired!" : (cert.isTrusted ? "Verified by macOS system root store" : "Failed system trust evaluation"))
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    if let days = cert.remainingDays {
                        Text("\(days) days left")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(days > 30 ? AppTheme.successGreen : AppTheme.warningAmber)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background((days > 30 ? AppTheme.successGreen : AppTheme.warningAmber).opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                .padding(14)
                .smartCard()
                
                // Detailed Attributes
                VStack(alignment: .leading, spacing: 8) {
                    Text("Certificate Attributes")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    VStack(spacing: 6) {
                        certRow(label: "Common Name", value: cert.commonName)
                        certRow(label: "Issuer Authority", value: cert.issuer)
                        certRow(label: "Valid From", value: cert.validFrom?.formatted(date: .long, time: .shortened) ?? "N/A")
                        certRow(label: "Valid Until", value: cert.validUntil?.formatted(date: .long, time: .shortened) ?? "N/A")
                        certRow(label: "Signature Algorithm", value: cert.signatureAlgorithm)
                        if !cert.sanDNSNames.isEmpty {
                            certRow(label: "Subject Alt Names", value: cert.sanDNSNames.prefix(4).joined(separator: ", "))
                        }
                    }
                }
                .padding(14)
                .smartCard()
            }
        }
    }
    
    // MARK: - UI Helpers
    private func statCard(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .smartCard()
    }
    
    private func certRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 140, alignment: .leading)
            
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
            
            Spacer()
        }
        .padding(.vertical, 3)
    }
    
    // MARK: - Actions
    private func refreshInterfaces() {
        interfaces = NetworkConnectivityService.shared.fetchInterfaces()
    }
    
    private func startPing() {
        isPinging = true
        pingPackets.removeAll()
        
        let host = pingHost.trimmingCharacters(in: .whitespacesAndNewlines)
        pingTask = Task {
            for await packet in PingService.shared.ping(host: host, count: 8) {
                await MainActor.run {
                    self.pingPackets.append(packet)
                }
            }
            await MainActor.run {
                self.isPinging = false
            }
        }
    }
    
    private func stopPing() {
        pingTask?.cancel()
        pingTask = nil
        isPinging = false
    }
    
    private func runDNSLookup() {
        dnsLoading = true
        dnsError = nil
        dnsRecords.removeAll()
        
        Task {
            do {
                let res = try await DNSLookupService.shared.lookup(host: dnsHost, type: dnsType)
                await MainActor.run {
                    self.dnsRecords = res.records
                    self.dnsDuration = res.durationMs
                    self.dnsLoading = false
                }
            } catch {
                await MainActor.run {
                    self.dnsError = error.localizedDescription
                    self.dnsLoading = false
                }
            }
        }
    }
    
    private func inspectSSL() {
        sslLoading = true
        sslError = nil
        sslCert = nil
        
        Task {
            do {
                let cert = try await SSLCertificateService.shared.inspect(host: sslHost, port: sslPort)
                await MainActor.run {
                    self.sslCert = cert
                    self.sslLoading = false
                }
            } catch {
                await MainActor.run {
                    self.sslError = error.localizedDescription
                    self.sslLoading = false
                }
            }
        }
    }
}
