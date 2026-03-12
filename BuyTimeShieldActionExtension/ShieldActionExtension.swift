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
    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void) {

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
        // Focus always takes priority — spending is blocked during focus sessions
        if SharedData.isFocusCurrentlyActive {
            print("Spend blocked: focus session is active")
            completionHandler(.close)
            return
        }

        let spendAmount = SharedData.spendAmount
        let currentBalance = SharedData.earnedTimeMinutes

        guard currentBalance >= spendAmount else {
            print("✗ Insufficient balance: need \(spendAmount), have \(currentBalance)")
            completionHandler(.close)
            return
        }

        SharedData.earnedTimeMinutes = currentBalance - spendAmount
        SharedData.shieldSpendDelta -= spendAmount

        let blockUtils = AppBlockUtils()
        blockUtils.startEarnedTimeMonitoring(minutes: spendAmount)
        completionHandler(.none)
    }
}
