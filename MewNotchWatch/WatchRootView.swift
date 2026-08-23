//
//  WatchRootView.swift
//  MewNotchWatch
//

import SwiftUI

/// Landing screen of the watch app: the app icon and its name.
struct WatchRootView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image("AppIconPreview")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                }

            Text("YourNotch")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.black.gradient, for: .navigation)
    }
}

#Preview {
    WatchRootView()
}
