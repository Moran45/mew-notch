//
//  ExpandedNotchItem.swift
//  MewNotch
//
//  Created by Monu Kumar on 28/04/25.
//


enum ExpandedNotchItem: String, CaseIterable, Codable, Identifiable {
    var id: String {
        self.rawValue
    }
    
    case NowPlaying
    case Bash
    
    var displayName: String {
        switch self {
        case .NowPlaying:
            return "Now Playing"
        case .Bash:
            return "Bash Command"
        }
    }
    
    var imageSystemName: String {
        switch self {
        case .NowPlaying:
            return "music.note"
        case .Bash:
            return "terminal"
        }
    }
}
