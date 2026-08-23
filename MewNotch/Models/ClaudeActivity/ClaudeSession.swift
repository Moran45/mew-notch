//
//  ClaudeSession.swift
//  MewNotch
//

import Foundation

/// Derived state of a single Claude Code session.
///
/// The transcript never states a status outright, so it is inferred from the
/// last non-sidechain, non-meta entry: a `user` entry means a prompt is in
/// flight, an `assistant` entry means the turn is over and Claude is waiting.
enum ClaudeSessionStatus: String, Hashable, Codable, Sendable {

    /// A prompt was submitted and no reply has landed yet.
    case working

    /// Claude answered and is waiting on the user.
    case waiting

    /// The transcript ended without a usable signal.
    case unknown

    var label: String {
        switch self {
        case .working: return "Working"
        case .waiting: return "Waiting"
        case .unknown: return "Idle"
        }
    }
}

/// One Claude Code session, as reconstructed from its transcript on disk.
struct ClaudeSession: Identifiable, Hashable, Codable, Sendable {

    /// Claude Code's own session UUID, also the transcript filename.
    let id: String

    /// Absolute path of the directory Claude was invoked in.
    let projectPath: String

    /// Model-generated title for the session, when one has been emitted.
    let title: String?

    /// Most recent prompt text, used as a fallback label.
    let lastPrompt: String?

    let gitBranch: String?

    let status: ClaudeSessionStatus

    /// Timestamp of the last entry, used for sorting and staleness.
    let lastActivity: Date

    /// Best available human label for the session.
    var displayName: String {
        if let title, !title.isEmpty { return title }
        if let lastPrompt, !lastPrompt.isEmpty { return lastPrompt }
        return projectName
    }

    /// Trailing path component of the project directory.
    var projectName: String {
        URL(fileURLWithPath: projectPath).lastPathComponent
    }

    /// Sessions untouched for a while are treated as dormant rather than live.
    func isStale(now: Date = Date(), threshold: TimeInterval = 30 * 60) -> Bool {
        now.timeIntervalSince(lastActivity) > threshold
    }
}
