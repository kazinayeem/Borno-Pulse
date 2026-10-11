//
//  ClipboardPickerView.swift
//  Borno Pulse
//

import AppKit
import SwiftUI

struct ClipboardPickerView: View {
    @ObservedObject var model: ClipboardPickerModel
    @ObservedObject var service: ClipboardManagerService
    let onChoose: (ClipboardItem) -> Void
    let onClose: () -> Void
    let onOpenSettings: () -> Void

    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(AppTheme.cardBorder)
            content
            Divider().overlay(AppTheme.cardBorder)
            footer
        }
        .background(AppTheme.cardBackground)
        .onAppear {
            DispatchQueue.main.async { searchFocused = true }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textTertiary)
                TextField("Search clipboard history", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.textPrimary)
                    .focused($searchFocused)
                    .accessibilityLabel("Search clipboard history")
                if !model.query.isEmpty {
                    Button {
                        model.query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear search")
                    .accessibilityLabel("Clear search")
                }
                MonitoringStatusBadge(state: service.monitoringState)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .themedInputField(cornerRadius: AppTheme.Radius.medium, isFocused: searchFocused)

            HStack(spacing: 6) {
                typeChip(nil, label: "All", icon: "square.stack")
                ForEach(ClipboardContentType.allCases) { type in
                    typeChip(type, label: type.shortLabel, icon: type.icon)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 26)
        .padding(.bottom, 10)
    }

    private func typeChip(_ type: ClipboardContentType?, label: String, icon: String) -> some View {
        let selected = model.typeFilter == type
        return Button {
            model.typeFilter = type
        } label: {
            Label(label, systemImage: icon)
                .labelStyle(.titleAndIcon)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .foregroundStyle(AppTheme.selectableForeground(selected))
                .background(Capsule().fill(AppTheme.selectableFill(selected)))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if !service.isEnabled {
            stateView(
                icon: "doc.on.clipboard",
                title: "Clipboard History Is Off",
                message: "Turn it on in Settings to keep a private, on-device history of what you copy."
            ) {
                Button("Open Clipboard Settings", action: onOpenSettings)
                    .buttonStyle(.themedPrimary)
            }
        } else if !service.hasLoadedHistory {
            VStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Loading history…")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if service.items.isEmpty {
            stateView(
                icon: "tray",
                title: "Nothing Copied Yet",
                message: service.isPaused
                    ? "History is paused. Resume to record new copies."
                    : "Copy text, links, images or files and they'll appear here."
            ) { EmptyView() }
        } else {
            let results = model.results
            if results.isEmpty {
                stateView(
                    icon: "magnifyingglass",
                    title: "No Matches",
                    message: model.query.isEmpty
                        ? "No \(model.typeFilter?.shortLabel.lowercased() ?? "") items in history."
                        : "Nothing in history matches “\(model.query)”."
                ) { EmptyView() }
            } else {
                list(results)
            }
        }
    }

    private func list(_ results: [ClipboardItem]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { index, item in
                        ClipboardItemRow(
                            item: item,
                            service: service,
                            isSelected: item.id == (model.selectedID ?? results.first?.id),
                            shortcutIndex: index < 9 ? index + 1 : nil
                        )
                        .id(item.id)
                        .contentShape(Rectangle())
                        .onTapGesture { onChoose(item) }
                        .onHover { hovering in
                            if hovering { model.selectedID = item.id }
                        }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityHint("Pastes this item")
                    }
                }
                .padding(6)
            }
            .onChange(of: model.selectedID) { _, newValue in
                guard let newValue else { return }
                proxy.scrollTo(newValue)
            }
        }
    }

    private func stateView<Actions: View>(icon: String, title: String, message: String, @ViewBuilder actions: () -> Actions) -> some View {
        VStack(spacing: 12) {
            ThemedEmptyState(icon: icon, title: title, message: message)
            actions()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 6) {
            if service.isEnabled && service.autoPasteEnabled && !model.accessibilityTrusted {
                HStack(spacing: 8) {
                    Image(systemName: "hand.raised")
                        .foregroundStyle(AppTheme.warningAmber)
                    Text("Automatic paste needs Accessibility access. Until then, items are copied and you press ⌘V.")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button("Set Up…", action: onOpenSettings)
                        .controlSize(.small)
                }
            }
            if service.isEnabled && service.isPaused {
                HStack(spacing: 8) {
                    Image(systemName: "pause.circle")
                        .foregroundStyle(AppTheme.warningAmber)
                    Text("Paused — new copies aren't being recorded.")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer(minLength: 0)
                    Button("Resume") { service.resume() }
                        .controlSize(.small)
                }
            }
            HStack(spacing: 12) {
                hint("↩", "Paste")
                hint("↑↓", "Select")
                hint("⌘1–9", "Quick pick")
                hint("esc", "Close")
                Spacer(minLength: 0)
                Button {
                    onOpenSettings()
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Clipboard settings")
                .accessibilityLabel("Clipboard settings")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppTheme.toolbarBackground)
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(RoundedRectangle(cornerRadius: 4).fill(AppTheme.subtleFill))
            Text(label)
                .font(.system(size: 10))
        }
        .foregroundStyle(AppTheme.textSecondary)
    }
}

// MARK: - Shared Row

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let service: ClipboardManagerService
    var isSelected: Bool = false
    var shortcutIndex: Int?
    var compact: Bool = false

    var body: some View {
        let missingFiles = item.type == .file && !item.missingFilePaths.isEmpty
        HStack(spacing: 10) {
            ClipboardItemThumbnail(item: item, service: service, size: compact ? 26 : 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.maskedPreview)
                    .font(.system(size: compact ? 12 : 13))
                    .foregroundStyle(missingFiles ? AppTheme.textTertiary : AppTheme.textPrimary)
                    .lineLimit(compact ? 1 : 2)
                    .truncationMode(.tail)
                HStack(spacing: 4) {
                    Text(item.type.shortLabel)
                    Text("·")
                    Text(item.timestamp, format: .relative(presentation: .named))
                    if let app = item.sourceAppName, !compact {
                        Text("·")
                        Text(app).lineLimit(1)
                    }
                    if missingFiles {
                        Text("·")
                        Text("File missing").foregroundStyle(AppTheme.warningAmber)
                    }
                }
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer(minLength: 4)

            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.warningAmber)
                    .accessibilityLabel("Pinned")
            }
            if let shortcutIndex {
                Text("⌘\(shortcutIndex)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.textTertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, compact ? 4 : 6)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.small, style: .continuous)
                .fill(isSelected ? AppTheme.selectionBackground : Color.clear)
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct ClipboardItemThumbnail: View {
    let item: ClipboardItem
    let service: ClipboardManagerService
    var size: CGFloat = 36

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        Group {
            if item.type == .image, let image = service.thumbnail(for: item, maxPixelSize: Int(size * 2)) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: item.isSensitive ? "lock.fill" : item.type.icon)
                    .font(.system(size: size * 0.42))
                    .foregroundStyle(AppTheme.electricBlue)
            }
        }
        .frame(width: size, height: size)
        .background(shape.fill(AppTheme.subtleFill))
        .clipShape(shape)
        .accessibilityHidden(true)
    }
}

struct MonitoringStatusBadge: View {
    let state: ClipboardMonitoringState

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(state.label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(AppTheme.subtleFill))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Clipboard history: \(state.label)")
    }

    private var color: Color {
        switch state {
        case .monitoring: return AppTheme.successGreen
        case .paused: return AppTheme.warningAmber
        case .off: return AppTheme.textTertiary
        }
    }
}
