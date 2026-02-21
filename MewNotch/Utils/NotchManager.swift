//
//  NotchManager.swift
//  MewNotch
//
//  Created by Monu Kumar on 12/03/25.
//

import SwiftUI
import MacroVisionKit

class NotchManager {
    
    static let shared = NotchManager()
    
    var notchDefaults: NotchDefaults = .shared
    
    var windows: [NSScreen: NSWindow] = [:]
    
    private var monitorTask: Task<Void, Never>?
    
    private init() {
        monitorTask = Task { @MainActor in
            let stream = await FullScreenMonitor.shared.spaceChanges()
            for await spaces in stream {
                self.updateFullScreenStatus(with: spaces)
            }
        }
        
        addListenerForScreenUpdates()
    }
    
    deinit {
        monitorTask?.cancel()
        removeListenerForScreenUpdates()
    }

    private func getDisplayID(
        for screen: NSScreen
    ) -> CGDirectDisplayID? {
        NotchScreenResolver.shared.displayID(from: screen)
    }

    private func getIntegratedScreen() -> NSScreen? {
        NotchScreenResolver.shared.pantallaIntegradaActual()
    }

    private func windowForDisplayID(
        _ displayID: CGDirectDisplayID
    ) -> (screen: NSScreen, window: NSWindow)? {
        guard let item = windows.first(where: { (screen, _) in
            getDisplayID(for: screen) == displayID
        }) else {
            return nil
        }

        return (screen: item.key, window: item.value)
    }
    
    @MainActor
    private func updateFullScreenStatus(with spaces: [MacroVisionKit.FullScreenMonitor.SpaceInfo]) {
        guard notchDefaults.hideOnFullScreen else { return }

        guard
            let integratedScreen = getIntegratedScreen(),
            let integratedDisplayID = getDisplayID(for: integratedScreen),
            let targetWindow = windowForDisplayID(integratedDisplayID)?.window
        else {
            return
        }

        let isIntegratedDisplayFullScreen = spaces.contains { space in
            guard
                let fullScreenAppScreen = FullScreenMonitor.shared.screen(for: space),
                let fullScreenDisplayID = getDisplayID(for: fullScreenAppScreen)
            else {
                return false
            }

            return fullScreenDisplayID == integratedDisplayID
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.6
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

            targetWindow.animator().alphaValue = isIntegratedDisplayFullScreen ? 0 : 1
        }
    }
    
    @objc func refreshNotches(
        killAllWindows: Bool = false,
        addToSeparateSpace: Bool = true
    ) {

        let targetScreen = getIntegratedScreen()
        let targetDisplayID = targetScreen.flatMap { getDisplayID(for: $0) }

        let screensToClose = windows.keys.filter { screen in
            if killAllWindows {
                return true
            }

            guard let expectedDisplayID = targetDisplayID else {
                return true
            }

            return getDisplayID(for: screen) != expectedDisplayID
        }

        for screen in screensToClose {
            guard let window = windows.removeValue(forKey: screen) else {
                continue
            }

            window.close()
        }

        guard
            let targetScreen,
            let targetDisplayID
        else {
            return
        }

        let existingWindowEntry = windowForDisplayID(targetDisplayID)
        var panel: NSWindow? = existingWindowEntry?.window

        if let existingScreen = existingWindowEntry?.screen, existingScreen != targetScreen {
            windows.removeValue(forKey: existingScreen)
        }

        if panel == nil {
            let view: NSView = NSHostingView(
                rootView: NotchView(
                    screen: targetScreen
                )
            )

            panel = MewPanel(
                contentRect: targetScreen.frame,
                styleMask: [
                    .borderless,
                    .nonactivatingPanel,
                    .utilityWindow,
                    .hudWindow
                ],
                backing: .buffered,
                defer: true
            )

            panel?.contentView = view
        }

        guard let panel else {
            return
        }

        panel.setFrame(
            targetScreen.frame,
            display: true
        )

        panel.orderFrontRegardless()

        windows[targetScreen] = panel

        if addToSeparateSpace {
            if notchDefaults.shownOnLockScreen {
                WindowManager.shared?.moveToLockScreen(panel)
            } else {
                NotchSpaceManager.shared.notchSpace.windows.insert(panel)
            }
        }
        
        // Trigger manual update based on current state
        Task { @MainActor in
            let spaces = await FullScreenMonitor.shared.detectFullscreenApps()
            self.updateFullScreenStatus(with: spaces)
        }
    }
    
    func addListenerForScreenUpdates() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshNotches),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    func removeListenerForScreenUpdates() {
        NotificationCenter.default.removeObserver(self)
    }
}
