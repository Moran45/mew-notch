//
//  NotchSettingsView.swift
//  MewNotch
//
//  Created by Monu Kumar on 23/03/25.
//

import SwiftUI

struct NotchSettingsView: View {
    
    @StateObject var notchDefaults = NotchDefaults.shared
    
    var body: some View {
        Form {
            Section {
                SettingsRow(
                    title: "Notch Display",
                    subtitle: "Built-in MacBook display only (fixed)",
                    icon: MewNotch.Assets.icDisplay,
                    color: MewNotch.Colors.notch
                ) {
                    Text("Fixed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                SettingsRow(
                    title: "Show on Lock Screen",
                    subtitle: "Incompatible with File Shelf feature",
                    icon: MewNotch.Assets.icLock,
                    color: MewNotch.Colors.lock
                ) {
                    Toggle("", isOn: $notchDefaults.shownOnLockScreen)
                        .onChange(of: notchDefaults.shownOnLockScreen) { _, _ in
                            NotchManager.shared.refreshNotches(killAllWindows: true)
                        }
                }
                
                SettingsRow(
                    title: "Hide on Full Screen",
                    subtitle: "Hides the notch when a full screen app is detected",
                    icon: MewNotch.Assets.icDisplay,
                    color: MewNotch.Colors.notch
                ) {
                    Toggle("", isOn: $notchDefaults.hideOnFullScreen)
                        .onChange(of: notchDefaults.hideOnFullScreen) { _, _ in
                            NotchManager.shared.refreshNotches()
                        }
                }
                
                SettingsRow(
                    title: "Reset View on Collapse",
                    subtitle: notchDefaults.resetViewOnCollapse ? "Notch resets to Home when Collapsed" : "Notch will retain state when Collapsed",
                    icon: MewNotch.Assets.icReset,
                    color: MewNotch.Colors.notch
                ) {
                    Toggle("", isOn: $notchDefaults.resetViewOnCollapse)
                }
                
            } header: {
                Text("Displays")
            }
            
            if #available(macOS 26.0, *) {
                Section {
                    SettingsRow(
                        title: "Apply Glass Effect",
                        subtitle: "Forces 'Expand on Hover' to be enabled",
                        icon: MewNotch.Assets.icGlass,
                        color: MewNotch.Colors.glass
                    ) {
                        Toggle("", isOn: $notchDefaults.applyGlassEffect)
                    }
                } header: {
                    Text("Interface")
                }
            }
            
            Section {
                SettingsRow(
                    title: "Expand on Hover",
                    subtitle: "Expand notch when hovered > 500ms.\nDisables click interactions in all HUDs.",
                    icon: MewNotch.Assets.icHover,
                    color: MewNotch.Colors.hover
                ) {
                    Toggle("", isOn: Binding(
                        get: { notchDefaults.expandOnHover || notchDefaults.applyGlassEffect },
                        set: { notchDefaults.expandOnHover = $0 }
                    ))
                    .disabled(notchDefaults.applyGlassEffect)
                }
            } header: {
                Text("Interaction")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Notch")
        .toolbarTitleDisplayMode(.inline)
    }
}

#Preview {
    NotchSettingsView()
}
