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

    private func formatTime(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
        return "\(minutes) minutes"
    }

    private func buildConfig(appName: String?) -> ShieldConfiguration {
        if SharedData.isFocusCurrentlyActive {
            return buildFocusConfig(appName: appName)
        } else {
            return buildNormalConfig(appName: appName)
        }
    }

    private func buildFocusConfig(appName: String?) -> ShieldConfiguration {
        let displayName = appName ?? "This app"
        let remaining = SharedData.focusEndTime - Date().timeIntervalSince1970
        let remainingMin = max(0, Int(remaining / 60))
        let remainingDisplay = remainingMin > 0 ? "\(remainingMin) min left" : "Almost done"

        return ShieldConfiguration(
            backgroundBlurStyle: nil,
            backgroundColor: UIColor.systemIndigo,
            icon: UIImage(named: "dark_logo"),
            title: ShieldConfiguration.Label(text: "Focus Mode Active", color: .white),
            subtitle: ShieldConfiguration.Label(
                text: "\(displayName) is blocked\n\(remainingDisplay)",
                color: UIColor(white: 1, alpha: 0.7)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Keep Focusing", color: .white),
            primaryButtonBackgroundColor: UIColor(white: 1, alpha: 0.15),
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Close", color: .white)
        )
    }

    private func buildNormalConfig(appName: String?) -> ShieldConfiguration {
        let walletTime = SharedData.earnedTimeMinutes
        let spendAmount = SharedData.spendAmount
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
        buildConfig(appName: application.localizedDisplayName)
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        buildConfig(appName: application.localizedDisplayName)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        buildConfig(appName: webDomain.domain)
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        buildConfig(appName: webDomain.domain)
    }
}
