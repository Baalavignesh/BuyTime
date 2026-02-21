//
//  BalanceViewModel.swift
//  BuyTime
//
//  Manages the user's available minutes balance.
//
//  Source of truth: SharedData.earnedTimeMinutes (AppGroup UserDefaults)
//  API is a remote mirror synced via delta — safe for multi-device use.
//
//  Sync model:
//    pendingDelta = SharedData.earnedTimeMinutes - lastAPIValue
//    On sync: GET api balance → PATCH (apiBalance + pendingDelta) if delta != 0
//             else accept server value (picks up other-device changes)
//

import Foundation
import SwiftUI
import Combine

@MainActor
class BalanceViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var availableMinutes: Int = 0
    @Published var isRefreshing: Bool = false

    // MARK: - Persistence

    private enum CacheKey {
        static let lastAPIValue = "balance_lastAPIValue"
    }

    /// Last `availableMinutes` value confirmed from the API.
    /// -1 means "never synced" — first sync will GET only, no PATCH.
    private var lastAPIValue: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: CacheKey.lastAPIValue)
            // integer(forKey:) returns 0 when key is absent; use -1 as sentinel instead
            guard UserDefaults.standard.object(forKey: CacheKey.lastAPIValue) != nil else {
                return -1
            }
            return stored
        }
        set {
            UserDefaults.standard.set(newValue, forKey: CacheKey.lastAPIValue)
        }
    }

    /// Changes made locally that haven't been confirmed by the API yet.
    /// Computed — no need to persist separately.
    private var pendingDelta: Int {
        guard lastAPIValue != -1 else { return 0 }
        return SharedData.earnedTimeMinutes - lastAPIValue
    }

    // MARK: - Init

    init() {
        availableMinutes = SharedData.earnedTimeMinutes
    }

    // MARK: - Lifecycle Hooks

    /// Call from `.onAppear`. Only fetches on first-ever launch (no API value seeded yet).
    func onAppear() {
        guard lastAPIValue == -1 else { return }
        Task { await performSync(showSpinner: false) }
    }

    /// Call when `scenePhase` changes to `.active`.
    /// Picks up any balance changes made by the shield extension, then syncs if needed.
    func onForeground() {
        // Re-read SharedData in case the shield extension changed it while we were backgrounded
        availableMinutes = SharedData.earnedTimeMinutes

        // If never synced, skip — wait for onAppear to do the initial GET
        guard lastAPIValue != -1 else { return }

        guard pendingDelta != 0 else { return }
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

    // MARK: - Debug (remove before production)

    func debugSetMinutes(_ amount: Int) {
        SharedData.earnedTimeMinutes = max(0, amount)
        availableMinutes = SharedData.earnedTimeMinutes
        // Reset lastAPIValue so the next sync re-seeds from the API
        lastAPIValue = -1
    }

    // MARK: - Core Sync

    /// Performs a GET /api/balance, then conditionally PATCH if pendingDelta != 0.
    /// All failures are swallowed silently — pendingDelta persists for the next retry.
    private func performSync(showSpinner: Bool) async {
        if showSpinner { isRefreshing = true }
        defer { if showSpinner { isRefreshing = false } }

        do {
            let apiBalance = try await BuyTimeAPI.shared.getBalance()

            let delta = pendingDelta

            if delta != 0 {
                // Local changes exist — apply them on top of the current server value.
                // This preserves deductions/additions from other devices (e.g. laptop).
                let newAbsolute = max(0, apiBalance.availableMinutes + delta)
                let confirmed = try await BuyTimeAPI.shared.updateBalance(availableMinutes: newAbsolute)
                lastAPIValue = confirmed.availableMinutes
                SharedData.earnedTimeMinutes = confirmed.availableMinutes
            } else {
                // No local changes — accept server value (picks up other-device changes).
                lastAPIValue = apiBalance.availableMinutes
                SharedData.earnedTimeMinutes = apiBalance.availableMinutes
            }

            availableMinutes = SharedData.earnedTimeMinutes
        } catch {
            // Silent failure.
            // pendingDelta remains non-zero → will retry on next foreground or pull-to-refresh.
        }
    }
}
