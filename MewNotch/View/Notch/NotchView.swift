//
//  NotchView.swift
//  MewNotch
//
//  Created by Monu Kumar on 25/02/25.
//

import SwiftUI

struct NotchView: View {
    
    @Namespace var namespace
    
    @Environment(\.openSettings) private var openSettings
    
    @StateObject var notchDefaults = NotchDefaults.shared
    
    @StateObject var notchViewModel: NotchViewModel
    @StateObject var expandedNotchViewModel: ExpandedNotchViewModel = .init()

    @StateObject private var claudeActivityMonitor = ClaudeActivityMonitor.shared

    /// Counter driving the collapsed notch's shake.
    @State private var shakeTrigger: Int = 0
    
    init(
        screen: NSScreen
    ) {
        self._notchViewModel = .init(
            wrappedValue: .init(
                screen: screen
            )
        )
    }
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                
                ZStack(
                    alignment: .top
                ) {
                    let collapsedNotchView = CollapsedNotchView(
                        namespace: namespace,
                        notchViewModel: notchViewModel
                    )
                    
                    ExpandedNotchView(
                        namespace: namespace,
                        notchViewModel: notchViewModel,
                        expandedNotchViewModel: expandedNotchViewModel,
                        collapsedNotchView: collapsedNotchView
                    ).hide(when: !notchViewModel.isExpanded)
                    
                    collapsedNotchView
                }
                .glassEffect(when: notchDefaults.applyGlassEffect, in: NotchShape(
                    topRadius: notchViewModel.cornerRadius.top,
                    bottomRadius: notchViewModel.cornerRadius.bottom
                ))
                .background {
                    if !notchDefaults.applyGlassEffect {
                        Color.black
                    }
                }
                .mask {
                    NotchShape(
                        topRadius: notchViewModel.cornerRadius.top,
                        bottomRadius: notchViewModel.cornerRadius.bottom
                    )
                }
                .scaleEffect(
                    notchViewModel.isHovered ? 1.1 : 1.0,
                    anchor: .top
                )
                .shakes(on: shakeTrigger)
                .shadow(
                    radius: notchViewModel.isHovered ? 5 : 0
                )
                .onHover {
                    notchViewModel.onHover(
                        $0,
                        shouldExpand: notchDefaults.expandOnHover || notchDefaults.applyGlassEffect
                    )
                }
                .onTapGesture(
                    perform: notchViewModel.onTap
                )
                
                Spacer()
            }
            
            Spacer()
        }
        .preferredColorScheme(.dark)
        .contextMenu {
            NotchOptionsView()
        }
        .onAppear {
            // Kept running for the lifetime of the notch: the shake has to fire
            // while the Claude tab is closed, which is the whole point of it.
            claudeActivityMonitor.start()
        }
        .onReceive(claudeActivityMonitor.$activityPulse) { pulse in
            // Only while collapsed — an expanded notch already shows the change.
            guard pulse > 0, !notchViewModel.isExpanded else { return }
            shakeTrigger &+= 1
        }
    }
}
