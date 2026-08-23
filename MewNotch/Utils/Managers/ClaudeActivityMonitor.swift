//
//  ClaudeActivityMonitor.swift
//  MewNotch
//

import Foundation
import SwiftUI

/// Watches Claude Code's on-disk transcripts and publishes a live view of every
/// session.
///
/// Transcripts live at `~/.claude/projects/<slug>/<sessionId>.jsonl`, one JSON
/// object per line, appended as the conversation advances. Rather than parse
/// whole files — they routinely pass a megabyte — only the tail of each is read,
/// which is enough for the status signal and the most recent title and prompt.
///
/// Polling is driven by modification dates: each tick stats the transcripts and
/// re-parses only those that changed.
final class ClaudeActivityMonitor: ObservableObject {

    static let shared = ClaudeActivityMonitor()

    /// All known sessions, most recently active first.
    @Published private(set) var sessions: [ClaudeSession] = []

    /// Bytes read from the end of each transcript. Large enough to comfortably
    /// contain the recent `ai-title` and `last-prompt` entries.
    private let tailByteCount = 256 * 1024

    private let projectsURL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/projects", isDirectory: true)

    private let queue = DispatchQueue(
        label: "com.yournotch.claude-activity",
        qos: .utility
    )

    private var timer: DispatchSourceTimer?

    /// Modification date of each transcript at the time it was last parsed.
    private var parsedDates: [String: Date] = [:]

    /// Last parse result per transcript, reused when the file has not changed.
    private var cache: [String: ClaudeSession] = [:]

    private var startCount = 0

    private init() {}

    // MARK: - Lifecycle

    /// Begins polling. Balanced by `stop()`; nested calls are reference counted
    /// so several views can observe the monitor independently.
    func start(interval: TimeInterval = 2) {
        queue.async { [weak self] in
            guard let self else { return }

            self.startCount += 1
            guard self.timer == nil else { return }

            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now(), repeating: interval)
            timer.setEventHandler { [weak self] in
                self?.refresh()
            }
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
        let fileManager = FileManager.default

        guard let projectDirs = try? fileManager.contentsOfDirectory(
            at: projectsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        var found: [ClaudeSession] = []
        var liveKeys: Set<String> = []

        for projectDir in projectDirs {
            let isDirectory = (try? projectDir.resourceValues(
                forKeys: [.isDirectoryKey]
            ))?.isDirectory ?? false
            guard isDirectory else { continue }

            let transcripts = (try? fileManager.contentsOfDirectory(
                at: projectDir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ))?.filter { $0.pathExtension == "jsonl" } ?? []

            for transcript in transcripts {
                let key = transcript.path
                liveKeys.insert(key)

                let modified = (try? transcript.resourceValues(
                    forKeys: [.contentModificationDateKey]
                ))?.contentModificationDate ?? .distantPast

                // Unchanged since the last pass: reuse the parsed result.
                if parsedDates[key] == modified, let cached = cache[key] {
                    found.append(cached)
                    continue
                }

                guard let session = parseSession(at: transcript, modified: modified) else {
                    continue
                }

                parsedDates[key] = modified
                cache[key] = session
                found.append(session)
            }
        }

        // Drop transcripts that disappeared.
        parsedDates = parsedDates.filter { liveKeys.contains($0.key) }
        cache = cache.filter { liveKeys.contains($0.key) }

        found.sort { $0.lastActivity > $1.lastActivity }

        DispatchQueue.main.async { [weak self] in
            guard let self, self.sessions != found else { return }
            self.sessions = found
        }
    }

    // MARK: - Parsing

    private func parseSession(at url: URL, modified: Date) -> ClaudeSession? {
        guard let tail = readTail(of: url) else { return nil }

        // The first line is usually truncated mid-object by the tail read.
        var lines = tail.split(separator: "\n", omittingEmptySubsequences: true)
        if lines.count > 1 { lines.removeFirst() }

        var title: String?
        var lastPrompt: String?
        var gitBranch: String?
        var projectPath: String?
        var status: ClaudeSessionStatus = .unknown
        var statusResolved = false

        // Walk forward for the metadata (latest wins) and backward for status.
        var entries: [[String: Any]] = []
        entries.reserveCapacity(lines.count)

        for line in lines {
            guard
                let data = line.data(using: .utf8),
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                continue
            }
            entries.append(object)

            switch object["type"] as? String {
            case "ai-title":
                title = object["aiTitle"] as? String
            case "last-prompt":
                lastPrompt = object["lastPrompt"] as? String
            default:
                break
            }

            if let cwd = object["cwd"] as? String, !cwd.isEmpty {
                projectPath = cwd
            }
            if let branch = object["gitBranch"] as? String, !branch.isEmpty {
                gitBranch = branch
            }
        }

        // Status comes from the last conversational entry. Sidechain traffic is
        // subagent chatter and meta entries are injected context, so neither
        // reflects what the session is doing.
        for object in entries.reversed() {
            guard let type = object["type"] as? String else { continue }
            guard type == "user" || type == "assistant" else { continue }
            if object["isSidechain"] as? Bool == true { continue }
            if object["isMeta"] as? Bool == true { continue }

            status = (type == "user") ? .working : .waiting
            statusResolved = true
            break
        }

        if !statusResolved { status = .unknown }

        let sessionId = url.deletingPathExtension().lastPathComponent

        return ClaudeSession(
            id: sessionId,
            projectPath: projectPath ?? decodeProjectPath(from: url),
            title: title,
            lastPrompt: lastPrompt,
            gitBranch: gitBranch,
            status: status,
            lastActivity: modified
        )
    }

    /// Reads the trailing bytes of a transcript, or the whole file when it is
    /// smaller than the window.
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
    /// path in the directory name by replacing separators with dashes, which is
    /// lossy but good enough for a label.
    private func decodeProjectPath(from url: URL) -> String {
        let slug = url.deletingLastPathComponent().lastPathComponent
        return slug.replacingOccurrences(of: "-", with: "/")
    }
}
