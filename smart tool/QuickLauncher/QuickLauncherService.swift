//
//  QuickLauncherService.swift
//  Borno Pulse
//

import Foundation

public final class QuickLauncherService: Sendable {
    public static let shared = QuickLauncherService()
    
    private init() {}
    
    public var allItems: [QuickLauncherItem] {
        [
            // Hardware
            QuickLauncherItem(id: "overview", title: "System Overview", subtitle: "Real-time hardware status & sparklines", icon: "square.grid.2x2.fill", category: "Hardware", section: .overview, keywords: ["hardware", "mac", "specs", "dashboard"]),
            QuickLauncherItem(id: "cpu", title: "CPU & Core Metrics", subtitle: "Per-core utilization, architecture & frequency", icon: "cpu", category: "Hardware", section: .cpu, keywords: ["processor", "m1", "m2", "m3", "m4", "intel", "load"]),
            QuickLauncherItem(id: "gpu", title: "GPU & Neural Engine", subtitle: "Metal capabilities, ANE status, GPU memory", icon: "circle.grid.cross.fill", category: "Hardware", section: .gpu, keywords: ["graphics", "metal", "apple silicon", "render"]),
            QuickLauncherItem(id: "memory", title: "Memory & Swap Pressure", subtitle: "RAM breakdown, wired memory, pageouts", icon: "memorychip.fill", category: "Hardware", section: .memory, keywords: ["ram", "swap", "pressure"]),
            QuickLauncherItem(id: "sensors", title: "Temperature & Thermal State", subtitle: "Thermal envelope & throttling audit", icon: "thermometer.medium", category: "Hardware", section: .sensors, keywords: ["fans", "heat", "thermal", "throttle"]),
            QuickLauncherItem(id: "storage", title: "Storage Volumes", subtitle: "APFS capacity, mount points & purgeable space", icon: "internaldrive.fill", category: "Hardware", section: .storage, keywords: ["disk", "ssd", "apfs", "drive"]),
            QuickLauncherItem(id: "network", title: "Network Telemetry", subtitle: "Interface throughput, upload & download speeds", icon: "network", category: "Hardware", section: .network, keywords: ["bandwidth", "speed", "traffic"]),
            QuickLauncherItem(id: "battery", title: "Battery Health & Power", subtitle: "Cycle count, temperature, charging state", icon: "battery.100.bolt", category: "Hardware", section: .battery, keywords: ["cycles", "power", "health", "adapter"]),
            
            // File & Batch Tools
            QuickLauncherItem(id: "pdf_studio", title: "PDF Studio", subtitle: "All-in-one local PDF editor, merger, OCR & Office converter", icon: "doc.richtext.fill", category: "Utilities", section: .pdfStudio, keywords: ["pdf", "studio", "editor", "merge", "ocr", "annotate", "word", "sign", "split", "extract", "compress"]),
            QuickLauncherItem(id: "batch", title: "Batch File Converter", subtitle: "Unified batch queue for images & PDFs", icon: "arrow.triangle.2.circlepath", category: "Utilities", section: .batchConverter, keywords: ["convert", "png", "jpg", "heic", "webp", "pdf", "queue"]),
            QuickLauncherItem(id: "filetools", title: "File Tools Hub", subtitle: "Standalone image, PDF, and checksum utilities", icon: "folder.badge.gearshape", category: "Utilities", section: .fileTools, keywords: ["pdf", "image", "resizer", "compressor"]),
            
            // Developer & Network
            QuickLauncherItem(id: "port_manager", title: "Port Manager", subtitle: "Inspect listening ports, recognize dev servers & stop processes", icon: "server.rack", category: "Developer", section: .portManager, keywords: ["port", "ports", "lsof", "listen", "tcp", "server", "vite", "next", "react", "kill", "conflict", "docker"]),
            QuickLauncherItem(id: "dev_json", title: "Developer Toolbox: JSON", subtitle: "Formatter, minifier, tree explorer & diff", icon: "curlybraces", category: "Developer", section: .developerToolbox, keywords: ["json", "pretty", "minify", "tree", "diff", "csv"]),
            QuickLauncherItem(id: "dev_jwt", title: "Developer Toolbox: JWT Inspector", subtitle: "Inspect claims, header, payload & expiration", icon: "key.horizontal.fill", category: "Developer", section: .developerToolbox, keywords: ["jwt", "token", "claims", "bearer", "auth"]),
            QuickLauncherItem(id: "dev_api", title: "API Request Tester", subtitle: "Lightweight HTTP client with secret redaction", icon: "paperplane.fill", category: "Developer", section: .developerToolbox, keywords: ["api", "http", "curl", "postman", "get", "post"]),
            QuickLauncherItem(id: "dev_docker", title: "Docker Dashboard", subtitle: "Containers, images, stats and logs", icon: "shippingbox.fill", category: "Developer", section: .developerToolbox, keywords: ["docker", "container", "daemon"]),
            QuickLauncherItem(id: "net_ping", title: "Network Toolkit: Ping", subtitle: "Latency measurement & packet loss test", icon: "waveform.path.ecg", category: "Network", section: .networkToolkit, keywords: ["ping", "latency", "rtt", "icmp"]),
            QuickLauncherItem(id: "net_dns", title: "Network Toolkit: DNS Lookup", subtitle: "A, AAAA, MX, CNAME, TXT records query", icon: "magnifyingglass", category: "Network", section: .networkToolkit, keywords: ["dns", "dig", "domain", "resolve"]),
            QuickLauncherItem(id: "net_ssl", title: "Network Toolkit: SSL Certificate", subtitle: "TLS certificate chain & expiry inspector", icon: "lock.shield.fill", category: "Network", section: .networkToolkit, keywords: ["ssl", "tls", "https", "certificate", "x509"]),
            
            // Productivity & Privacy
            QuickLauncherItem(id: "clipboard", title: "Clipboard Manager", subtitle: "Opt-in clipboard history with secret protection", icon: "doc.on.clipboard", category: "Productivity", section: .clipboard, keywords: ["paste", "copy", "snippets", "history"]),
            QuickLauncherItem(id: "focus", title: "Focus & Pomodoro Timer", subtitle: "25m focus blocks, break cycles & streaks", icon: "timer", category: "Productivity", section: .focusPomodoro, keywords: ["pomodoro", "timer", "focus", "work", "break"]),
            QuickLauncherItem(id: "privacy", title: "Privacy & File Hasher", subtitle: "Streaming SHA-256, SHA-512, metadata & TCC audit", icon: "shield.lefthalf.filled", category: "Security", section: .privacySecurity, keywords: ["hash", "sha256", "checksum", "metadata", "permissions"]),
            QuickLauncherItem(id: "backup", title: "Local Backup Helper", subtitle: "Folder profiles, full/incremental/mirror & restore", icon: "externaldrive.badge.timemachine", category: "Backup", section: .localBackup, keywords: ["backup", "sync", "mirror", "restore", "archive"]),
            
            // System Utilities
            QuickLauncherItem(id: "storage_analytics", title: "Storage Analytics", subtitle: "Interactive squarified treemap & disk breakdown", icon: "chart.pie.fill", category: "System", section: .storageAnalytics, keywords: ["treemap", "disk space", "cleanup", "large files"]),
            QuickLauncherItem(id: "screentime", title: "Screen Time Analytics", subtitle: "Foreground focus vs idle detection & reports", icon: "clock.badge.checkmark", category: "System", section: .screenTime, keywords: ["screen time", "apps", "usage", "timeline"]),
            QuickLauncherItem(id: "cleaner", title: "Safe Cache Cleaner", subtitle: "Two-step review and purge of junk caches", icon: "sparkles", category: "System", section: .cleaner, keywords: ["clean", "cache", "junk", "purge", "trash"]),
            QuickLauncherItem(id: "diagnostics", title: "System Diagnostics", subtitle: "Hardware audit & in-app invariant test runner", icon: "waveform.path.ecg.rectangle", category: "System", section: .diagnostics, keywords: ["test", "diagnostics", "audit", "specs"])
        ]
    }
    
    public func search(query: String) -> [QuickLauncherItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return allItems }
        
        return allItems.filter { item in
            item.title.lowercased().contains(trimmed) ||
            item.subtitle.lowercased().contains(trimmed) ||
            item.category.lowercased().contains(trimmed) ||
            item.keywords.contains(where: { $0.contains(trimmed) })
        }
    }
}
