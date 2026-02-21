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
        let displaysIntegrados = screens.filter { screen in
            guard let id = displayID(from: screen) else {
                return false
            }

            return esDisplayIntegrado(id)
        }

        guard !displaysIntegrados.isEmpty else {
            NSLog("NotchScreenResolver: no built-in display available. Notch will not be shown.")
            return nil
        }

        return displaysIntegrados.max { lhs, rhs in
            let lhsTieneNotch = lhs.safeAreaInsets.top > 0
            let rhsTieneNotch = rhs.safeAreaInsets.top > 0

            if lhsTieneNotch != rhsTieneNotch {
                return !lhsTieneNotch && rhsTieneNotch
            }

            let lhsArea = lhs.frame.width * lhs.frame.height
            let rhsArea = rhs.frame.width * rhs.frame.height

            return lhsArea < rhsArea
        }
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
