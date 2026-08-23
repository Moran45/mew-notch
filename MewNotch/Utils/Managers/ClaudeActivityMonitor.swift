//
//  ClaudeActivityMonitor.swift
//  MewNotch
//

import Foundation
import SwiftUI

/// Publishes a live view of every Claude Code session.
///
/// Two sources are merged, because neither is complete on its own:
///
/// - `~/.claude/sessions/<pid>.json` is written by each running session and
///   carries the authoritative `status` and process id. It only exists while
///   the session is alive, and it has no conversation title.
/// - `~/.claude/projects/<slug>/<sessionId>.jsonl` is the transcript. It has the
///   title and survives the session, but reports no status, so sessions that
///   have exited are simply listed as ended.
///
/// Transcripts routinely pass a megabyte, so only their tail is read, and only
/// when the file's modification date has changed since the last pass.
final class ClaudeActivityMonitor: ObservableObject {

    static let shared = ClaudeActivityMonitor()

    /// All known sessions: running ones first, then most recently active.
    @Published private(set) var sessions: [ClaudeSession] = []

    /// Bumped whenever a running session changes state — a prompt goes out, or
    /// a reply lands. Views observe it to signal that something happened.
    ///
    /// Deliberately driven by status transitions rather than transcript writes:
    /// a transcript is appended to continuously during a turn, which would fire
    /// this every couple of seconds while Claude works.
    @Published private(set) var activityPulse: Int = 0

    /// Last seen status per running session, for detecting transitions.
    private var lastLiveStatuses: [String: ClaudeSessionStatus] = [:]

    /// Suppresses a pulse for the very first scan, so the notch does not shake
    /// simply because the app launched.
    private var hasScanned = false

    /// Data a running session reports about itself.
    private struct LiveSession: Decodable {
        let pid: Int32
        let sessionId: String
        let cwd: String
        let name: String?
        let status: String?
        let kind: String?
        let updatedAt: Double?
    }

    /// What a transcript contributes.
    private struct TranscriptInfo {
        let sessionId: String
        let projectPath: String
        let title: String?
        let lastPrompt: String?
        let gitBranch: String?
        let lastActivity: Date
    }

    private let tailByteCount = 256 * 1024

    private let claudeURL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent(".claude", isDirectory: true)

    private var projectsURL: URL { claudeURL.appendingPathComponent("projects", isDirectory: true) }
    private var sessionsURL: URL { claudeURL.appendingPathComponent("sessions", isDirectory: true) }

    private let queue = DispatchQueue(label: "com.yournotch.claude-activity", qos: .utility)

    private var timer: DispatchSourceTimer?
    private var startCount = 0

    private var parsedDates: [String: Date] = [:]
    private var cache: [String: TranscriptInfo] = [:]

    private init() {}

    // MARK: - Lifecycle

    func start(interval: TimeInterval = 2) {
        queue.async { [weak self] in
            guard let self else { return }

            self.startCount += 1
            guard self.timer == nil else { return }

            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now(), repeating: interval)
            timer.setEventHandler { [weak self] in self?.refresh() }
            self.timer = timer
            timer.resume()
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }

            self.startCount = max(0, self.startCount - 1)
            guard self.startCount == 0 else { return }

