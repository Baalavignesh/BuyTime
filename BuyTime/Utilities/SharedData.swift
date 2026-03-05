//
//  SharedData.swift
//  BuyTime
//
//  Created by Baalavignesh Arunachalam on 1/7/26.
//

import Foundation
import FamilyControls

/// Represents a queued API operation for offline-first sync.
/// Only used by the main app target (not extensions).
struct SyncOperation: Codable {
    enum Kind: String, Codable {
        case start, end, abandon
    }

    let kind: Kind
    let sessionId: String
    let mode: String
    let plannedMinutes: Int
    let actualMinutes: Int
    let createdAt: Date
}

class SharedData {

    static let appGroupIdentifier = "group.com.baalavignesh.buytime"
    static let defaultsGroup: UserDefaults? = UserDefaults(suiteName: appGroupIdentifier)

    enum Keys: String {
        case blockedApps = "blockedAppsSelection"
        case earnedTimeEventActive = "earnedTimeEventActive"
        case earnedTimeMinutes = "earnedTimeMinutes"
        case spendAmount = "spendAmount"
        case userBalanceValues = "userBalanceValues"

        // Earned time session counter (repurposes old currentEventTimeLeft key)
        case remainingEarnedTimeMinutes = "currentEventTimeLeft"

        // Focus session state
        case isFocusActive = "isFocusActive"
        case focusEndTime = "focusEndTime"
        case focusSessionId = "focusSessionId"
        case focusStartTime = "focusStartTime"
        case focusMode = "focusMode"
        case focusPlannedMinutes = "focusPlannedMinutes"

        // Background-to-foreground API handoff
        case pendingSessionEnd = "pendingSessionEnd"
        case pendingActualMinutes = "pendingActualMinutes"

        // Offline sync queue (main app only)
        case pendingSyncOperations = "pendingSyncOperations"
    }

    // MARK: - Blocked App Selection

