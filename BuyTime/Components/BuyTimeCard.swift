//
//  BuyTimeCard.swift
//  BuyTime
//
//  Created by Baalavignesh Arunachalam on 3/5/26.
//

import SwiftUI

struct BuyTimeCard: View {

    let userName: String = "Baalavignesh A"
    let timeBalance: Int
    let tier: CardTier = .platinum

    var body: some View {
        ZStack {
            // Ambient gradient glow behind card
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.25),
                            Color.white.opacity(0.15),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 200
                    )
                )
                .blur(radius: 24)
                .frame(width: 310, height: 190)

            // Card
            cardContent
                .padding(.horizontal, 20)
                .frame(width: 300, height: 180)
                .cardBackground(tier: tier)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.35),
                                    Color.white.opacity(0.08),
                                    Color.white.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
        }
        .frame(width: 300, height: 180)
        .clipped()
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App Name - Top Center
            Text("ByTime")
                .font(.system(size: 18, weight: .light, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.top, 20)

            Spacer()

            // Logo - Center
            Image("dark_logo")
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
                .frame(maxWidth: .infinity)

            Spacer()

            // Time Balance
            HStack(spacing: 5) {
                Image(systemName: "timer")
                    .font(.system(size: 10))
                Text("\(timeBalance) min")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
            }
            .padding(.bottom, 8)

            // Bottom Row: Name & Tier
            HStack {
                Text(userName)
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1.5)

                Spacer()

                Text(tier.rawValue.uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .tracking(2)
            }
            .padding(.bottom, 14)
        }
    }
}

// MARK: - Liquid Glass / Fallback Background

private struct CardBackgroundModifier: ViewModifier {
    let tier: CardTier

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .background(.ultraThinMaterial)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        } else {
            content
                .background(tier.gradient)
        }
    }
}

extension View {
    func cardBackground(tier: CardTier) -> some View {
        modifier(CardBackgroundModifier(tier: tier))
    }
}

enum CardTier: String {
    case platinum = "Platinum"

    var gradient: LinearGradient {
        switch self {
        case .platinum:
            return LinearGradient(
                colors: [Color(UIColor.systemGray2), Color(UIColor.systemGray4), Color(UIColor.systemGray3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
