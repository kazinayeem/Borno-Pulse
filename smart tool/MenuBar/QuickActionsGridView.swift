//
//  QuickActionsGridView.swift
//  Borno Pulse
//
//  Responsive, native macOS icon grid for system quick actions.
//  Compact spacing, consistent rounded icon badges, state feedback,
//  confirmation dialogs, and customizable action selection.
//

import AppKit
import SwiftUI

public struct QuickActionsGridView: View {
    @ObservedObject var registry = QuickActionRegistry.shared
    @ObservedObject var awakeService = KeepAwakeService.shared
    @ObservedObject var settings = AppSettings.shared

    public var onOpenDashboard: () -> Void
    public var onQuickCleanup: () -> Void

    @State private var feedbackMessage: String? = nil
    @State private var isFeedbackWarning: Bool = false
    @State private var feedbackTimer: Timer? = nil

    @State private var pendingConfirmationAction: QuickActionItem? = nil
    @State private var showCustomizationSheet: Bool = false

    public init(
        onOpenDashboard: @escaping () -> Void = {},
        onQuickCleanup: @escaping () -> Void = {}
    ) {
        self.onOpenDashboard = onOpenDashboard
        self.onQuickCleanup = onQuickCleanup
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Header with title and customization shortcut
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.electricBlue)
                    Text("Quick System Actions")
                        .font(AppTypography.font(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                }

                Spacer()

                if awakeService.isActive {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 5, height: 5)
                        Text("Awake Active")
                            .font(AppTypography.font(size: 9, weight: .bold))
                            .foregroundStyle(Color.orange)
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(Capsule())
                }

