//
//  MewNotchWatchApp.swift
//  MewNotchWatch
//

import SwiftUI

/// Standalone watchOS app.
///
/// watchOS apps cannot be companions to a macOS app — that mechanism only
/// exists for iOS hosts — so this ships as its own product. It will receive
/// Claude session state from the Mac over CloudKit; until that is wired up it
/// only establishes presence on the watch.
@main
struct MewNotchWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchRootView()
        }
    }
}
