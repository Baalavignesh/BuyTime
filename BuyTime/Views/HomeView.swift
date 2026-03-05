//
//  HomeView.swift
//  BuyTime
//
//  Created by Baalavignesh Arunachalam on 12/18/25.
//

import SwiftUI
import Combine

struct HomeView: View {
    @State var path = NavigationPath()
    @StateObject private var balanceVM = BalanceViewModel()
    @StateObject private var prefsVM = PreferencesViewModel()
    @Environment(\.scenePhase) private var scenePhase

    // Focus countdown state (local, updated by timer)
    @State private var isFocusActive = false
    @State private var focusTimeRemaining: TimeInterval = 0
    @State private var focusEndDate: Date = .distantFuture

    // Focus start UI
    @State private var isShowingCustomPicker = false
    @State private var customMinutes: Int = 30

    // Focus abandon UI
    @State private var isShowingEndFocusAlert = false

    private let focusPresets: [(label: String, minutes: Int)] = [
        ("15m", 15),
        ("30m", 30),
        ("1hr", 60)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                BuyTimeCard(timeBalance: balanceVM.availableMinutes).padding(.top, 32)

                if isFocusActive {
                    activeFocusSection
                } else {
                    startFocusSection
                }

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
        .refreshable {
            await balanceVM.refresh()
        }
        .onAppear {
            balanceVM.onAppear()
            prefsVM.onAppear()
            customMinutes = Int(prefsVM.focusDuration)
            syncFocusState()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                balanceVM.onForeground()
                checkPendingSessionEnd()
                syncFocusState()
                Task { await drainSyncQueue() }
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            tickTimer()
        }
        .sheet(isPresented: $isShowingCustomPicker) {
            TimePickerSheet(
                selectedMinutes: $customMinutes,
                title: "Custom Duration",
                buttonLabel: "Start",
                range: Array(stride(from: 10, through: 240, by: 5)),
                onConfirm: {
                    isShowingCustomPicker = false
                    startFocusSession(minutes: customMinutes)
                },
                onCancel: { isShowingCustomPicker = false }
            )
            .presentationDetents([.height(300)])
        }
        .alert("End Focus Early?", isPresented: $isShowingEndFocusAlert) {
            Button("End Focus", role: .destructive) {
                abandonFocusSession()
            }
            Button("Keep Focusing", role: .cancel) {}
        } message: {
            let balance = SharedData.earnedTimeMinutes
            if balance > 0 {
                Text("Your wallet balance of \(balance) min will be halved to \(balance / 2) min as a penalty.")
            } else {
                Text("Your focus session will end with no reward.")
            }
        }
    }

    // MARK: - Start Focus Section

