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

    static let blockerActivityName = DeviceActivityName("com.baalavignesh.buytime.blockerActivity")

    let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("buytimeAppRestriction"))
    let center = DeviceActivityCenter()
    
    
    func startMonitoringSchedule() {
        let schedule = DeviceActivitySchedule(intervalStart: DateComponents(hour: 0, minute: 0), intervalEnd: DateComponents(hour: 0, minute: 0), repeats: true, warningTime: nil)
        
        do {
            try center.startMonitoring(Self.blockerActivityName, during: schedule)
            print("Monitoring Started")
        } catch {
            print("Error starting Device Activity monitoring")
        }
    }
    
    func stopMonitoring() {
        center.stopMonitoring([
            Self.blockerActivityName
        ])
        print("Monitoring stopped")
    }
    
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
}
