//
//  FileShelfView.swift
//  MewNotch
//
//  Created by Monu Kumar on 03/07/25.
//

import SwiftUI
import AppKit

struct FileShelfView: View {
    @ObservedObject var notchViewModel: NotchViewModel
    @StateObject private var diskListViewModel = ActiveDiskListViewModel()
    
    private var diskNameFont: NSFont {
        NSFont.systemFont(ofSize: 11, weight: .medium)
    }
    
    private var leftPanelWidth: CGFloat {
        let maxNameWidth = diskListViewModel.activeDisks
            .map { $0.name.width(using: diskNameFont) }
            .max() ?? 0
        
        let rowContentWidth: CGFloat = 14 + 8 + maxNameWidth
        let rowHorizontalPadding: CGFloat = 8
        let panelHorizontalPadding: CGFloat = 8
        
        let calculatedWidth = rowContentWidth + rowHorizontalPadding + panelHorizontalPadding
        let minimumWidth = notchViewModel.notchSize.height * 1.9
        
        return max(calculatedWidth, minimumWidth)
    }
    
    private var shelfWidth: CGFloat {
        // Keep this view narrower than previous expanded width while reserving
        // a bit of horizontal space on the right side for future content.
        max(leftPanelWidth + 24, notchViewModel.notchSize.width * 1.55)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 8) {
                Spacer(minLength: 0)
                
                ForEach(diskListViewModel.activeDisks) { disk in
                    HStack(spacing: 8) {
                        Image(systemName: disk.iconSystemName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(width: 16, alignment: .leading)
                        
                        Text(disk.name)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                        
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.07))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            }
                    }
                }
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)
            .frame(
                width: leftPanelWidth,
                height: notchViewModel.notchSize.height * 3
            )
            
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(
             width: shelfWidth,
             height: notchViewModel.notchSize.height * 3,
             alignment: .bottom
        )
    }
}

private extension String {
    func width(using font: NSFont) -> CGFloat {
        (self as NSString).size(withAttributes: [.font: font]).width
    }
}

private struct ActiveDiskItem: Identifiable, Equatable {
    let id: String
    let name: String
    let isBuiltIn: Bool
    
    var iconSystemName: String {
        isBuiltIn ? "applelogo" : "internaldrive.fill"
    }
}

private final class ActiveDiskListViewModel: ObservableObject {
    @Published private(set) var activeDisks: [ActiveDiskItem] = []
    
    private var notificationTokens: [NSObjectProtocol] = []
    private let workspaceNotificationCenter = NSWorkspace.shared.notificationCenter
    
    init() {
        startObservingVolumeChanges()
        refreshDisks()
    }
    
    deinit {
        notificationTokens.forEach(workspaceNotificationCenter.removeObserver)
    }
    
    private func startObservingVolumeChanges() {
        let notifications: [Notification.Name] = [
            NSWorkspace.didMountNotification,
            NSWorkspace.didUnmountNotification,
            NSWorkspace.didRenameVolumeNotification
        ]
        
        notifications.forEach { notification in
            let token = workspaceNotificationCenter.addObserver(
                forName: notification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.refreshDisks()
            }
            notificationTokens.append(token)
        }
    }
    
    private func refreshDisks() {
        let keys: Set<URLResourceKey> = [
            .volumeNameKey,
            .volumeIsInternalKey,
            .volumeIsBrowsableKey,
            .volumeIsLocalKey
        ]
        
        let mountedVolumes = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: Array(keys),
            options: [.skipHiddenVolumes]
        ) ?? []
        
        var builtInDisk: ActiveDiskItem?
        var externalDisks: [ActiveDiskItem] = []
        
        for volumeURL in mountedVolumes {
            guard
                let values = try? volumeURL.resourceValues(forKeys: keys),
                values.volumeIsBrowsable != false,
                values.volumeIsLocal != false
            else {
                continue
            }
            
            let diskName = values.volumeName ?? volumeURL.lastPathComponent
            let isBuiltIn = values.volumeIsInternal ?? false
            let item = ActiveDiskItem(
                id: volumeURL.path,
                name: diskName,
                isBuiltIn: isBuiltIn
            )
            
            if isBuiltIn {
                if builtInDisk == nil || volumeURL.path == "/" {
                    builtInDisk = item
                }
            } else {
                externalDisks.append(item)
            }
        }
        
        if builtInDisk == nil {
            let rootURL = URL(fileURLWithPath: "/")
            let rootName = (try? rootURL.resourceValues(forKeys: [.volumeNameKey]))?.volumeName ?? "Macintosh HD"
            builtInDisk = ActiveDiskItem(id: rootURL.path, name: rootName, isBuiltIn: true)
        }
        
        externalDisks.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        
        var nextState: [ActiveDiskItem] = []
        if let builtInDisk {
            nextState.append(builtInDisk)
        }
        if let firstExternal = externalDisks.first {
            nextState.append(firstExternal)
        }
        
        if activeDisks != nextState {
            activeDisks = nextState
        }
    }
}
