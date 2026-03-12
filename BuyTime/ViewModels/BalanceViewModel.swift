//
//  BalanceViewModel.swift
//  BuyTime
//
//  Manages the user's available minutes balance.
//
//  Source of truth: server (API) for balance, SharedData for local display.
//
//  Sync model:
//    On foreground: GET api balance → apply shieldSpendDelta if any → accept server value
//    Shield extension writes explicit shieldSpendDelta — no inferred deltas.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class BalanceViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var availableMinutes: Int = 0
    @Published var isRefreshing: Bool = false

    // Today's stats (populated from GET /api/balance → today)
    @Published private(set) var todayEarnedMinutes: Int = 0
    @Published private(set) var todaySpentMinutes: Int = 0
    @Published private(set) var todaySessionsCompleted: Int = 0

    // MARK: - Persistence

    /// Whether we've ever synced with the API.
    private var hasSynced: Bool {
        UserDefaults.standard.bool(forKey: "balance_hasSynced")
    }

    private func markSynced() {
        UserDefaults.standard.set(true, forKey: "balance_hasSynced")
    }

    // MARK: - Init

    init() {
        availableMinutes = SharedData.earnedTimeMinutes
    }

    // MARK: - Lifecycle Hooks

    /// Call from `.onAppear`. Fetches on first-ever launch.
    func onAppear() {
        guard !hasSynced else { return }
        Task { await performSync(showSpinner: false) }
    }

    /// Call when `scenePhase` changes to `.active`.
    /// Always syncs to pick up changes from other devices and apply shield spend delta.
    func onForeground() {
        availableMinutes = SharedData.earnedTimeMinutes
        Task { await performSync(showSpinner: false) }
    }

    // MARK: - Pull-to-Refresh

    /// Call from `.refreshable`. Always GETs; only PATCHes if there is a pending delta.
    func refresh() async {
        await performSync(showSpinner: true)
    }

    // MARK: - Balance Mutations (called by main app, e.g. focus session completion)

    /// Earn minutes from a completed focus session. Updates local immediately, then syncs.
    func addMinutes(_ amount: Int) {
        let newValue = max(0, SharedData.earnedTimeMinutes + amount)
        SharedData.earnedTimeMinutes = newValue
        availableMinutes = newValue
        Task { await performSync(showSpinner: false) }
    }

    /// Set the balance to an exact absolute value and sync to server.
    func setBalance(_ amount: Int) async {
        let newValue = max(0, amount)
        SharedData.earnedTimeMinutes = newValue
        availableMinutes = newValue

        do {
            let confirmed = try await BuyTimeAPI.shared.updateBalance(availableMinutes: newValue)
            SharedData.earnedTimeMinutes = confirmed.availableMinutes
            availableMinutes = confirmed.availableMinutes
        } catch {
            // Silent — will sync on next foreground
        }
    }

    // MARK: - Core Sync

    /// Fetches server balance, applies any shield spend delta, then accepts the result.
    private func performSync(showSpinner: Bool) async {
        if showSpinner { isRefreshing = true }
        defer { if showSpinner { isRefreshing = false } }

        do {
            let apiBalance = try await BuyTimeAPI.shared.getBalance()

            // Update today's stats
            if let today = apiBalance.today {
                todayEarnedMinutes = today.earnedMinutes
                todaySpentMinutes = today.spentMinutes
                todaySessionsCompleted = today.sessionsCompleted
            }

            // Check if the shield extension spent minutes while we were backgrounded
            let shieldDelta = SharedData.shieldSpendDelta

            if shieldDelta != 0 {
                // Apply shield spend to server balance, then reset
                let newAbsolute = max(0, apiBalance.availableMinutes + shieldDelta)
                let confirmed = try await BuyTimeAPI.shared.updateBalance(availableMinutes: newAbsolute)
                SharedData.shieldSpendDelta = 0
                SharedData.earnedTimeMinutes = confirmed.availableMinutes
            } else {
                // No shield changes — accept server value (picks up other-device changes)
                SharedData.earnedTimeMinutes = apiBalance.availableMinutes
            }

            availableMinutes = SharedData.earnedTimeMinutes
            markSynced()
        } catch {
            // Silent failure — will retry on next foreground or pull-to-refresh.
        }
    }
}
