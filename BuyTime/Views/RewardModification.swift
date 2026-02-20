//
//  RewardModification.swift
//  BuyTime
//
//  Created by Baalavignesh Arunachalam on 1/22/26.
//

import SwiftUI

enum Mode: String, CaseIterable {
    case hard, medium, easy, fun

    var multiplier: Double {
        switch self {
        case .hard:   return 0.25
        case .medium: return 0.5
        case .easy:   return 0.75
        case .fun:    return 1.0
        }
    }

    var displayName: String {
        switch self {
        case .hard:   return "Hard 25%"
        case .medium: return "Medium 50%"
        case .easy:   return "Easy 75%"
        case .fun:    return "Relax 100%"
        }
    }

    static let orderedModes: [Mode] = [.hard, .medium, .easy, .fun]
}


struct RewardModification: View {

    @StateObject private var vm = PreferencesViewModel()

    // MARK: - Computed Properties

    // Reward is always derived from focus and mode — no separate state.
    private var rewardMinutes: Double {
        vm.focusDuration * vm.focusMode.multiplier
    }

    var formattedWorkTime: (hours: Int, minutes: Int) {
        let totalMinutes = Int(vm.focusDuration * 8)
        return (totalMinutes / 60, totalMinutes % 60)
    }

    var formattedRewardTime: (hours: Int, minutes: Int) {
        let totalMinutes = Int(rewardMinutes * 8)
        return (totalMinutes / 60, totalMinutes % 60)
    }


    // Reward slider is bidirectional: dragging it back-calculates focus and auto-switches
    // mode when the current mode can't produce a valid focus (15...60) for the reward value.
    //
    // focus < 15 → reward too low for mode → try a harder mode (lower multiplier raises focus)
    // focus > 60 → reward too high for mode → try an easier mode (higher multiplier lowers focus)
    private var rewardBinding: Binding<Double> {
        Binding(
            get: { rewardMinutes },
            set: { newValue in
                var targetFocus = newValue / vm.focusMode.multiplier
                var selectedMode = vm.focusMode

                if targetFocus < 15 {
                    // Need multiplier ≤ newValue/15 — pick the largest such multiplier
                    // (keeps focus as close to 15 as possible from above)
                    let maxMultiplier = newValue / 15.0
                    if let mode = Mode.orderedModes
                        .filter({ $0.multiplier <= maxMultiplier })
                        .max(by: { $0.multiplier < $1.multiplier }) {
                        selectedMode = mode
                        targetFocus = newValue / mode.multiplier
                    } else {
                        targetFocus = 15.0 // no mode can satisfy it, clamp
                    }
                } else if targetFocus > 60 {
                    // Need multiplier ≥ newValue/60 — pick the smallest such multiplier
                    // (keeps focus as close to 60 as possible from below)
                    let minMultiplier = newValue / 60.0
                    if let mode = Mode.orderedModes
                        .filter({ $0.multiplier >= minMultiplier })
                        .min(by: { $0.multiplier < $1.multiplier }) {
                        selectedMode = mode
                        targetFocus = newValue / mode.multiplier
                    } else {
                        targetFocus = 60.0 // no mode can satisfy it, clamp
                    }
                }

                vm.focusMode = selectedMode
                vm.focusDuration = max(15.0, min(60.0, targetFocus))
                vm.onPreferenceChanged()
            }
        )
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 28) {

                // MARK: - Header
                VStack(spacing: 4) {
                    Text("Your Day, Planned")
                        .font(.system(.largeTitle, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)

                    Text("The totals below are how much work and reward you'll accumulate across the entire day.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                }

                // MARK: - Loading / Time Display Cards
                if vm.isLoading {
                    ProgressView()
                        .tint(.white)
                        .frame(height: 100)
                } else {
                    HStack(spacing: 16) {
                        // Work Time Card
                        VStack(spacing: 8) {
                            Text("WORK")
                                .font(.system(.caption, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundColor(.white.opacity(0.5))
                                .tracking(2)

                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text("\(formattedWorkTime.hours)")
                                    .font(.system(size: 32, weight: .medium, design: .rounded))
                                    .foregroundColor(.white)
                                Text("h")
                                    .font(.system(.title3, design: .rounded))
                                    .foregroundColor(.white.opacity(0.6))
                                Text("\(formattedWorkTime.minutes)")
                                    .font(.system(size: 32, weight: .medium, design: .rounded))
                                    .foregroundColor(.white)
                                Text("m")
                                    .font(.system(.title3, design: .rounded))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 100)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        // Reward Time Card
                        VStack(spacing: 8) {
                            Text("REWARD")
                                .font(.system(.caption, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundColor(.white.opacity(0.5))
                                .tracking(2)

                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text("\(formattedRewardTime.hours)")
                                    .font(.system(size: 32, weight: .medium, design: .rounded))
                                    .foregroundColor(.white)
                                Text("h")
                                    .font(.system(.title3, design: .rounded))
                                    .foregroundColor(.white.opacity(0.6))
                                Text("\(formattedRewardTime.minutes)")
                                    .font(.system(size: 32, weight: .medium, design: .rounded))
                                    .foregroundColor(.white)
                                Text("m")
                                    .font(.system(.title3, design: .rounded))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 100)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }

                // MARK: - Sliders
                VStack(spacing: 24) {
                    SliderSection(
                        title: "Focus Duration",
                        value: $vm.focusDuration,
                        range: 15...60,
                        unit: "min"
                    ) {
                        vm.onPreferenceChanged()
                    }

                    // Reward: derived from focus × multiplier, but also adjustable.
                    // Moving this back-calculates focus, clamped to 15...60.
                    // Min 4 = floor(15 × 0.25) — hard mode at minimum focus.
                    SliderSection(
                        title: "Reward Duration",
                        value: rewardBinding,
                        range: 4...60,
                        unit: "min"
                    ) {}
                }

                // MARK: - Mode Buttons
                VStack(spacing: 12) {
                    Text("DIFFICULTY")
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.5))
                        .tracking(2)

                    HStack(spacing: 12) {
                        ForEach([Mode.fun, Mode.easy, Mode.medium, Mode.hard], id: \.self) { mode in
                            ModeButton(
                                mode: mode,
                                isSelected: vm.focusMode == mode
                            ) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    vm.focusMode = mode
                                    vm.onPreferenceChanged()
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 16)
            }
            .padding(.horizontal, 24)

            // MARK: - Error Banner
            if let message = vm.errorMessage {
                Text(message)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.85))
                    .clipShape(Capsule())
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut, value: vm.errorMessage)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .navigationTitle("Configure Your Balance")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            vm.onAppear()
        }
    }
}

// MARK: - Slider Section Component
// (unchanged from original)

struct SliderSection: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let unit: String
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.7))

                Spacer()

                Text("\(Int(value)) \(unit)")
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            Slider(value: $value, in: range)
                .tint(.white)
                .onChange(of: value) {
                    onChange()
                }

            HStack {
                Text("\(Int(range.lowerBound))")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))

                Spacer()

                Text("\(Int(range.upperBound))")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }
}

// MARK: - Mode Button Component
// (unchanged from original)

struct ModeButton: View {
    let mode: Mode
    let isSelected: Bool
    let action: () -> Void

    private var label: String {
        switch mode {
        case .fun:    return "Relax"
        case .easy:   return "Easy"
        case .medium: return "Medium"
        case .hard:   return "Hard"
        }
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(isSelected ? .black : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.white : Color.white.opacity(0.08))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(isSelected ? 0 : 0.2), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}


#Preview {
    RewardModification()
}
