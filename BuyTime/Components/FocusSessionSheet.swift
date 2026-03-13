//
//  FocusSessionSheet.swift
//  BuyTime
//
//  Confirmation sheet with swipe-to-start slider for focus sessions.
//

import SwiftUI

struct FocusSessionSheet: View {

    let selectedMinutes: Int
    var onConfirm: () -> Void
    var onCancel: (() -> Void)? = nil

    @StateObject private var prefsVM = PreferencesViewModel()

    private var mode: Mode { prefsVM.focusMode }
    private var estimatedReward: Int { Int(Double(selectedMinutes) * mode.multiplier) }
    private var endTime: Date { Date.now.addingTimeInterval(Double(selectedMinutes) * 60) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Info section
                VStack(spacing: 0) {
                    infoRow("Duration", value: formatDuration(selectedMinutes))
                    Divider().padding(.horizontal, 16)
                    infoRow("Mode", value: mode.displayName)
                    Divider().padding(.horizontal, 16)
                    infoRow("Est. Reward", value: "~\(estimatedReward) min")
                    Divider().padding(.horizontal, 16)
                    HStack {
                        Text("Ends At")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(endTime, format: .dateTime.hour().minute())
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(Color(white: 0.13))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.10), lineWidth: 0.5))
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Spacer()

                SwipeToStartSlider(label: "Slide to Start", onSuccess: onConfirm)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
            }
            .navigationTitle("Start Focus Session")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationBackground(Color(white: 0.07))
    }

    // MARK: - Helpers

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func formatDuration(_ minutes: Int) -> String {
        FormatUtils.duration(minutes)
    }
}

// MARK: - SwipeToStartSlider

private struct SwipeToStartSlider: View {
    let label: String
    let onSuccess: () -> Void

    private let trackHeight: CGFloat = 50
    private let thumbSize: CGFloat = 40
    private let edgePadding: CGFloat = 5
    private let triggerThreshold: CGFloat = 0.8

    @State private var dragOffset: CGFloat = 0
    @State private var isCompleted = false
    @State private var isDragging = false
    @State private var lastHapticPercent: Int = 0
    @State private var hapticTrigger: Int = 0
    @State private var completionTrigger: Bool = false
    @State private var failureTrigger: Bool = false

    var body: some View {
        GeometryReader { geo in
            let maxDrag = geo.size.width - thumbSize - edgePadding * 2
            let progress = maxDrag > 0 ? min(dragOffset / maxDrag, 1.0) : 0

            ZStack(alignment: .leading) {
                // Track background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(white: 0.20))
                    .frame(height: trackHeight)
                    .clipShape(.rect(cornerRadius: 8))
                    // Glossy border — visible on all sides
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.30),
                                        .white.opacity(0.12),
                                        .white.opacity(0.08),
                                        .white.opacity(0.12),
                                        .white.opacity(0.20)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    }
                    // Soft inner shadow for inset depth
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.black.opacity(0.25), lineWidth: 1)
                            .blur(radius: 1)
                            .offset(y: 1)
                            .mask(RoundedRectangle(cornerRadius: 8).fill(.black))
                    }
                    // Subtle outer glow
                    .shadow(color: .white.opacity(0.06), radius: 2, y: -1)

                // Fill layer
                RoundedRectangle(cornerRadius: 8)
                    .fill(isCompleted ? Color.green : Color.white)
                    .opacity(0.85)
                    .frame(width: dragOffset + thumbSize + edgePadding * 2, height: trackHeight)

                // Label
                Text(label)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .opacity(1.0 - Double(progress) * 1.2)

                // Thumb
                RoundedRectangle(cornerRadius: 8)
                    .fill(isCompleted ? Color.green : Color.black)
                    .frame(width: thumbSize, height: thumbSize)
                    .overlay {
                        Image(systemName: isCompleted ? "checkmark" : "chevron.right.2")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.35), .white.opacity(0.1)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.75
                            )
                    }
                    .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
                    .offset(x: edgePadding + dragOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                guard !isCompleted else { return }
                                if !isDragging {
                                    isDragging = true
                                    lastHapticPercent = 0
                                    hapticTrigger += 1
                                }
                                dragOffset = min(max(0, value.translation.width), maxDrag)

                                // Haptics at 25% intervals
                                let currentPercent = Int(progress * 4) // 0,1,2,3
                                if currentPercent > lastHapticPercent {
                                    lastHapticPercent = currentPercent
                                    hapticTrigger += 1
                                }
                            }
                            .onEnded { _ in
                                guard !isCompleted else { return }
                                isDragging = false

                                if progress >= triggerThreshold {
                                    // Success
                                    isCompleted = true
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        dragOffset = maxDrag
                                    }
                                    completionTrigger.toggle()
                                    Task {
                                        try? await Task.sleep(for: .milliseconds(300))
                                        onSuccess()
                                    }
                                } else {
                                    // Fail — spring back
                                    failureTrigger.toggle()
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                        dragOffset = 0
                                    }
                                    lastHapticPercent = 0
                                }
                            }
                    )
            }
            .padding(.vertical, 20)
        }
        .frame(height: trackHeight)
        .sensoryFeedback(.impact(flexibility: .solid, intensity: 0.6), trigger: hapticTrigger)
        .sensoryFeedback(.success, trigger: completionTrigger)
        .sensoryFeedback(.warning, trigger: failureTrigger)
    }
}
