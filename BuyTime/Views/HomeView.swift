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
        Button("Add 5 minutes") {
            SharedData.earnedTimeMinutes += 5
        }.buttonStyle(PrimaryButtonStyle())
        
        Button("Set Time to 0") {
            SharedData.earnedTimeMinutes = 0
        }.buttonStyle(PrimaryButtonStyle())
    }
}

#Preview {
    HomeView()
}
