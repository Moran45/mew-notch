//
//  ClaudeView.swift
//  MewNotch
//

import SwiftUI

/// Claude tab of the expanded notch: the running Claude Code sessions, with a
/// click to bring a session's terminal to the front.
struct ClaudeView: View {

    @ObservedObject var notchViewModel: NotchViewModel
    @StateObject private var monitor = ClaudeActivityMonitor.shared

    /// Feedback shown after a focus attempt that could not select the exact tab.
    @State private var focusNotice: String?
    @State private var focusNoticeIsError = false
    @State private var noticeDismissTask: Task<Void, Never>?

    /// The notch is short, so only the first few sessions are rendered.
    private let maxVisibleSessions = 3

    /// Breathing room above the first row and below the last one. Without it
    /// the bottom row sits flush against the edge of the notch.
    private let verticalPadding: CGFloat = 6

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private var visibleSessions: [ClaudeSession] {
        Array(monitor.sessions.prefix(maxVisibleSessions))
    }

    private var contentWidth: CGFloat {
        max(notchViewModel.notchSize.width * 1.55, 300)
    }

    private var contentHeight: CGFloat {
        notchViewModel.notchSize.height * 3
    }

    var body: some View {
        VStack(spacing: 5) {
            if visibleSessions.isEmpty {
                emptyState
            } else {
                ForEach(visibleSessions) { session in
                    sessionRow(session)
                }
            }

            if let focusNotice {
                Text(focusNotice)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(focusNoticeIsError ? .orange : .white.opacity(0.55))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .transition(.opacity)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, verticalPadding)
        .frame(width: contentWidth)
        // minHeight rather than a fixed height: the reserved size is kept when
        // there are few rows, but a full list is never clipped.
        .frame(minHeight: contentHeight, alignment: .top)
        .onAppear { monitor.start() }
        .onDisappear {
            monitor.stop()
            noticeDismissTask?.cancel()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 4) {
            Image(systemName: "asterisk")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.35))

            Text("No Claude sessions")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func sessionRow(_ session: ClaudeSession) -> some View {
        Button {
            focus(session)
        } label: {
            HStack(spacing: 8) {
                statusIndicator(for: session)

                VStack(alignment: .leading, spacing: 1) {
                    Text(session.displayName)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(session.isLive ? 0.92 : 0.55))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(subtitle(for: session))
                        .font(.system(size: 9, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 4)

                Text(
                    Self.relativeFormatter.localizedString(
                        for: session.lastActivity,
                        relativeTo: Date()
                    )
                )
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
                .fixedSize()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(session.isLive ? 0.08 : 0.04))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(session.isLive ? 0.14 : 0.07), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
        .disabled(!session.isLive)
        .help(session.isLive ? "Bring this session's terminal to the front" : "Session has ended")
    }

    private func statusIndicator(for session: ClaudeSession) -> some View {
        Circle()
            .fill(color(for: session))
            .frame(width: 8, height: 8)
            .overlay {
                Circle().stroke(Color.white.opacity(0.25), lineWidth: 1)
            }
    }

    private func color(for session: ClaudeSession) -> Color {
        switch session.status {
        case .working: return .orange
        case .waiting: return .green
        case .ended, .unknown: return .gray
        }
    }

    private func subtitle(for session: ClaudeSession) -> String {
        var parts: [String] = []

        if let detail = session.detailName {
            parts.append(detail)
        } else {
            parts.append(session.projectName)
            if let branch = session.gitBranch, !branch.isEmpty {
                parts.append(branch)
            }
        }

        return parts.joined(separator: " · ")
    }

    // MARK: - Focus

    private func focus(_ session: ClaudeSession) {
        switch ClaudeSessionFocusService.focus(session) {
        case .focusedTab:
            show(notice: nil, isError: false)

        case .focusedApp(let app):
            // The host cannot address individual terminals from outside, so the
            // user still has to pick the tab themselves.
            show(notice: "Opened \(app) — select the tab yourself", isError: false)

        case .failed(let reason):
            show(notice: reason, isError: true)
        }
    }

    private func show(notice: String?, isError: Bool) {
        noticeDismissTask?.cancel()

        withAnimation(.easeOut(duration: 0.15)) {
            focusNotice = notice
            focusNoticeIsError = isError
        }

        guard notice != nil else { return }

        noticeDismissTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(.easeOut(duration: 0.15)) { focusNotice = nil }
            }
        }
    }
}
