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

    private var customConfig = ShieldConfiguration(
        backgroundColor: UIColor.black,
        icon: UIImage(systemName: "hourglass"),
        title: ShieldConfiguration.Label(text: "App Blocked", color: .white),
        subtitle: ShieldConfiguration.Label(text: "This app is currently restricted by BuyTime", color: .gray),
        primaryButtonLabel: ShieldConfiguration.Label(text: "Spend 5 minutes", color: UIColor(white: 1.0, alpha: 1.0)),
        primaryButtonBackgroundColor: UIColor.systemBlue,
        secondaryButtonLabel: ShieldConfiguration.Label(text: "Visit Later", color: .white)
    )
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        // Customize the shield as needed for applications.
        customConfig
    }
    
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        // Customize the shield as needed for applications shielded because of their category.
        customConfig
    }
    
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        // Customize the shield as needed for web domains.
        customConfig
    }
    
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        // Customize the shield as needed for web domains shielded because of their category.
        customConfig
    }
}
