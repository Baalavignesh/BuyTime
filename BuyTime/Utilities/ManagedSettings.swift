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
    static let earnedTimeEventName = DeviceActivityEvent.Name("com.baalavignesh.buytime.earnedTimeEvent")

    let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("buytimeAppRestriction"))
    let center = DeviceActivityCenter()
    
    func applyRestrictions(selection: FamilyActivitySelection) {
        let applicationTokens = selection.applicationTokens
        let categoryTokens = selection.categoryTokens
        let webDomainTokens = selection.webDomainTokens
        
        store.shield.applications = applicationTokens.isEmpty ? nil : applicationTokens
        store.shield.applicationCategories = categoryTokens.isEmpty ? nil : .specific(categoryTokens)
        store.shield.webDomains = webDomainTokens.isEmpty ? nil : webDomainTokens
        
        print("Restrictions applied to ManagedSettingsStore.")
    }
    
    func removeRestriction() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        
        print("Restriction Removed")
    }
    
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
                
        // Step 1: Remove shields to allow app usage
        removeRestriction()
        
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true,
            warningTime: nil
        )
        
        let event = DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens,
            threshold: DateComponents(minute: minutes),
        )
        
        do {
            try center.startMonitoring(
                Self.earnedTimeActivityName,
                during: schedule,
                events: [Self.earnedTimeEventName: event]
            )
            SharedData.earnedTimeEventActive = true
            print("Started earned time monitoring: \(minutes) minutes")
            print("Tracking \(selection.applicationTokens.count) apps")
        } catch {
            print("Failed to start earned time monitoring: \(error)")
        }
        
    }

}