    @ViewBuilder
    private var startFocusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupBox {
            HStack(spacing: 10) {
                ForEach(focusPresets, id: \.minutes) { preset in
                    Button(preset.label) {
                        startFocusSession(minutes: preset.minutes)
                    }
                    .buttonStyle(ChipButtonStyle())
                }

                Button {
                    isShowingCustomPicker = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .buttonStyle(ChipButtonStyle())
            }
            } label: {
                Text("Start Focus Session")
                    .font(.headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Active Focus Section

    @ViewBuilder
    private var activeFocusSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 10) {
                HStack {
                    Text("Focus Session Active")
                        .font(.headline)
                    Spacer()
                }

                Text(formatCountdown(focusTimeRemaining))
                    .font(.system(size: 52, weight: .light, design: .monospaced))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)

                let mode = Mode(rawValue: SharedData.focusMode) ?? .easy
                let plannedMinutes = SharedData.focusPlannedMinutes
                let estimatedReward = Int(Double(plannedMinutes) * mode.multiplier)

                HStack(spacing: 6) {
                    Text("Mode: \(mode.rawValue)")
                    Text("•")
                    Text("Reward: ~\(estimatedReward) min")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(20)
            .background(Color(.systemIndigo).opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Button("End Focus Early") {
                isShowingEndFocusAlert = true
            }
            .foregroundStyle(.red)
        }
    }




    // MARK: - Timer

    private func tickTimer() {
        guard isFocusActive else { return }
        focusTimeRemaining = max(0, focusEndDate.timeIntervalSinceNow)
        if focusTimeRemaining <= 0 {
            syncFocusState()
        }
    }

    // MARK: - Focus State Sync

    private func syncFocusState() {
        isFocusActive = SharedData.isFocusCurrentlyActive
        if isFocusActive {
            focusEndDate = Date(timeIntervalSince1970: SharedData.focusEndTime)
            focusTimeRemaining = max(0, focusEndDate.timeIntervalSinceNow)
        }
    }

    // MARK: - Pending Session End

    private func checkPendingSessionEnd() {
        guard SharedData.pendingSessionEnd else { return }
        SharedData.pendingSessionEnd = false

        // Capture all values before clearing state
        let sessionId = SharedData.focusSessionId
        let actualMinutes = SharedData.pendingActualMinutes
        let modeStr = SharedData.focusMode
        let plannedMinutes = SharedData.focusPlannedMinutes

        // Credit reward locally immediately
        let mode = Mode(rawValue: modeStr) ?? .easy
        let reward = Int(Double(actualMinutes) * mode.multiplier)
        if reward > 0 {
            balanceVM.addMinutes(reward)
        }

        SharedData.pendingActualMinutes = 0
        SharedData.clearFocusSessionState()
        syncFocusState()

        // Fire API in background, queue on failure
        guard !sessionId.isEmpty, actualMinutes > 0 else { return }
        Task {
            do {
                _ = try await BuyTimeAPI.shared.endSession(
                    sessionId: sessionId,
                    actualDurationMinutes: actualMinutes
                )
            } catch {
                SharedData.enqueueSyncOperation(SyncOperation(
                    kind: .end,
                    sessionId: sessionId,
                    mode: modeStr,
                    plannedMinutes: plannedMinutes,
                    actualMinutes: actualMinutes,
                    createdAt: Date()
                ))
            }
        }
    }

    // MARK: - Start Focus (Local-First)

    private func startFocusSession(minutes: Int) {
        let mode = prefsVM.focusMode.rawValue

        // Start monitoring locally — instant, no network needed
        AppBlockUtils().startFocusMonitoring(minutes: minutes, mode: mode)
        syncFocusState()

        // Fire API in background
        let sessionId = SharedData.focusSessionId
        Task {
            do {
                _ = try await BuyTimeAPI.shared.startSession(
                    sessionId: sessionId,
                    mode: mode,
                    plannedDurationMinutes: minutes
                )
            } catch {
                SharedData.enqueueSyncOperation(SyncOperation(
                    kind: .start,
                    sessionId: sessionId,
                    mode: mode,
                    plannedMinutes: minutes,
                    actualMinutes: 0,
                    createdAt: Date()
                ))
            }
        }
    }

    // MARK: - Abandon Focus (Local-First)

    private func abandonFocusSession() {
        let sessionId = SharedData.focusSessionId
        let currentBalance = SharedData.earnedTimeMinutes

        // Stop monitoring and clear flags immediately
        AppBlockUtils().stopFocusMonitoring()

        // Apply wallet balance penalty locally (halve if > 0)
        if currentBalance > 0 {
            let newBalance = currentBalance / 2
            Task { await balanceVM.setBalance(newBalance) }
        }

        // Clear session state
        let modeStr = SharedData.focusMode
        SharedData.clearFocusSessionState()
        syncFocusState()

        // Fire API in background, queue on failure
        guard !sessionId.isEmpty else { return }
        Task {
            do {
                _ = try await BuyTimeAPI.shared.abandonSession(sessionId: sessionId)
            } catch {
                SharedData.enqueueSyncOperation(SyncOperation(
                    kind: .abandon,
                    sessionId: sessionId,
                    mode: modeStr,
                    plannedMinutes: 0,
                    actualMinutes: 0,
                    createdAt: Date()
                ))
            }
        }
    }

    // MARK: - Offline Sync Queue

    @MainActor
    private func drainSyncQueue() async {
        var queue = SharedData.pendingSyncOperations
        guard !queue.isEmpty else { return }

        let staleThreshold = Date().addingTimeInterval(-24 * 60 * 60)
        var remaining: [SyncOperation] = []

        for op in queue {
            // Drop stale operations (>24h old)
            if op.createdAt < staleThreshold { continue }

            do {
                switch op.kind {
                case .start:
                    _ = try await BuyTimeAPI.shared.startSession(
                        sessionId: op.sessionId,
                        mode: op.mode,
                        plannedDurationMinutes: op.plannedMinutes
                    )
                case .end:
                    _ = try await BuyTimeAPI.shared.endSession(
                        sessionId: op.sessionId,
                        actualDurationMinutes: op.actualMinutes
                    )
                case .abandon:
                    _ = try await BuyTimeAPI.shared.abandonSession(sessionId: op.sessionId)
                }
                // Success — don't re-enqueue
            } catch {
                // Failed again — keep in queue for next attempt
                remaining.append(op)
            }
        }

        SharedData.pendingSyncOperations = remaining
    }

    // MARK: - Helpers

    private func formatCountdown(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

}

private struct BuyTimeCard: View {

    let userName: String = "Baalavignesh A"
    let timeBalance: Int
    let tier: CardTier = .platinum
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App Name - Top Center
            Text("ByTime")
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
