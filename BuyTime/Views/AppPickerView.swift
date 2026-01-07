//
//  AppPickerView.swift
//  BuyTime
//
//  Created by Baalavignesh Arunachalam on 1/7/26.
//

import SwiftUI
import FamilyControls

struct AppPickerView: View {
    @State var selection = FamilyActivitySelection()

    
    var body: some View {
        FamilyActivityPicker(selection: $selection)
        
        Button("Proceed with Selection") {
//            hasCompletedAppSelection = true
        }
        
    }
}

#Preview {
    AppPickerView()
}
