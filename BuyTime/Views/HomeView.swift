//
//  HomeView.swift
//  BuyTime
//
//  Created by Baalavignesh Arunachalam on 12/18/25.
//

import SwiftUI


struct HomeView: View {
    @State var path = NavigationPath()
    
    var body: some View {
        Button("Allow ScreenTime Access") {
            
        }.buttonStyle(PrimaryButtonStyle())
    }
}

#Preview {
    HomeView()
}
