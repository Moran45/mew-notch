//
//  WakefulnessDefaults.swift
//  MewNotch
//

import Foundation

class WakefulnessDefaults: ObservableObject {

    private static var PREFIX: String = "Wakefulness_"

    static let shared = WakefulnessDefaults()

    private init() {}

    @PrimitiveUserDefault(
        PREFIX + "Mode",
        defaultValue: WakefulnessMode.off.rawValue
    )
    private var storedMode: String {
        didSet {
            self.objectWillChange.send()
        }
    }

    var mode: WakefulnessMode {
        get { WakefulnessMode(rawValue: storedMode) ?? .off }
        set { storedMode = newValue.rawValue }
    }
}
