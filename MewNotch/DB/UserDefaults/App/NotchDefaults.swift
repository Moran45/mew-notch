//
//  NotchDefaults.swift
//  MewNotch
//
//  Created by Monu Kumar on 23/03/25.
//

import Foundation

class NotchDefaults: ObservableObject {
    
    private static var PREFIX: String = "Notch_"
    private static let INTERNAL_DISPLAY_MIGRATION_KEY = PREFIX + "InternalDisplayOnlyMigrationV1"
    
    static let shared = NotchDefaults()
    
    private init() {
        if !UserDefaults.standard.bool(forKey: Self.INTERNAL_DISPLAY_MIGRATION_KEY) {
            // Legacy cleanup: this app now always targets the built-in MacBook display.
            notchDisplayVisibility = .NotchedDisplayOnly
            shownOnDisplay = [:]
            UserDefaults.standard.set(true, forKey: Self.INTERNAL_DISPLAY_MIGRATION_KEY)
        }

        var currentOrder = expandedItemsOrder
        let allItems = ExpandedNotchItem.allCases
        
        let missingItems = allItems.filter { !currentOrder.contains($0) }
        
        if !missingItems.isEmpty {
            currentOrder.append(contentsOf: missingItems)
            expandedItemsOrder = currentOrder
        }
    }
    
    @PrimitiveUserDefault(
        PREFIX + "HideOnFullScreen",
        defaultValue: true
    )
    var hideOnFullScreen: Bool {
        didSet {
            self.objectWillChange.send()
        }
    }
    
    @CodableUserDefault(
        PREFIX + "NotchDisplayVisibility",
        defaultValue: NotchDisplayVisibility.NotchedDisplayOnly
    )
    // Deprecated: persisted only for backward compatibility.
    var notchDisplayVisibility: NotchDisplayVisibility {
        didSet {
            self.objectWillChange.send()
        }
    }
    
    @CodableUserDefault(
        PREFIX + "ShownOnDisplay",
        defaultValue: [:]
    )
    // Deprecated: persisted only for backward compatibility.
    var shownOnDisplay: [String: Bool] {
        didSet {
            self.objectWillChange.send()
        }
    }
    
    @PrimitiveUserDefault(
        PREFIX + "ShownOnLockScreen",
        defaultValue: true
    )
    var shownOnLockScreen: Bool {
        didSet {
            self.objectWillChange.send()
        }
    }
    
    @PrimitiveUserDefault(
        PREFIX + "resetViewOnCollapse",
        defaultValue: true
    )
    var resetViewOnCollapse: Bool {
        didSet {
            self.objectWillChange.send()
        }
    }
    
    @CodableUserDefault(
        PREFIX + "HeightMode",
        defaultValue: NotchHeightMode.Match_Notch
    )
    var heightMode: NotchHeightMode {
        didSet {
            self.objectWillChange.send()
        }
    }
    
    @PrimitiveUserDefault(
        PREFIX + "GlassEffect",
        defaultValue: false
    )
    var applyGlassEffect: Bool {
        didSet {
            self.objectWillChange.send()
        }
    }
    
    @PrimitiveUserDefault(
        PREFIX + "ExpandOnHover",
        defaultValue: false
    )
    var expandOnHover: Bool {
        didSet {
            self.objectWillChange.send()
        }
    }
    
    @PrimitiveUserDefault(
        PREFIX + "ExpandedNotchShowDividers",
        defaultValue: true
    )
    var showDividers: Bool {
        didSet {
            self.objectWillChange.send()
        }
    }
    
    @CodableUserDefault(
        PREFIX + "ExpandedNotchItems",
        defaultValue: [
            ExpandedNotchItem.NowPlaying
        ]
    )
    var expandedNotchItems: [ExpandedNotchItem] {
        didSet {
            self.objectWillChange.send()
        }
    }
    
    @CodableUserDefault(
        PREFIX + "ExpandedItemsOrder",
        defaultValue: ExpandedNotchItem.allCases
    )
    var expandedItemsOrder: [ExpandedNotchItem] {
        didSet {
            self.objectWillChange.send()
        }
    }
}