    static var blockedAppsSelection: FamilyActivitySelection {
        get {
            guard let data = defaultsGroup?.data(forKey: Keys.blockedApps.rawValue) else {
                return FamilyActivitySelection()
            }
            do {
                return try JSONDecoder().decode(FamilyActivitySelection.self, from: data)
            } catch {
                print("Failed to decode FamilyActivitySelection: \(error)")
                return FamilyActivitySelection()
            }
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                defaultsGroup?.set(data, forKey: Keys.blockedApps.rawValue)
            } catch {
                print("Failed to encode FamilyActivitySelection: \(error)")
            }
        }
    }

    // MARK: - Balance

    static var userBalanceValues: [String: Int] {
        get {
            defaultsGroup?.dictionary(forKey: Keys.userBalanceValues.rawValue) as? [String: Int] ?? [:]
        }
        set {
            defaultsGroup?.set(newValue, forKey: Keys.userBalanceValues.rawValue)
        }
    }

    static var earnedTimeMinutes: Int {
        get {
            defaultsGroup?.synchronize()
            return defaultsGroup?.integer(forKey: Keys.earnedTimeMinutes.rawValue) ?? 0
        }
        set {
            defaultsGroup?.set(max(0, newValue), forKey: Keys.earnedTimeMinutes.rawValue)
            defaultsGroup?.synchronize()
        }
    }

    // MARK: - Earned Time Session

    static var earnedTimeEventActive: Bool {
        get { defaultsGroup?.bool(forKey: Keys.earnedTimeEventActive.rawValue) ?? false }
        set { defaultsGroup?.set(newValue, forKey: Keys.earnedTimeEventActive.rawValue) }
    }

    static var spendAmount: Int {
        get {
            let value = defaultsGroup?.integer(forKey: Keys.spendAmount.rawValue) ?? 0
            return value > 0 ? value : 5
        }
        set {
            defaultsGroup?.set(max(1, newValue), forKey: Keys.spendAmount.rawValue)
        }
    }

    /// Live counter decremented each time a one-minute DeviceActivity event fires.
    /// When earnedTimeEventActive = true  → ticking counter (actual in-app usage)
    /// When earnedTimeEventActive = false → paused amount waiting to resume after focus
    /// Value = 0 → nothing active or paused
    static var remainingEarnedTimeMinutes: Int {
        get { defaultsGroup?.integer(forKey: Keys.remainingEarnedTimeMinutes.rawValue) ?? 0 }
        set { defaultsGroup?.set(max(0, newValue), forKey: Keys.remainingEarnedTimeMinutes.rawValue) }
    }

    // MARK: - Focus Session State

    static var isFocusActive: Bool {
        get { defaultsGroup?.bool(forKey: Keys.isFocusActive.rawValue) ?? false }
        set { defaultsGroup?.set(newValue, forKey: Keys.isFocusActive.rawValue) }
    }

    /// Timestamp (seconds since 1970) when the current focus session ends. 0 = not set.
    static var focusEndTime: Double {
        get { defaultsGroup?.double(forKey: Keys.focusEndTime.rawValue) ?? 0 }
        set { defaultsGroup?.set(newValue, forKey: Keys.focusEndTime.rawValue) }
    }

    /// Client-generated UUID for the focus session. "" = not set.
    static var focusSessionId: String {
        get { defaultsGroup?.string(forKey: Keys.focusSessionId.rawValue) ?? "" }
        set { defaultsGroup?.set(newValue, forKey: Keys.focusSessionId.rawValue) }
    }

    /// Timestamp when focus started. Used to compute actualDurationMinutes for the API.
    static var focusStartTime: Double {
        get { defaultsGroup?.double(forKey: Keys.focusStartTime.rawValue) ?? 0 }
        set { defaultsGroup?.set(newValue, forKey: Keys.focusStartTime.rawValue) }
    }

    /// Focus mode string (fun/easy/medium/hard). Used for UI display on recovery.
    static var focusMode: String {
        get { defaultsGroup?.string(forKey: Keys.focusMode.rawValue) ?? "" }
        set { defaultsGroup?.set(newValue, forKey: Keys.focusMode.rawValue) }
    }

    /// Planned duration in minutes. Used for estimated reward display and as fallback for actualMinutes.
    static var focusPlannedMinutes: Int {
        get { defaultsGroup?.integer(forKey: Keys.focusPlannedMinutes.rawValue) ?? 0 }
        set { defaultsGroup?.set(max(0, newValue), forKey: Keys.focusPlannedMinutes.rawValue) }
    }

    // MARK: - Background-to-Foreground Handoff

    /// Set by DeviceActivityMonitorExtension when focus ends in background.
    /// Main app reads this on next foreground and calls POST /api/sessions/end.
    static var pendingSessionEnd: Bool {
        get { defaultsGroup?.bool(forKey: Keys.pendingSessionEnd.rawValue) ?? false }
        set { defaultsGroup?.set(newValue, forKey: Keys.pendingSessionEnd.rawValue) }
    }

    /// Actual focus minutes set by extension alongside pendingSessionEnd.
    /// Sent to POST /api/sessions/end so server computes rewardMinutes.
    static var pendingActualMinutes: Int {
        get { defaultsGroup?.integer(forKey: Keys.pendingActualMinutes.rawValue) ?? 0 }
        set { defaultsGroup?.set(max(0, newValue), forKey: Keys.pendingActualMinutes.rawValue) }
    }

    // MARK: - Convenience

    /// True if a focus session is currently active.
    /// Checks both the flag and the end date — the date is always authoritative.
    static var isFocusCurrentlyActive: Bool {
        guard isFocusActive, focusEndTime > 0 else { return false }
        return Date().timeIntervalSince1970 < focusEndTime
    }

    // MARK: - State Helpers

    /// Clears all focus session metadata. Call after completing, abandoning, or recovering a session.
    static func clearFocusSessionState() {
        focusSessionId = ""
        focusStartTime = 0
        focusMode = ""
        focusPlannedMinutes = 0
    }

    // MARK: - Offline Sync Queue

    /// Appends a sync operation to the offline queue.
    static func enqueueSyncOperation(_ op: SyncOperation) {
        var queue = pendingSyncOperations
        queue.append(op)
        pendingSyncOperations = queue
    }

    /// Pending API operations queued when offline. Main app only.
    static var pendingSyncOperations: [SyncOperation] {
        get {
            guard let data = defaultsGroup?.data(forKey: Keys.pendingSyncOperations.rawValue) else {
                return []
            }
            return (try? JSONDecoder().decode([SyncOperation].self, from: data)) ?? []
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            defaultsGroup?.set(data, forKey: Keys.pendingSyncOperations.rawValue)
        }
    }
}
