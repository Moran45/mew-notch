//
//  FileShelfView.swift
//  MewNotch
//
//  Created by Monu Kumar on 03/07/25.
//

import SwiftUI

struct FileShelfView: View {
    @ObservedObject var notchViewModel: NotchViewModel
    
    var body: some View {
        Color.clear
        .frame(
             width: notchViewModel.notchSize.width * 2.2,
             height: notchViewModel.notchSize.height * 3,
             alignment: .bottom
        )
    }
}
