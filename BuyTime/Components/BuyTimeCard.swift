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
        ZStack(alignment: .leading) {
            // Left-side pixel grid pattern
            pixelPattern
                .frame(width: 160)
                .clipped()
                .mask(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.6),
                            Color.white.opacity(0.15),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            VStack(alignment: .leading, spacing: 0) {
                // Top Row: Logo + ByTime
                HStack(spacing: 4) {
                    Image("dark_logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)

                    Text("ByTime")
                        .font(.system(size: 16, weight: .light, design: .rounded))
                }
                .padding(.top, 16)

                Spacer()

                // Middle Row
                HStack {
                    Spacer()

                    Image(systemName: "wifi")
                        .font(.system(size: 20, weight: .thin))
                        .foregroundStyle(.white.opacity(0.65))
                        .rotationEffect(.degrees(90))
                }

                Spacer()

                // Time Balance
                HStack(spacing: 5) {
                    Image(systemName: "timer")
                        .font(.system(size: 10))
                    Text("\(timeBalance) min")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                }
                .padding(.bottom, 6)

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
            .padding(.horizontal, 20)
        }
    }

    private var pixelPattern: some View {
        Canvas { context, size in
            let cellSize: CGFloat = 6
            let gap: CGFloat = 2
            let step = cellSize + gap
            let cols = Int(size.width / step) + 1
            let rows = Int(size.height / step) + 1

            for row in 0..<rows {
                for col in 0..<cols {
                    // Deterministic pseudo-random using simple hash
                    let hash = (row * 31 + col * 17 + row * col * 7) % 100
                    let opacity = hash < 30 ? 0.12 : (hash < 45 ? 0.06 : 0.0)

                    if opacity > 0 {
                        let rect = CGRect(
                            x: CGFloat(col) * step,
                            y: CGFloat(row) * step,
                            width: cellSize,
                            height: cellSize
                        )
                        context.fill(
                            Path(roundedRect: rect, cornerRadius: 1),
                            with: .color(.white.opacity(opacity))
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Liquid Glass / Fallback Background

private struct CardBackgroundModifier: ViewModifier {
    let tier: CardTier

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .background(Color(white: 0.06))
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
