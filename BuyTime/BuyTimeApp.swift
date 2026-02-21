//
//  BuyTimeApp.swift
//  BuyTime
//
//  Created by Baalavignesh Arunachalam on 12/17/25.
//

import SwiftUI
import Clerk
import FamilyControls

@main
struct ClerkQuickstartApp: App {
    @State private var clerk = Clerk.shared
    @State private var isClerkLoaded = false

    var body: some Scene {
        WindowGroup(makeContent: {
            ContentView(isClerkLoaded: isClerkLoaded)
                .environment(\.clerk, clerk)
                .task {
                    clerk.configure(publishableKey: Secrets.clerkPublishableKey)
                    try? await clerk.load()
                    isClerkLoaded = true

                    // DEV ONLY: Print long-lived JWT for API testing
                    await printJWTToken()

                    let savedSelection = SharedData.blockedAppsSelection
                    if !savedSelection.applicationTokens.isEmpty ||
                        !savedSelection.categoryTokens.isEmpty {
                        let blockUtils = AppBlockUtils()
                        blockUtils.applyRestrictions(selection: savedSelection)
                    }
                }
        })
    }
    
    // DEV ONLY: Remove before production
    func printJWTToken() async {
        do {
            if let session = Clerk.shared.session {
                let token = try await session.getToken(.init(template: "dev-testing"))
                print("🔐 JWT Token (dev-testing, 1-day expiry):")
                print(token?.jwt ?? "No token available")
            }
        } catch {
            print("Failed to get JWT token: \(error)")
        }
    }
}
