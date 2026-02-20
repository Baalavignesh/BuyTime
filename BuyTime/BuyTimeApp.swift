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
    
    var body: some Scene {
        WindowGroup(makeContent: {
            ContentView()
                .environment(\.clerk, clerk)
                .task {
                    clerk.configure(publishableKey: "pk_test_c2hhcmluZy1pbXBhbGEtNTUuY2xlcmsuYWNjb3VudHMuZGV2JA")
                    try? await clerk.load()
                    
                    // Print JWT token if session exists on app launch
                    await printJWTToken(context: "App launch - session restored")
                    
                    let savedSelection = SharedData.blockedAppsSelection
                    if !savedSelection.applicationTokens.isEmpty ||
                        !savedSelection.categoryTokens.isEmpty {
                        let blockUtils = AppBlockUtils()
                        blockUtils.applyRestrictions(selection: savedSelection)
                    }
                }
                .onChange(of: clerk.session) { oldSession, newSession in
                    Task {
                        if newSession != nil {
                            await printJWTToken(context: "Session changed/refreshed")
                        }
                    }
                }
        })
    }
    
    func printJWTToken(context: String) async {
        do {
            if let session = Clerk.shared.session {
                let token = try await session.getToken()
                print("🔐 JWT Token (\(context)):")
                print(token?.jwt ?? "No token available")
            }
        } catch {
            print("Failed to get JWT token: \(error)")
        }
    }
}
