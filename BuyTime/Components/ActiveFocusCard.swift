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

    @State private var animateBlobs = false

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Base fill
                Color(.systemGray6)

                // Animated blurred blobs
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height

                    // Blob 1 - soft blue, drifts left half
                    Circle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: w * 0.7, height: w * 0.7)
                        .blur(radius: 40)
                        .position(
                            x: animateBlobs ? w * 0.2 : w * 0.45,
                            y: animateBlobs ? h * 0.25 : h * 0.65
                        )

                    // Blob 2 - sky blue, drifts right half
                    Circle()
                        .fill(Color.cyan.opacity(0.25))
                        .frame(width: w * 0.65, height: w * 0.65)
                        .blur(radius: 45)
                        .position(
                            x: animateBlobs ? w * 0.75 : w * 0.5,
                            y: animateBlobs ? h * 0.7 : h * 0.3
                        )

                    // Blob 3 - periwinkle, drifts center-left
                    Circle()
                        .fill(Color.indigo.opacity(0.2))
                        .frame(width: w * 0.6, height: w * 0.6)
                        .blur(radius: 50)
                        .position(
                            x: animateBlobs ? w * 0.35 : w * 0.65,
                            y: animateBlobs ? h * 0.75 : h * 0.35
                        )

                    // Blob 4 - light teal, drifts center-right
                    Circle()
                        .fill(Color.teal.opacity(0.25))
                        .frame(width: w * 0.6, height: w * 0.6)
                        .blur(radius: 35)
                        .position(
                            x: animateBlobs ? w * 0.6 : w * 0.3,
                            y: animateBlobs ? h * 0.3 : h * 0.7
                        )

                    // Blob 5 - right-side anchor
                    Circle()
                        .fill(Color.blue.opacity(0.25))
                        .frame(width: w * 0.7, height: w * 0.7)
                        .blur(radius: 45)
                        .position(
                            x: animateBlobs ? w * 0.8 : w * 0.65,
                            y: animateBlobs ? h * 0.4 : h * 0.6
                        )
                }

                // Content overlay
                VStack {
                    // Top row: label + mode
                    HStack {
                        Text("FOCUS SESSION")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .tracking(1)
                        Spacer()
                        Text(mode.rawValue.uppercased())
                            .font(.caption2)
                            .fontWeight(.medium)
                            .tracking(1)
                    }
                    .foregroundStyle(.secondary)

                    Spacer()

                    // Center: large countdown with glass background
                    if #available(iOS 26, *) {
                        Text(countdown)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 12)
                            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
                    } else {
                        Text(countdown)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 12)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }

                    Spacer()

                    // Bottom row: reward
                    HStack {
                        Text("~\(estimatedReward) min reward")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
                .padding(24)
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .onAppear {
                withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                    animateBlobs = true
                }
            }

            // End Early button
            Button(action: onEndEarly) {
                HStack {
                    Image(systemName: "xmark.circle").imageScale(.large)
                    Text("End Focus")
                }
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.red)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}