            self.timer?.cancel()
            self.timer = nil
        }
    }

    // MARK: - Scanning

    private func refresh() {
        let live = readLiveSessions()
        let transcripts = readTranscripts()

        var merged: [ClaudeSession] = []
        var claimed: Set<String> = []

        // Running sessions first: they carry a real status and can be focused.
        for session in live {
            let transcript = transcripts[session.sessionId]
            claimed.insert(session.sessionId)

            merged.append(
                ClaudeSession(
                    id: session.sessionId,
                    pid: session.pid,
                    name: session.name,
                    projectPath: session.cwd,
                    title: transcript?.title,
                    lastPrompt: transcript?.lastPrompt,
                    gitBranch: transcript?.gitBranch,
                    status: session.status.map(ClaudeSessionStatus.init(liveStatus:)) ?? .unknown,
                    lastActivity: transcript?.lastActivity
                        ?? session.updatedAt.map { Date(timeIntervalSince1970: $0 / 1000) }
                        ?? Date()
                )
            )
        }

        // Then sessions that have exited, newest first.
        let ended = transcripts.values
            .filter { !claimed.contains($0.sessionId) }
            .sorted { $0.lastActivity > $1.lastActivity }

        for transcript in ended {
            merged.append(
                ClaudeSession(
                    id: transcript.sessionId,
                    pid: nil,
                    name: nil,
                    projectPath: transcript.projectPath,
                    title: transcript.title,
                    lastPrompt: transcript.lastPrompt,
                    gitBranch: transcript.gitBranch,
                    status: .ended,
                    lastActivity: transcript.lastActivity
                )
            )
        }

        let statuses = Dictionary(
            uniqueKeysWithValues: merged.filter(\.isLive).map { ($0.id, $0.status) }
        )
        let changed = statuses.contains { lastLiveStatuses[$0.key] != $0.value }
        let shouldPulse = hasScanned && changed

        lastLiveStatuses = statuses
        hasScanned = true

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            if shouldPulse {
                self.activityPulse &+= 1
            }

            guard self.sessions != merged else { return }
            self.sessions = merged
        }
    }

    /// Reads the per-process files that running sessions maintain.
    private func readLiveSessions() -> [LiveSession] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: sessionsURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ))?.filter { $0.pathExtension == "json" } ?? []

        let decoder = JSONDecoder()

        return files
            .compactMap { url -> LiveSession? in
                guard
                    let data = try? Data(contentsOf: url),
                    let session = try? decoder.decode(LiveSession.self, from: data)
                else {
                    return nil
                }

                // A crashed session can leave its file behind, so confirm the
                // process is actually alive before offering it as focusable.
                guard kill(session.pid, 0) == 0 || errno == EPERM else { return nil }

                return session
            }
            .sorted { ($0.name ?? "") < ($1.name ?? "") }
    }

    private func readTranscripts() -> [String: TranscriptInfo] {
        let fileManager = FileManager.default

        guard let projectDirs = try? fileManager.contentsOfDirectory(
            at: projectsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return [:]
        }

        var result: [String: TranscriptInfo] = [:]
        var liveKeys: Set<String> = []

        for projectDir in projectDirs {
            let isDirectory = (try? projectDir.resourceValues(forKeys: [.isDirectoryKey]))?
                .isDirectory ?? false
            guard isDirectory else { continue }

            let transcripts = (try? fileManager.contentsOfDirectory(
                at: projectDir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ))?.filter { $0.pathExtension == "jsonl" } ?? []

            for transcript in transcripts {
                let key = transcript.path
                liveKeys.insert(key)

                let modified = (try? transcript.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? .distantPast

                if parsedDates[key] == modified, let cached = cache[key] {
                    result[cached.sessionId] = cached
                    continue
                }

                guard let info = parseTranscript(at: transcript, modified: modified) else { continue }

                parsedDates[key] = modified
                cache[key] = info
                result[info.sessionId] = info
            }
        }

        parsedDates = parsedDates.filter { liveKeys.contains($0.key) }
        cache = cache.filter { liveKeys.contains($0.key) }

        return result
    }

    // MARK: - Parsing

    private func parseTranscript(at url: URL, modified: Date) -> TranscriptInfo? {
        guard let tail = readTail(of: url) else { return nil }

        // The tail read almost always cuts the first line mid-object.
        var lines = tail.split(separator: "\n", omittingEmptySubsequences: true)
        if lines.count > 1 { lines.removeFirst() }

        var title: String?
        var lastPrompt: String?
        var gitBranch: String?
        var projectPath: String?
        for line in lines {
            guard
                let data = line.data(using: .utf8),
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                continue
            }
            switch object["type"] as? String {
            case "ai-title": title = object["aiTitle"] as? String
            case "last-prompt": lastPrompt = object["lastPrompt"] as? String
            default: break
            }

            if let cwd = object["cwd"] as? String, !cwd.isEmpty { projectPath = cwd }
            if let branch = object["gitBranch"] as? String, !branch.isEmpty { gitBranch = branch }
        }

        return TranscriptInfo(
            sessionId: url.deletingPathExtension().lastPathComponent,
            projectPath: projectPath ?? decodeProjectPath(from: url),
            title: title,
            lastPrompt: lastPrompt,
            gitBranch: gitBranch,
            lastActivity: modified
        )
    }

    private func readTail(of url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        guard let end = try? handle.seekToEnd() else { return nil }

        let offset = end > UInt64(tailByteCount) ? end - UInt64(tailByteCount) : 0
        try? handle.seek(toOffset: offset)

        guard let data = try? handle.readToEnd() else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Fallback when no entry carried a `cwd`: Claude Code encodes the project
    /// path in the directory name by replacing separators with dashes.
    private func decodeProjectPath(from url: URL) -> String {
        url.deletingLastPathComponent().lastPathComponent
            .replacingOccurrences(of: "-", with: "/")
    }
}
