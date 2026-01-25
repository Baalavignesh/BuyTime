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
    case .hard: return 0.25
    case .medium: return 0.33
    case .easy: return 0.5
    case .fun: return 1.0
    }
  }

  var displayName: String {
    switch self {
    case .hard: return "Hard 25%"
    case .medium: return "Medium 33%"
    case .easy: return "Easy 50%"
    case .fun: return "Relax 100%"
    }
  }

  static let orderedModes: [Mode] = [.hard, .medium, .easy, .fun]
}

enum Parameter {
  case focusTime
  case rewardTime
}

struct RewardModification: View {

  @State private var focusTime = 30.0
  @State private var rewardTime = 15.0
  @State private var selectedMode: Mode = .easy

  // MARK: - Computed Properties

  var formattedWorkTime: (hours: Int, minutes: Int) {
    let totalMinutes = Int(focusTime * 8)
    return (totalMinutes / 60, totalMinutes % 60)
  }

  var formattedRewardTime: (hours: Int, minutes: Int) {
    let totalMinutes = Int(rewardTime * 8)
    return (totalMinutes / 60, totalMinutes % 60)
  }

  // MARK: - Functions

  func calculateReward(parameter: Parameter, value: Double) {
    var multiplier = selectedMode.multiplier

    if parameter == .focusTime {
      withAnimation(.easeInOut(duration: 0.15)) {
        rewardTime = value * multiplier
      }
    } else if parameter == .rewardTime {
      var calculatedFocus = value / multiplier

      while calculatedFocus > 60.0 {
        if let currentIndex = Mode.orderedModes.firstIndex(of: selectedMode),
          currentIndex < Mode.orderedModes.count - 1
        {
          selectedMode = Mode.orderedModes[currentIndex + 1]
          multiplier = selectedMode.multiplier
          calculatedFocus = value / multiplier
        } else {
          calculatedFocus = 60.0
          break
        }
      }
      withAnimation(.easeInOut(duration: 0.15)) {
        focusTime = calculatedFocus
      }
    }
      
      
  }

  // MARK: - Body

  var body: some View {
      VStack(spacing: 28) {

        // MARK: - Header
        VStack(spacing: 4) {
          Text("Based on the 8-8-8 Rule")
                .font(.system(.largeTitle, design: .rounded))
                .foregroundColor(.white.opacity(0.5)).multilineTextAlignment(.center)

          Text(
            "8 hrs work, 8 hrs play, 8 hrs rest. Set your reward time based on your daily work activity."
          )
            .font(.system(.subheadline, design: .rounded))
            .foregroundColor(.white.opacity(0.5))
            .multilineTextAlignment(.center)
        }

        // MARK: - Time Display Cards
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

        // MARK: - Sliders Section
        VStack(spacing: 24) {
          // Focus Slider
          SliderSection(
            title: "Focus Duration",
            value: $focusTime,
            range: 0...60,
            unit: "min"
          ) {
            calculateReward(parameter: .focusTime, value: focusTime)
          }

          // Reward Slider
          SliderSection(
            title: "Reward Duration",
            value: $rewardTime,
            range: 0...60,
            unit: "min"
          ) {
            calculateReward(parameter: .rewardTime, value: rewardTime)
          }
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
                isSelected: selectedMode == mode
              ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                  selectedMode = mode
                  calculateReward(parameter: .focusTime, value: focusTime)
                }
              }
            }
          }
        }
        .padding(.bottom, 16)
      }.padding(.horizontal, 24)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.black)
      .navigationTitle("Configure Your Balance")
      .navigationBarTitleDisplayMode(.inline)
      .toolbarColorScheme(.dark, for: .navigationBar)
      .toolbarBackground(Color.black, for: .navigationBar)
      .toolbarBackground(.visible, for: .navigationBar)
      
    }
  
}

// MARK: - Slider Section Component

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

      Slider(value: $value, in: range, step: 15)
        .tint(.white)
        .animation(.easeInOut(duration: 0.15), value: value)
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

struct ModeButton: View {
  let mode: Mode
  let isSelected: Bool
  let action: () -> Void

  private var label: String {
    switch mode {
    case .fun: return "Relax"
    case .easy: return "Easy"
    case .medium: return "Medium"
    case .hard: return "Hard"
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
