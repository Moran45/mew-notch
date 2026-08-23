//
//  ClaudeSession.swift
//  MewNotch
//

import Foundation

/// State of a Claude Code session.
///
/// Live sessions report this themselves in `~/.claude/sessions/<pid>.json`.
/// Sessions that have exited leave only a transcript, so their state is
/// inferred from the last entry instead.
enum ClaudeSessionStatus: String, Hashable, Codable, Sendable {

    /// Claude is processing a turn.
    case working

    /// Claude is waiting on the user.
    case waiting

    /// The session is no longer running.
    case ended

    case unknown

    /// Maps the `status` field Claude Code writes for a live session.
    init(liveStatus: String) {
        switch liveStatus.lowercased() {
        case "busy", "working", "running": self = .working
        case "idle", "waiting", "ready": self = .waiting
        default: self = .unknown
        }
    }

    var label: String {
        switch self {
        case .working: return "Working"
        case .waiting: return "Waiting"
        case .ended: return "Ended"
        case .unknown: return "Unknown"
        }
    }
}

/// One Claude Code session.
struct ClaudeSession: Identifiable, Hashable, Codable, Sendable {

    /// Claude Code's session UUID, also the transcript filename.
    let id: String

    /// Process id, present only while the session is running. This is the
    /// handle used to focus the session's terminal.
    let pid: Int32?

    /// Claude Code's own name for the session, e.g. `mew-notch-b1`.
    let name: String?

    /// Absolute path of the directory Claude was invoked in.
    let projectPath: String

    /// Model-generated title, from the transcript.
    let title: String?

    let lastPrompt: String?

    let gitBranch: String?

    let status: ClaudeSessionStatus

    let lastActivity: Date

    /// Whether the session is currently running.
    var isLive: Bool { pid != nil }

    /// Best available label. Claude Code's derived name is short and stable, so
    /// it wins over the model-generated title in a space this narrow.
    var displayName: String {
        if let name, !name.isEmpty { return name }
        if let title, !title.isEmpty { return title }
        if let lastPrompt, !lastPrompt.isEmpty { return lastPrompt }
        return projectName
    }

    /// Longer label for the row subtitle.
    var detailName: String? {
        guard let title, !title.isEmpty, title != displayName else { return nil }
        return title
    }

    var projectName: String {
        URL(fileURLWithPath: projectPath).lastPathComponent
    }

    func isStale(now: Date = Date(), threshold: TimeInterval = 30 * 60) -> Bool {
        now.timeIntervalSince(lastActivity) > threshold
    }
}
