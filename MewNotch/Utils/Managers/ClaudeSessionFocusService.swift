//
//  ClaudeSessionFocusService.swift
//  MewNotch
//

import AppKit
import Foundation

/// Brings a Claude Code session's terminal to the front.
///
/// A session only knows its own process id. The window it lives in belongs to
/// whichever application spawned the shell, so the owning app is found by
/// walking the process' parent chain until a running application is hit.
///
/// How precisely a session can be focused depends on that host:
///
/// - **Terminal.app / iTerm2** expose their tabs to AppleScript keyed by tty, so
///   the exact tab is selected.
/// - **Everything else** (VS Code's integrated terminal included) has no way to
///   address an individual terminal from outside the app, so only the
///   application itself is activated.
enum ClaudeSessionFocusService {

    enum Result {
        /// The exact terminal tab was selected.
        case focusedTab(app: String)

        /// The host application was activated, but not the specific terminal.
        case focusedApp(app: String)

        case failed(reason: String)
    }

    /// Bundle identifiers whose tabs can be addressed by tty.
    private enum ScriptableTerminal: String {
        case terminal = "com.apple.Terminal"
        case iTerm = "com.googlecode.iterm2"
    }

    @discardableResult
    static func focus(_ session: ClaudeSession) -> Result {
        guard let pid = session.pid else {
            return .failed(reason: "Session is not running")
        }

        guard let host = hostApplication(of: pid) else {
            return .failed(reason: "Could not find the application hosting this session")
        }

        let appName = host.localizedName ?? "the terminal"

        host.activate(options: [.activateAllWindows])

        guard
            let bundleID = host.bundleIdentifier,
            let scriptable = ScriptableTerminal(rawValue: bundleID),
            let tty = ttyPath(of: pid)
        else {
            return .focusedApp(app: appName)
        }

        return selectTab(tty: tty, in: scriptable)
            ? .focusedTab(app: appName)
            : .focusedApp(app: appName)
    }

    /// Whether this session can be focused at all.
    static func canFocus(_ session: ClaudeSession) -> Bool {
        guard let pid = session.pid else { return false }
        return hostApplication(of: pid) != nil
    }

    // MARK: - Process inspection

    /// Walks up from `pid` until a process that owns a running application is
    /// found. The shell and any helper processes in between are skipped.
    private static func hostApplication(of pid: pid_t) -> NSRunningApplication? {
        var current = pid

        // Bounded so a cycle or a very deep tree cannot spin here.
        for _ in 0..<16 {
            if let app = NSRunningApplication(processIdentifier: current) {
                return app
            }

            guard let parent = parentProcessID(of: current), parent > 1 else {
                return nil
            }
            current = parent
        }

        return nil
    }

    private static func processInfo(of pid: pid_t) -> kinfo_proc? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]

        let status = sysctl(&mib, u_int(mib.count), &info, &size, nil, 0)
        guard status == 0, size > 0 else { return nil }

        return info
    }

    private static func parentProcessID(of pid: pid_t) -> pid_t? {
        processInfo(of: pid)?.kp_eproc.e_ppid
    }

    /// Controlling terminal of the process, as a device path.
    private static func ttyPath(of pid: pid_t) -> String? {
        guard let info = processInfo(of: pid) else { return nil }

        let device = info.kp_eproc.e_tdev
        guard device != -1, let name = devname(device, S_IFCHR) else { return nil }

        return "/dev/" + String(cString: name)
    }

    // MARK: - AppleScript

    private static func selectTab(tty: String, in terminal: ScriptableTerminal) -> Bool {
        let source: String

        switch terminal {
        case .terminal:
            source = """
            tell application "Terminal"
                repeat with theWindow in windows
                    repeat with theTab in tabs of theWindow
                        if tty of theTab is "\(tty)" then
                            set selected tab of theWindow to theTab
                            set index of theWindow to 1
                            return true
                        end if
                    end repeat
                end repeat
            end tell
            return false
            """

        case .iTerm:
            source = """
            tell application "iTerm2"
                repeat with theWindow in windows
                    repeat with theTab in tabs of theWindow
                        repeat with theSession in sessions of theTab
                            if tty of theSession is "\(tty)" then
                                select theWindow
                                select theTab
                                select theSession
                                return true
                            end if
                        end repeat
                    end repeat
                end repeat
            end tell
            return false
            """
        }

        guard let script = NSAppleScript(source: source) else { return false }

        var error: NSDictionary?
        let output = script.executeAndReturnError(&error)

        // A nil error with a false result means the tty was not found; an error
        // usually means Automation permission has not been granted yet.
        guard error == nil else { return false }

        return output.booleanValue
    }
}
