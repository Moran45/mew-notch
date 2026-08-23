//
//  ClaudeView.swift
//  MewNotch
//

import SwiftUI

/// Reserved slot for the Claude tab.
///
/// Intentionally empty: it only preserves the expanded notch layout size so the
/// tab can be selected while its feature is built out. See `Deprecated/` for the
/// previous occupant of this slot (the storage shelf).
struct ClaudeView: View {

    @ObservedObject var notchViewModel: NotchViewModel

    private var contentWidth: CGFloat {
        notchViewModel.notchSize.width * 1.55
    }

    private var contentHeight: CGFloat {
        notchViewModel.notchSize.height * 3
    }

    var body: some View {
        Color.clear
            .frame(
                width: contentWidth,
                height: contentHeight,
                alignment: .bottom
            )
    }
}
