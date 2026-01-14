//
//  ShieldActionExtension.swift
//  BuyTimeShieldActionExtension
//
//  Created by Baalavignesh Arunachalam on 1/9/26.
//

import ManagedSettings
import Foundation
import FamilyControls
import DeviceActivity

// Override the functions below to customize the shield actions used in various situations.
// The system provides a default response for any functions that your subclass doesn't override.
// Make sure that your class name matches the NSExtensionPrincipalClass in your Info.plist.
class ShieldActionExtension: ShieldActionDelegate {

    let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("buytimeAppRestriction"))
    
    // Action for Application
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        print("ShieldAction triggered: \(action)")
        switch action {
        case .primaryButtonPressed:
            handleTemporaryAccess(completionHandler: completionHandler)
        case .secondaryButtonPressed:
            completionHandler(.close)
        @unknown default:
            fatalError()
        }
    }
    

    // Action for WebDomain
    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(.close)
    }
    
    // Action for Category
    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(.close)
    }

    private func handleTemporaryAccess(completionHandler: @escaping (ShieldActionResponse) -> Void) {
        // Handle the temporary access as needed.
        // Remove ALL shields - user can access any previously blocked app
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil

        let center = DeviceActivityCenter()
        let now = Calendar.current.dateComponents([.hour, .minute, .second], from: Date())
        let endTime = Calendar.current.dateComponents([.hour, .minute, .second], from: Date().addingTimeInterval(1 * 60))
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: now.hour, minute: now.minute, second: now.second),
            intervalEnd: DateComponents(hour: endTime.hour, minute: endTime.minute, second: endTime.second),
            repeats: false
        )
        do {
            try center.startMonitoring(DeviceActivityName("com.baalavignesh.buytime.temporaryUnlock"), during: schedule)
        } catch {
            print("Failed to schedule re-lock: \(error)")
        }
        completionHandler(.close)
}
}
