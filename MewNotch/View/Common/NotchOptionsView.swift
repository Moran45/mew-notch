//
//  NotchOptionsView.swift
//  MewNotch
//
//  Created by Monu Kumar on 15/05/25.
//

import SwiftUI

struct NotchOptionsView: View {
    
    enum OptionsType {
        case ContextMenu
        case MenuBar
    }
    
    @Environment(\.openSettings) private var openSettings
    
    @StateObject private var appDefaults = AppDefaults.shared
    @StateObject private var wakefulness = WakefulnessManager.shared
    
    var type: OptionsType = .ContextMenu
    
    var body: some View {
        Menu(keepAwakeTitle) {
            ForEach(WakefulnessMode.allCases.filter { $0 != .off }) { candidate in
                Toggle(
                    candidate.label,
                    isOn: Binding(
                        get: { wakefulness.mode == candidate },
                        set: { _ in wakefulness.toggle(candidate) }
                    )
                )
            }
        }

        Divider()

        Button("Fix Notch") {
            NotchManager.shared.refreshNotches()
        }
        
        Button("Settings") {
            openSettings()
        }
        .keyboardShortcut(
            ",",
            modifiers: .command
        )
        
        Button("Quit") {
            AppManager.shared.kill()
        }
        .keyboardShortcut("R", modifiers: .command)
    }

    /// Folds the current state into the menu title, so the state is readable
    /// without opening the submenu.
    private var keepAwakeTitle: String {
        switch wakefulness.mode {
        case .off:
            return "Keep Awake"
        case .indefinite:
            return "Keep Awake: On"
        case .followAgent:
            return wakefulness.isHoldingAwake
                ? "Keep Awake: Agent (holding)"
                : "Keep Awake: Agent (idle)"
        }
    }
}

#Preview {
    NotchOptionsView()
}
