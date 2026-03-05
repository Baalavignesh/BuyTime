//
//  ManagedSettings.swift
//  BuyTime
//
//  Created by Baalavignesh Arunachalam on 1/9/26.
//

import Foundation
import ManagedSettings
import FamilyControls
import DeviceActivity


class AppBlockUtils {

    static let earnedTimeActivityName = DeviceActivityName("com.baalavignesh.buytime.earnedTime")
    static let focusSessionActivityName = DeviceActivityName("com.baalavignesh.buytime.focusSession")

    let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("buytimeAppRestriction"))
    let center = DeviceActivityCenter()

    // MARK: - Restrictions

    func applyRestrictions(selection: FamilyActivitySelection) {
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        print("Restrictions applied to ManagedSettingsStore.")
    }

    func removeRestriction() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        print("Restriction Removed")
    }

    // MARK: - Earned Time Monitoring (multi-event approach)

    /// Starts earned time monitoring by registering N one-minute events.
    /// Each event fires as cumulative in-app usage crosses 1, 2, ... N minutes.
    /// Shields are only re-applied when the counter reaches 0 (final event).
    func startEarnedTimeMonitoring(minutes: Int) {
        guard minutes > 0 else {
            print("Invalid time amount: \(minutes)")
            return
        }

        let selection = SharedData.blockedAppsSelection
        guard !selection.applicationTokens.isEmpty ||
                !selection.categoryTokens.isEmpty ||
                !selection.webDomainTokens.isEmpty else {
            print("No apps selected to monitor")
            return
        }

        // Unlock apps first
        removeRestriction()

        // Set the live counter (decremented by DeviceActivityMonitor on each event)
        SharedData.remainingEarnedTimeMinutes = minutes

        // Register one event per minute (thresholds 1, 2, ..., N minutes)
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for minute in 1...minutes {
            let name = DeviceActivityEvent.Name("buytime.earnedTime.m\(minute)")
            events[name] = DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                webDomains: selection.webDomainTokens,
                threshold: DateComponents(minute: minute)
            )
        }

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true,
            warningTime: nil
        )

        do {
            try center.startMonitoring(Self.earnedTimeActivityName, during: schedule, events: events)
            SharedData.earnedTimeEventActive = true
            print("Started earned time monitoring: \(minutes) minutes (\(minutes) events)")
        } catch {
            print("Failed to start earned time monitoring: \(error)")
        }
    }

    // MARK: - Focus Session Monitoring

    /// Starts focus session monitoring. Does NOT make API calls — caller handles those.
    /// Generates a UUID locally and writes it to SharedData.focusSessionId.
    /// Pauses any active earned time session (leaves remainingEarnedTimeMinutes for resume).
    func startFocusMonitoring(minutes: Int, mode: String) {
        let selection = SharedData.blockedAppsSelection
        guard !selection.applicationTokens.isEmpty ||
                !selection.categoryTokens.isEmpty ||
                !selection.webDomainTokens.isEmpty else {
            print("No apps selected — cannot start focus monitoring")
            return
        }

        // Pause earned time if currently active
        if SharedData.earnedTimeEventActive {
            center.stopMonitoring([Self.earnedTimeActivityName])
            SharedData.earnedTimeEventActive = false
            // remainingEarnedTimeMinutes is intentionally NOT cleared — used for resume after focus
            print("Earned time paused for focus session. Remaining: \(SharedData.remainingEarnedTimeMinutes) min")
        }

        // Ensure shields are applied (apps may have been unlocked during earned time)
        applyRestrictions(selection: selection)

        // Write focus state — generate session ID locally for offline-first
        let sessionId = UUID().uuidString
        let now = Date().timeIntervalSince1970
        SharedData.isFocusActive = true
        SharedData.focusEndTime = now + Double(minutes * 60)
        SharedData.focusSessionId = sessionId
        SharedData.focusStartTime = now
        SharedData.focusMode = mode
        SharedData.focusPlannedMinutes = minutes

        // Start a wall-clock schedule for the focus duration
        let startComps = Calendar.current.dateComponents([.hour, .minute, .second], from: Date())
        let endDate = Calendar.current.date(byAdding: .minute, value: minutes, to: Date())!
        let endComps = Calendar.current.dateComponents([.hour, .minute, .second], from: endDate)

        let schedule = DeviceActivitySchedule(
            intervalStart: startComps,
            intervalEnd: endComps,
            repeats: false,
            warningTime: nil
        )

        do {
            try center.startMonitoring(Self.focusSessionActivityName, during: schedule, events: [:])
            print("Focus session monitoring started: \(minutes) min, mode: \(mode)")
        } catch {
            print("Failed to start focus monitoring: \(error)")
        }
    }

    /// Stops focus session monitoring and clears the active focus flags.
    /// Does NOT make API calls — caller handles abandon/end API calls.
    func stopFocusMonitoring() {
        center.stopMonitoring([Self.focusSessionActivityName])
        SharedData.isFocusActive = false
        SharedData.focusEndTime = 0
        print("Focus monitoring stopped")
    }
}
