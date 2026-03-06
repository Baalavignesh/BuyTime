//
//  FocusViewModel.swift
//  BuyTime
//
//  Focus session lifecycle: start, abandon, pending session end,
//  timer state, and offline sync queue.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class FocusViewModel: ObservableObject {

    // MARK: - Dependencies (injected from HomeView)

    private let balanceVM: BalanceViewModel
    private let prefsVM: PreferencesViewModel

    init(balanceVM: BalanceViewModel, prefsVM: PreferencesViewModel) {
        self.balanceVM = balanceVM
        self.prefsVM = prefsVM
    }

    // MARK: - Published State

    @Published private(set) var isFocusActive = false
    @Published private(set) var focusTimeRemaining: TimeInterval = 0
    @Published private(set) var focusEndDate: Date = .distantFuture

    // MARK: - Focus State Sync

    func syncFocusState() {
        isFocusActive = SharedData.isFocusCurrentlyActive
        if isFocusActive {
            focusEndDate = Date(timeIntervalSince1970: SharedData.focusEndTime)
            focusTimeRemaining = max(0, focusEndDate.timeIntervalSinceNow)
        }
    }

    // MARK: - Timer

    func tick() {
        guard isFocusActive else { return }
        focusTimeRemaining = max(0, focusEndDate.timeIntervalSinceNow)
        if focusTimeRemaining <= 0 {
            syncFocusState()
        }
    }

    // MARK: - Start Focus (Local-First)

    func startFocusSession(minutes: Int) {
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

    func abandonFocusSession() {
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

    // MARK: - Pending Session End

    func checkPendingSessionEnd() {
        guard SharedData.pendingSessionEnd else { return }
        SharedData.pendingSessionEnd = false

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

    // MARK: - Offline Sync Queue

    func drainSyncQueue() async {
        var queue = SharedData.pendingSyncOperations
        guard !queue.isEmpty else { return }

        let staleThreshold = Date().addingTimeInterval(-24 * 60 * 60)
        var remaining: [SyncOperation] = []

        for op in queue {
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
            } catch {
                remaining.append(op)
            }
        }

        SharedData.pendingSyncOperations = remaining
    }

    // MARK: - Helpers

    func formatCountdown(_ interval: TimeInterval) -> String {
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
