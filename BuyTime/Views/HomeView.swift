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
        BuyTimeCard().padding(.top, 32)
        Spacer()
        Button("Add 5 minutes") {
            SharedData.earnedTimeMinutes += 5
        }.buttonStyle(PrimaryButtonStyle())
        
        Button("Set Time to 0") {
            SharedData.earnedTimeMinutes = 0
        }.buttonStyle(PrimaryButtonStyle())
    }
}

private struct BuyTimeCard: View {
    
    let userName: String = "Baalavignesh A"
    let timeBalance: Int = SharedData.earnedTimeMinutes
    let tier: CardTier = .platinum
    var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                // App Name - Top Center
                Text("BuyTime")
                    .font(.system(size: 24, weight: .light, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                
                Spacer()
                
                // Logo - Center
                Image("dark_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .frame(maxWidth: .infinity)
                    
                
                Spacer()
                
                // Time Balance
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .font(.system(size: 12))
                    Text("\(timeBalance) min")
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                }
                .padding(.bottom, 12)
                
                // Bottom Row: Name & Tier
                HStack {
                    Text(userName)
                        .font(.system(size: 12, weight: .medium))
                        .tracking(1.5)
                    
                    Spacer()
                    
                    Text(tier.rawValue.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2)
                }
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 24)
            .frame(width: 360, height: 220)
            .background(tier.gradient)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}


private enum CardTier: String {
    case platinum = "Platinum"
    
    var gradient: LinearGradient {
        switch self {
        case .platinum:
            return LinearGradient(
                colors: [Color(.systemGray2), Color(.systemGray4), Color(.systemGray3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

#Preview {
    HomeView()
}