                Button {
                    showCustomizationSheet = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 10.5))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(width: 18, height: 18)
                        .background(AppTheme.subtleFill)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Customize Quick Actions")
            }

            // Real-time Action Feedback Banner
            if let feedback = feedbackMessage {
                HStack(spacing: 6) {
                    Image(systemName: isFeedbackWarning ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(isFeedbackWarning ? AppTheme.warningAmber : AppTheme.successGreen)
                    Text(feedback)
                        .font(AppTypography.font(size: 9.5, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4.5)
                .background((isFeedbackWarning ? AppTheme.warningAmber : AppTheme.successGreen).opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            // 4-Column Responsive Icon Grid
            let actions = registry.activeOrderedActions
            if actions.isEmpty {
                VStack(spacing: 6) {
                    Text("No Quick Actions Enabled")
                        .font(AppTypography.font(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    Button("Restore Default Actions") {
                        registry.resetToDefaults()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 6),
                        GridItem(.flexible(), spacing: 6),
                        GridItem(.flexible(), spacing: 6),
                        GridItem(.flexible(), spacing: 6)
                    ],
                    spacing: 8
                ) {
                    ForEach(actions) { action in
                        actionGridCell(action)
                    }
                }
            }
        }
        .confirmationDialog(
            pendingConfirmationAction?.confirmationTitle ?? "Confirm Action",
            isPresented: Binding(
                get: { pendingConfirmationAction != nil },
                set: { if !$0 { pendingConfirmationAction = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let item = pendingConfirmationAction {
                if item.id == .emptyTrash {
                    Button("Open Trash in Finder") {
                        if let trashURL = FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first {
                            NSWorkspace.shared.open(trashURL)
                        }
                        pendingConfirmationAction = nil
                    }
                    Button("Empty Trash Permanently", role: .destructive) {
                        Task {
                            await runAction(item)
                        }
                        pendingConfirmationAction = nil
                    }
                } else {
                    Button(item.title, role: .destructive) {
                        Task {
                            await runAction(item)
                        }
                        pendingConfirmationAction = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    pendingConfirmationAction = nil
                }
            }
        } message: {
            if let msg = pendingConfirmationAction?.confirmationMessage {
                Text(msg)
            }
        }
        .sheet(isPresented: $showCustomizationSheet) {
            QuickActionsCustomizerSheet(
                registry: registry,
                onDismiss: { showCustomizationSheet = false }
            )
        }
    }

    // MARK: - Action Grid Cell
    private func actionGridCell(_ action: QuickActionItem) -> some View {
        let isActive = registry.isActionActive(action.id)

        return Button {
            handleActionClick(action)
        } label: {
            VStack(spacing: 4.5) {
                // Icon Badge
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(badgeBackground(for: action, isActive: isActive))
                        .frame(width: 38, height: 38)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(badgeBorder(for: action, isActive: isActive), lineWidth: 0.6)
                        )

                    Image(systemName: action.icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(iconColor(for: action, isActive: isActive))
                        .frame(width: 38, height: 38, alignment: .center)

                    // Active dot indicator
                    if isActive {
                        Circle()
                            .fill(action.id == .keepAwake ? Color.orange : AppTheme.electricBlue)
                            .frame(width: 6, height: 6)
                            .offset(x: -3, y: 3)
                            .shadow(color: (action.id == .keepAwake ? Color.orange : AppTheme.electricBlue).opacity(0.6), radius: 2)
                    }
                }

                // Short, readable label (max 2 lines)
                Text(action.title)
                    .font(AppTypography.font(size: 9.5, weight: isActive ? .semibold : .medium))
                    .foregroundStyle(action.isSupported ? AppTheme.textPrimary : AppTheme.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .frame(height: 24, alignment: .top)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(action.unsupportedReason ?? action.description)
        .accessibilityLabel(action.title)
        .opacity(action.isSupported ? 1.0 : 0.65)
    }

    private func handleActionClick(_ action: QuickActionItem) {
        if action.requiresConfirmation {
            pendingConfirmationAction = action
        } else {
            Task {
                await runAction(action)
            }
        }
    }

    private func runAction(_ action: QuickActionItem) async {
        let result = await registry.execute(
            action.id,
            onOpenDashboard: onOpenDashboard,
            onQuickCleanup: onQuickCleanup
        )

        withAnimation(.easeInOut(duration: 0.15)) {
            feedbackMessage = result.message
            isFeedbackWarning = result.isWarning
        }

        feedbackTimer?.invalidate()
        feedbackTimer = Timer.scheduledTimer(withTimeInterval: 2.8, repeats: false) { _ in
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.2)) {
                    feedbackMessage = nil
                }
            }
        }
    }

    // MARK: - Color Tokens
    private func badgeBackground(for action: QuickActionItem, isActive: Bool) -> Color {
        if isActive {
            if action.id == .keepAwake {
                return Color.orange.opacity(0.18)
            }
            return AppTheme.electricBlue.opacity(0.18)
        }
        if !action.isSupported {
            return AppTheme.cardBackgroundSecondary.opacity(0.5)
        }
        return AppTheme.cardBackgroundSecondary
    }

    private func badgeBorder(for action: QuickActionItem, isActive: Bool) -> Color {
        if isActive {
            return action.id == .keepAwake ? Color.orange.opacity(0.4) : AppTheme.electricBlue.opacity(0.4)
        }
        return AppTheme.cardBorder
    }

    private func iconColor(for action: QuickActionItem, isActive: Bool) -> Color {
        if isActive {
            return action.id == .keepAwake ? Color.orange : AppTheme.electricBlue
        }
        if !action.isSupported {
            return AppTheme.textTertiary
        }
        switch action.category {
        case .display: return AppTheme.electricBlue
        case .system: return AppTheme.purpleAccent
        case .cleanup: return AppTheme.electricCyan
        case .tools: return AppTheme.successGreen
        }
    }
}

// MARK: - Quick Actions Customizer Sheet
private struct QuickActionsCustomizerSheet: View {
    @ObservedObject var registry: QuickActionRegistry
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Sheet Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Customize Quick Actions")
                        .font(AppTypography.font(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Select which actions appear in the menu bar widget.")
                        .font(AppTypography.font(size: 10))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                Spacer()
                Button("Done") {
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(14)
            .background(AppTheme.cardBackgroundSecondary)

            Divider().opacity(0.15)

            // Actions List with Toggles & Reorder
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(registry.actionOrder) { id in
                        if let item = registry.action(for: id) {
                            let isEnabled = registry.enabledActionIds.contains(id)
                            HStack(spacing: 8) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 13))
                                    .foregroundStyle(isEnabled ? AppTheme.electricBlue : AppTheme.textTertiary)
                                    .frame(width: 22)

                                VStack(alignment: .leading, spacing: 1) {
                                    HStack(spacing: 4) {
                                        Text(item.title)
                                            .font(AppTypography.font(size: 11, weight: .semibold))
                                            .foregroundStyle(AppTheme.textPrimary)
                                        if !item.isSupported {
                                            Text("Guide")
                                                .font(AppTypography.font(size: 8, weight: .bold))
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(AppTheme.warningAmber.opacity(0.12))
                                                .foregroundStyle(AppTheme.warningAmber)
                                                .clipShape(Capsule())
                                        }
                                    }
                                    Text(item.description)
                                        .font(AppTypography.font(size: 9))
                                        .foregroundStyle(AppTheme.textTertiary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                // Move Up / Down
                                Button {
                                    moveAction(id: id, direction: -1)
                                } label: {
                                    Image(systemName: "arrow.up")
                                        .font(.system(size: 9))
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                .buttonStyle(.plain)
                                .disabled(registry.actionOrder.first == id)

                                Button {
                                    moveAction(id: id, direction: 1)
                                } label: {
                                    Image(systemName: "arrow.down")
                                        .font(.system(size: 9))
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                .buttonStyle(.plain)
                                .disabled(registry.actionOrder.last == id)

                                // Toggle Button
                                Toggle("", isOn: Binding(
                                    get: { isEnabled },
                                    set: { val in
                                        if val {
                                            if !registry.enabledActionIds.contains(id) {
                                                registry.enabledActionIds.append(id)
                                            }
                                        } else {
                                            registry.enabledActionIds.removeAll { $0 == id }
                                        }
                                    }
                                ))
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.mini)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppTheme.cardBackgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 0.5))
                        }
                    }
                }
                .padding(12)
            }
            .frame(height: 280)

            Divider().opacity(0.15)

            // Sheet Footer (Restore Defaults)
            HStack {
                Button("Restore Defaults") {
                    registry.resetToDefaults()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Text("\(registry.enabledActionIds.count) of \(QuickActionId.allCases.count) Active")
                    .font(AppTypography.font(size: 10))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .padding(12)
            .background(AppTheme.cardBackgroundSecondary)
        }
        .frame(width: 380)
    }

    private func moveAction(id: QuickActionId, direction: Int) {
        guard let idx = registry.actionOrder.firstIndex(of: id) else { return }
        let newIdx = idx + direction
        guard newIdx >= 0 && newIdx < registry.actionOrder.count else { return }
        var updated = registry.actionOrder
        updated.swapAt(idx, newIdx)
        registry.actionOrder = updated
    }
}
