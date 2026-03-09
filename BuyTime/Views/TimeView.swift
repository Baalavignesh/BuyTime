//
//  TimeView.swift
//  BuyTime
//
//  Created by Baalavignesh Arunachalam on 12/21/25.
//

import SwiftUI

struct TimeView: View {
    @StateObject private var balanceVM = BalanceViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Spend Time")
                // Debug buttons
                VStack(spacing: 12) {
                    Button("Add 5 minutes") {
                        balanceVM.addMinutes(5)
                    }.buttonStyle(PrimaryButtonStyle())

                    Button("Set Time to 0") {
                        balanceVM.debugSetMinutes(0)
                    }.buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }


}


}

#Preview {
    TimeView()
}
