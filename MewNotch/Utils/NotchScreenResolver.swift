//
//  NotchScreenResolver.swift
//  MewNotch
//
//  Created by Codex on 21/02/26.
//

import AppKit
import CoreGraphics

final class NotchScreenResolver {

    static let shared = NotchScreenResolver()

    private init() {}

    func pantallaIntegradaActual(
        from screens: [NSScreen] = NSScreen.screens
    ) -> NSScreen? {
        let displaysIntegrados = screens.compactMap { screen -> (screen: NSScreen, id: CGDirectDisplayID)? in
            guard let id = displayID(from: screen) else {
                return nil
            }

            guard esDisplayIntegrado(id) else {
                return nil
            }

            return (screen: screen, id: id)
        }.sorted { $0.id < $1.id }

        guard !displaysIntegrados.isEmpty else {
            NSLog("NotchScreenResolver: no built-in display available. Notch will not be shown.")
            return nil
        }

        return displaysIntegrados.first?.screen
    }

    func displayID(
        from screen: NSScreen
    ) -> CGDirectDisplayID? {
        guard let value = screen.deviceDescription[
            NSDeviceDescriptionKey("NSScreenNumber")
        ] as? NSNumber else {
            return nil
        }

        return CGDirectDisplayID(value.uint32Value)
    }

    func esDisplayIntegrado(
        _ id: CGDirectDisplayID
    ) -> Bool {
        CGDisplayIsBuiltin(id) != 0
    }
}
