//
//  WakefulnessManager.swift
//  MewNotch
//

import Combine
import Foundation
import IOKit.pwr_mgt

/// How long the Mac is kept awake after the last agent stops working, so a
/// short pause between turns does not drop the machine straight to sleep.
private let agentGracePeriod: TimeInterval = 5 * 60

enum WakefulnessMode: String, CaseIterable, Identifiable, Sendable {

    /// Normal macOS sleep behaviour.
    case off

    /// Awake until switched off.
    case indefinite

    /// Awake while a Claude session is working, plus a grace period.
    case followAgent

    var id: String { rawValue }

    var label: String {
        switch self {
        case .off: return "Off"
        case .indefinite: return "Indefinitely"
        case .followAgent: return "While the agent is working"
        }
    }
}

/// Keeps the Mac from sleeping, either indefinitely or for as long as a Claude
/// Code session is working.
///
/// Backed by an IOKit power assertion. `PreventUserIdleSystemSleep` stops the
/// *system* idling to sleep but deliberately lets the display sleep on its own
/// schedule — a long agent run should not also burn the screen.
///
/// The assertion does not survive closing the lid: macOS sleeps a clamshelled
/// laptop regardless of idle assertions.
final class WakefulnessManager: ObservableObject {

    static let shared = WakefulnessManager()

    @Published private(set) var mode: WakefulnessMode

    /// Whether an assertion is currently held.
    @Published private(set) var isHoldingAwake: Bool = false

    /// When the post-agent grace period expires, if one is running.
    @Published private(set) var graceEndsAt: Date?

    private var assertionID: IOPMAssertionID = 0
    private var agentObserver: AnyCancellable?
    private var graceTimer: Timer?

    private init() {
        mode = WakefulnessDefaults.shared.mode
        apply(mode: mode)
    }

    deinit {
        releaseAssertion()
    }

    // MARK: - Mode

    func setMode(_ newMode: WakefulnessMode) {
        guard newMode != mode else { return }

        mode = newMode
        WakefulnessDefaults.shared.mode = newMode

        apply(mode: newMode)
    }

    /// Convenience for menu toggles: selecting an active mode turns it off.
    func toggle(_ candidate: WakefulnessMode) {
        setMode(mode == candidate ? .off : candidate)
    }

    private func apply(mode: WakefulnessMode) {
        cancelGrace()
        agentObserver = nil

        switch mode {
        case .off:
            ClaudeActivityMonitor.shared.stopIfObserving(&isObservingAgent)
            releaseAssertion()

        case .indefinite:
            ClaudeActivityMonitor.shared.stopIfObserving(&isObservingAgent)
            acquireAssertion()

        case .followAgent:
            startObservingAgent()
        }
    }

    // MARK: - Agent tracking

    private var isObservingAgent = false

    private func startObservingAgent() {
        if !isObservingAgent {
            ClaudeActivityMonitor.shared.start()
            isObservingAgent = true
        }

        agentObserver = ClaudeActivityMonitor.shared.$sessions
            .map { sessions in
                sessions.contains { $0.isLive && $0.status == .working }
            }
            .removeDuplicates()
            .sink { [weak self] isWorking in
                self?.handleAgent(isWorking: isWorking)
            }
    }

    private func handleAgent(isWorking: Bool) {
        guard mode == .followAgent else { return }

        if isWorking {
            cancelGrace()
            acquireAssertion()
            return
        }

        // Nothing running: hold on for the grace period rather than dropping
        // the assertion the instant a turn ends.
        guard isHoldingAwake, graceTimer == nil else { return }

        let deadline = Date().addingTimeInterval(agentGracePeriod)
        graceEndsAt = deadline

        let timer = Timer(fire: deadline, interval: 0, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.cancelGrace()
            self.releaseAssertion()
        }

        RunLoop.main.add(timer, forMode: .common)
        graceTimer = timer
    }

    private func cancelGrace() {
        graceTimer?.invalidate()
        graceTimer = nil
        graceEndsAt = nil
    }

    // MARK: - Power assertion

    private func acquireAssertion() {
        guard assertionID == 0 else { return }

        var identifier: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertPreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "YourNotch is keeping this Mac awake" as CFString,
            &identifier
        )

        guard result == kIOReturnSuccess else { return }

        assertionID = identifier
        isHoldingAwake = true
    }

    private func releaseAssertion() {
        guard assertionID != 0 else { return }

        IOPMAssertionRelease(assertionID)
        assertionID = 0
        isHoldingAwake = false
    }
}

private extension ClaudeActivityMonitor {

    /// Balances the `start()` taken when agent tracking began.
    func stopIfObserving(_ flag: inout Bool) {
        guard flag else { return }
        stop()
        flag = false
    }
}
