//
//  ActiveFocusCard.swift
//  BuyTime
//
//  Created by Baalavignesh Arunachalam on 03/09/26.
//

import SwiftUI

struct ActiveFocusCard: View {
    let countdown: String
    let mode: Mode
    let estimatedReward: Int
    var onEndEarly: () -> Void

    @State private var blob1Active = false
    @State private var blob2Active = false
    @State private var blob3Active = false
    @State private var blob4Active = false

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Base
                Color(white: 0.06)

                // 3 distinct greyscale blobs — smaller, sharper, wider travel
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height

                    // Blob 1 — brightest, top-left ↔ bottom-right
                    Circle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: w * 0.35, height: w * 0.35)
                        .blur(radius: 20)
                        .position(
                            x: blob1Active ? w * 0.15 : w * 0.8,
                            y: blob1Active ? h * 0.2 : h * 0.75
                        )

                    // Blob 2 — medium, bottom-left ↔ top-right
                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: w * 0.3, height: w * 0.3)
                        .blur(radius: 22)
                        .position(
                            x: blob2Active ? w * 0.85 : w * 0.2,
                            y: blob2Active ? h * 0.25 : h * 0.8
                        )

                    // Blob 3 — subtle, wanders center
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: w * 0.32, height: w * 0.32)
                        .blur(radius: 25)
                        .position(
                            x: blob3Active ? w * 0.35 : w * 0.65,
                            y: blob3Active ? h * 0.7 : h * 0.3
                        )

                    // Blob 4 — mid-bright, top-right ↔ bottom-left
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: w * 0.28, height: w * 0.28)
                        .blur(radius: 18)
                        .position(
                            x: blob4Active ? w * 0.75 : w * 0.25,
                            y: blob4Active ? h * 0.8 : h * 0.15
                        )
                }
                .drawingGroup()

                // Content overlay
                VStack {
                    // Top row: label + mode
                    HStack {
                        Text("FOCUS SESSION")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .tracking(2)
                        Spacer()
                        Text(mode.rawValue.uppercased())
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .tracking(2)
                    }
                    .foregroundStyle(.white.opacity(0.4))

                    Spacer()

                    // Center: large countdown — fixed width so it doesn't resize
                    if #available(iOS 26, *) {
                        Text(countdown)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                            .frame(width: 200)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 12)
                            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
                    } else {
                        Text(countdown)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                            .frame(width: 200)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 12)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }

                    Spacer()

                    // Bottom row: reward
                    HStack {
                        Text("~\(estimatedReward) min reward")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.35))
                        Spacer()
                    }
                }
                .padding(24)
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.06),
                                Color.white.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                    blob1Active = true
                }
                withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) {
                    blob2Active = true
                }
                withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                    blob3Active = true
                }
                withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                    blob4Active = true
                }
            }

            // End Early
            Button(action: onEndEarly) {
                Text("End Focus")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(.red.opacity(0.25), lineWidth: 0.5)
                    )
            }.padding(.bottom, 32)
        }
    }
}
