//
//  ActiveFocusCard.swift
//  BuyTime
//
//  Created by Baalavignesh Arunachalam on 03/09/26.
//

import SwiftUI

struct ActiveFocusCard: View {
    let isExpanded: Bool
    let countdown: String
    let mode: Mode
    let estimatedReward: Int
    var onCollapse: (() -> Void)? = nil
    var onEndEarly: (() -> Void)? = nil

    @State private var startTime: Date = .now

    var body: some View {
        ZStack {
            shaderBackground
                .ignoresSafeArea(edges: isExpanded ? .all : [])

            VStack {
                topBar
                Spacer()
                timerSection
                Spacer()
                bottomSection
            }
            .padding(24)
            .padding(.top, isExpanded ? 36 : 0)
            .padding(.bottom, isExpanded ? 16 : 0)
        }
        .frame(height: isExpanded ? nil : 200)
        .clipShape(RoundedRectangle(cornerRadius: isExpanded ? 0 : 20))
        .overlay {
            if !isExpanded {
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
            }
        }
        .contentShape(Rectangle())
    }

    // MARK: - Shader Background

    @ViewBuilder
    private var shaderBackground: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startTime)
            GeometryReader { geo in
                Color.black
                    .colorEffect(
                        ShaderLibrary.focusBackground(
                            .float2(Float(geo.size.width), Float(geo.size.height)),
                            .float(Float(elapsed)),
                            .float(Float(isExpanded ? 1.3 : 1.0))
                        )
                    )
            }
        }
    }

    // MARK: - Top Bar

    @ViewBuilder
    private var topBar: some View {
        HStack {
            if isExpanded {
                Button("Collapse", systemImage: "chevron.down") { onCollapse?() }
                    .labelStyle(.iconOnly)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            } else {
                Text("FOCUS SESSION")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            Text(mode.rawValue.uppercased())
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    // MARK: - Timer

    @ViewBuilder
    private var timerSection: some View {
        VStack(spacing: isExpanded ? 16 : 0) {
            if isExpanded {
                Text("FOCUS SESSION")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(.white.opacity(0.35))
            }

            timerView

            if isExpanded {
                Text("~\(estimatedReward) min reward")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
    }

    @ViewBuilder
    private var timerView: some View {
        let fontSize: CGFloat = isExpanded ? 72 : 48
        let hPad: CGFloat = isExpanded ? 36 : 28
        let vPad: CGFloat = isExpanded ? 16 : 12
        let radius: CGFloat = isExpanded ? 20 : 12

        if #available(iOS 26, *) {
            Text(countdown)
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isExpanded ? .white : .primary)
                .frame(width: isExpanded ? nil : 200)
                .padding(.horizontal, hPad)
                .padding(.vertical, vPad)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: radius))
        } else {
            Text(countdown)
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isExpanded ? .white : .primary)
                .frame(width: isExpanded ? nil : 200)
                .padding(.horizontal, hPad)
                .padding(.vertical, vPad)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius))
        }
    }

    // MARK: - Bottom

    @ViewBuilder
    private var bottomSection: some View {
        if isExpanded {
            Button { onEndEarly?() } label: {
                Text("End Focus")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(.red.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.red.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.red.opacity(0.2), lineWidth: 0.5)
                    )
            }
        } else {
            HStack {
                Text("~\(estimatedReward) min reward")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
                Spacer()
            }
        }
    }
}
