//
//  ShieldConfigurationExtension.swift
//  BuyTimeShield
//
//  Created by Baalavignesh Arunachalam on 1/5/26.
//

import ManagedSettings
import ManagedSettingsUI
import UIKit

// Override the functions below to customize the shields used in various situations.
// The system provides a default appearance for any methods that your subclass doesn't override.
// Make sure that your class name matches the NSExtensionPrincipalClass in your Info.plist.
class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    private let sharedDefaults = UserDefaults(suiteName: "group.com.baalavignesh.buytime")
    
    private func getWalletTime() -> Int {
        return sharedDefaults?.integer(forKey: "earnedTimeMinutes") ?? 0
    }
    
    private func getSpendAmount() -> Int {
        let value = sharedDefaults?.integer(forKey: "spendAmount") ?? 0
        return value > 0 ? value : 5
    }
    
    private func formatTime(_ minutes: Int) -> String {
            if minutes >= 60 {
                let hours = minutes / 60
                let mins = minutes % 60
                return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
            }
            return "\(minutes) minutes"
        }
    
    private func buildConfig(appName: String?) -> ShieldConfiguration {
        
        let walletTime = getWalletTime()
        let spendAmount = getSpendAmount()
        
        let displayName = appName ?? "This app"
        
        let titleText = "\(displayName) is Blocked by BuyTime"
                
        let subtitleText = """
        
        Spend your time carefully
        
        Time in wallet
        \(formatTime(walletTime))
        """
                
        let buttonText = walletTime >= spendAmount
            ? "Spend \(spendAmount) minutes"
            : "Not enough time"
        
        return ShieldConfiguration(
            backgroundBlurStyle: nil,
            backgroundColor: UIColor.black,
            icon: UIImage(named: "dark_logo"),
            title: ShieldConfiguration.Label(text: titleText, color: .white),
            subtitle: ShieldConfiguration.Label(text: subtitleText, color: .lightGray),
            primaryButtonLabel: ShieldConfiguration.Label(text: buttonText, color: .white),
            primaryButtonBackgroundColor: walletTime >= spendAmount ? .blue : .darkGray,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Close", color: .white)
        )
    }
    
    
    
    
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        // Customize the shield as needed for applications.
        buildConfig(appName: application.localizedDisplayName)
    }
    
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        // Customize the shield as needed for applications shielded because of their category.
        buildConfig(appName: application.localizedDisplayName)
    }
    
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        // Customize the shield as needed for web domains.
        buildConfig(appName: webDomain.domain)
    }
    
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        // Customize the shield as needed for web domains shielded because of their category.
        buildConfig(appName: webDomain.domain)
    }
}
