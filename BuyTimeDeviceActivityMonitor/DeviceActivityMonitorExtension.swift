//
//  DeviceActivityMonitorExtension.swift
//  BuyTimeDeviceActivityMonitor
//
//  Created by Baalavignesh Arunachalam on 1/5/26.
//

import DeviceActivity
import ManagedSettings
import FamilyControls
import Foundation

// Optionally override any of the functions below.
// Make sure that your class name matches the NSExtensionPrincipalClass in your Info.plist.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("buytimeAppRestriction"))

    override func intervalDidStart(for activity: DeviceActivityName) {
        print("interval started in Device Activity: \(activity.rawValue)")
        super.intervalDidStart(for: activity)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        if activity == AppBlockUtils.focusSessionActivityName {
            // Skip if focus was already ended (user abandoned or manual cleanup)
            guard SharedData.isFocusActive else {
                print("Focus intervalDidEnd: session already cleared, skipping")
                return
            }

            // Compute actual focus duration
            let startTime = SharedData.focusStartTime
            let actualMinutes: Int
            if startTime > 0 {
                actualMinutes = max(1, Int((Date().timeIntervalSince1970 - startTime) / 60))
            } else {
                actualMinutes = max(1, SharedData.focusPlannedMinutes)
            }

            // Signal main app to call POST /api/sessions/end (extensions cannot make Clerk-auth'd calls)
            SharedData.pendingSessionEnd = true
            SharedData.pendingActualMinutes = actualMinutes

            // Clear focus flags
            SharedData.isFocusActive = false
            SharedData.focusEndTime = 0

            print("Focus session ended naturally. Actual: \(actualMinutes) min. Pending API call set.")

            // Resume earned time if it was paused when focus started
            let remaining = SharedData.remainingEarnedTimeMinutes
            if remaining > 0 && !SharedData.earnedTimeEventActive {
                AppBlockUtils().startEarnedTimeMonitoring(minutes: remaining)
                print("Resumed paused earned time: \(remaining) min")
            }
            // If remaining = 0, shields stay applied (apps remain blocked)
        }
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)

        print("Event threshold reached: \(event.rawValue) in \(activity.rawValue)")

        if activity == AppBlockUtils.earnedTimeActivityName {
            SharedData.remainingEarnedTimeMinutes -= 1
            let remaining = SharedData.remainingEarnedTimeMinutes
            print("Earned time event fired. Remaining: \(remaining) min")

            if remaining <= 0 {
                // Final event — all earned time consumed, re-lock apps
                SharedData.earnedTimeEventActive = false
                SharedData.remainingEarnedTimeMinutes = 0
                reapplyRestrictions()
                DeviceActivityCenter().stopMonitoring([activity])
                print("Earned time exhausted — shields reapplied")
            }
            // Intermediate events: do nothing to shields — apps remain open
        }
    }

    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        super.intervalWillStartWarning(for: activity)
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
    }

    override func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventWillReachThresholdWarning(event, activity: activity)
    }

    private func reapplyRestrictions() {
        let selection = SharedData.blockedAppsSelection
        store.clearAllSettings()
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        print("Shields re-applied")
    }
}
