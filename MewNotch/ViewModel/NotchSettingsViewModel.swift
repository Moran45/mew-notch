//
//  NotchSettingsViewModel.swift
//  MewNotch
//
//  Created by Monu Kumar on 03/01/2026.
//

import SwiftUI

final class NotchSettingsViewModel: ObservableObject {
    
    func refreshNotches() {
        NotchManager.shared.refreshNotches()
    }
    
    func refreshNotchesAndKillWindows() {
         NotchManager.shared.refreshNotches(killAllWindows: true)
    }
}
