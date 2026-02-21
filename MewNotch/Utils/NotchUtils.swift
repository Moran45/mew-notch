//
//  NotchUtils.swift
//  MewNotch
//
//  Created by Monu Kumar on 25/02/25.
//

import SwiftUI

class NotchUtils {
    
    static let shared = NotchUtils()

    // Hardcoded for MacBook Air M3 13.6"
    private let notchBaseSize: CGSize = .init(
        width: 209,
        height: 38
    )
    
    var collapsedCornerRadius: (
        top: CGFloat,
        bottom: CGFloat
    ) {
        return (
            top: 8,
            bottom: 13
        )
    }
    
    var expandedCornerRadius: (
        top: CGFloat,
        bottom: CGFloat
    ) {
        return (
            top: 8,
            bottom: 24
        )
    }
    
    private init() { }

    func notchSize() -> CGSize {
        notchBaseSize
    }
}
