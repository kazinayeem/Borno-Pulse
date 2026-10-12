//
//  AboutDeveloperView.swift
//  Borno Pulse
//
//  About dialog & Developer Profile card
//

import SwiftUI
import AppKit

public struct AboutDeveloperView: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                Text("About Borno Pulse")
                    .font(AppTypography.font(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(AppTheme.toolbarBackground)

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    // App Brand Header
                    VStack(spacing: 8) {
                        Image(systemName: "gauge.with.dots.needle.bottom.100percent")
                            .font(.system(size: 42))
                            .foregroundStyle(AppTheme.electricBlue)

                        Text("Borno Pulse")
                            .font(AppTypography.font(size: 20, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)

                        Text("Smart Mac Utilities & System Monitor • v1.3.0")
                            .font(AppTypography.font(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(.top, 10)

                    // Developer Profile Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 14) {
                            DeveloperAvatarView(size: 56)

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Mohammad Ali Nayeem")
                                    .font(AppTypography.font(size: 16, weight: .bold))
                                    .foregroundStyle(AppTheme.textPrimary)

                                Text("Software Engineer")
                                    .font(AppTypography.font(size: 13, weight: .semibold))
                                    .foregroundStyle(AppTheme.electricCyan)

                                Text("B.Sc in SWE, Daffodil International University")
                                    .font(AppTypography.font(size: 11.5))
                                    .foregroundStyle(AppTheme.textSecondary)

                                Text("Founder of BornoSoft")
                                    .font(AppTypography.font(size: 12, weight: .bold))
                                    .foregroundStyle(AppTheme.successGreen)
                            }
                        }

                        Divider()

                        Text("Engineered with Swift 6 strict concurrency, native SwiftUI, Metal, and Darwin APIs. Built for Apple Silicon and Intel Macs with a 100% offline, privacy-first architecture.")
                            .font(AppTypography.font(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineSpacing(2)

                        HStack(spacing: 12) {
                            Button {
                                if let url = URL(string: "https://bornosoft.bd") {
                                    NSWorkspace.shared.open(url)
                                }
                            } label: {
                                Label("BornoSoft Website", systemImage: "globe")
                                    .font(AppTypography.font(size: 11, weight: .medium))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.accentFill)

                            Button {
                                if let url = URL(string: "https://github.com/kazinayeem/Borno-Pulse") {
                                    NSWorkspace.shared.open(url)
                                }
                            } label: {
                                Label("GitHub Repository", systemImage: "chevron.left.forwardslash.chevron.right")
                                    .font(AppTypography.font(size: 11, weight: .medium))
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .smartCard(padding: 16)

                    // Credits & License
                    HStack {
                        Text("Free & Open Source under the MIT License • Copyright © 2026 BornoSoft")
                            .font(AppTypography.font(size: 10))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    .padding(.bottom, 8)
                }
                .padding(20)
            }
        }
        .frame(width: 480, height: 420)
        .background(AppTheme.graphiteCanvas)
    }
}

// MARK: - Reusable Developer Avatar View
public struct DeveloperAvatarView: View {
    public let size: CGFloat

    public init(size: CGFloat = 48) {
        self.size = size
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(AppTheme.electricBlue.opacity(0.12))
                .frame(width: size, height: size)

            if let img = NSImage(named: "DeveloperAvatar") ?? NSImage(contentsOfFile: "/Users/mohammadalinayeem/Project & Code/ios/smart tool/smart tool/developer_avatar.png") {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppTheme.electricBlue.opacity(0.6), lineWidth: 1.5))
                    .shadow(color: AppTheme.electricBlue.opacity(0.2), radius: 3, x: 0, y: 1)
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: size * 0.82))
                    .foregroundStyle(AppTheme.electricBlue)
            }
        }
    }
}
