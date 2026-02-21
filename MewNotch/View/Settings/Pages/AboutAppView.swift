//
//  AboutAppView.swift
//  MewNotch
//
//  Created by Monu Kumar on 27/02/25.
//

import SwiftUI

struct AboutAppView: View {
    private var currentVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return "\(version) (\(build))"
    }
    
    var body: some View {
        VStack(spacing: 32) {
            
            VStack(spacing: 16) {

                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .shadow(radius: 10)
                
                VStack(spacing: 8) {
                    Text("YourNotch")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(MewNotch.Colors.notch.color)
                    
                    Text("Version \(currentVersion)")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background {
                            Capsule()
                                .fill(.tertiary.opacity(0.2))
                        }
                }
            }

        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("")
    }
}

#Preview {
    AboutAppView()
}
