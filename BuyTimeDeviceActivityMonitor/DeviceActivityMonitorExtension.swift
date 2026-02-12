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
        print("interval started in Device Activity")
        super.intervalDidStart(for: activity)
    }
    
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
    }
    
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        
        print("Event threshold reached: \(event.rawValue)")
        
        if activity == DeviceActivityName("com.baalavignesh.buytime.earnedTime") {
            print("Earned time session complete")
            print("Remaining balance: \(SharedData.earnedTimeMinutes) minutes")
        }
        
        SharedData.earnedTimeEventActive = false
        
        reapplyRestrictions()
        
        let center = DeviceActivityCenter()
        center.stopMonitoring([activity])
        
        // Handle the event reaching its threshold.
    }
    
    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        super.intervalWillStartWarning(for: activity)
        
        // Handle the warning before the interval starts.
    }
    
    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        
        // Handle the warning before the interval ends.
    }
    
    override func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventWillReachThresholdWarning(event, activity: activity)
        
        // Handle the warning before the event reaches its threshold.
    }
    
    private func reapplyRestrictions() {
        let selection = SharedData.blockedAppsSelection
        
        store.clearAllSettings()

        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        
        print("Shields re-applied after user spends their earned time")
    }

}
