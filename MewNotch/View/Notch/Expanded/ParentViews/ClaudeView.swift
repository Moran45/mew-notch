//
//  ClaudeView.swift
//  MewNotch
//

import SwiftUI

/// Claude tab of the expanded notch: a live list of Claude Code sessions.
///
/// This is the macOS half of the shared activity model; the watchOS app renders
/// the same `ClaudeSession` values delivered over CloudKit.
struct ClaudeView: View {

    @ObservedObject var notchViewModel: NotchViewModel
    @StateObject private var monitor = ClaudeActivityMonitor.shared

    /// The notch cannot show a long list, so only the most recent sessions are
    /// rendered.
    private let maxVisibleSessions = 3

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private var visibleSessions: [ClaudeSession] {
        Array(monitor.sessions.prefix(maxVisibleSessions))
    }

    private var contentWidth: CGFloat {
        max(notchViewModel.notchSize.width * 1.55, 280)
    }

    private var contentHeight: CGFloat {
        notchViewModel.notchSize.height * 3
    }

    var body: some View {
        VStack(spacing: 6) {
            if visibleSessions.isEmpty {
                emptyState
            } else {
                ForEach(visibleSessions) { session in
                    sessionRow(session)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .frame(
            width: contentWidth,
            height: contentHeight,
            alignment: .top
        )
        .onAppear { monitor.start() }
        .onDisappear { monitor.stop() }
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
        HStack(spacing: 8) {
            statusIndicator(for: session)

            VStack(alignment: .leading, spacing: 1) {
                Text(session.displayName)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(subtitle(for: session))
                    .font(.system(size: 9, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
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
            .foregroundStyle(.white.opacity(0.45))
            .fixedSize()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.07))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                }
        }
    }

    @ViewBuilder
    private func statusIndicator(for session: ClaudeSession) -> some View {
        Circle()
            .fill(color(for: session))
            .frame(width: 8, height: 8)
            .overlay {
                Circle().stroke(Color.white.opacity(0.25), lineWidth: 1)
            }
    }

    private func color(for session: ClaudeSession) -> Color {
        if session.isStale() { return .gray }

        switch session.status {
        case .working: return .orange
        case .waiting: return .green
        case .unknown: return .gray
        }
    }

    private func subtitle(for session: ClaudeSession) -> String {
        var parts = [session.projectName]
        if let branch = session.gitBranch, !branch.isEmpty {
            parts.append(branch)
        }
        return parts.joined(separator: " · ")
    }
}
