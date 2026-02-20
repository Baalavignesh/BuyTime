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
                    clerk.configure(publishableKey: "pk_test_c2hhcmluZy1pbXBhbGEtNTUuY2xlcmsuYWNjb3VudHMuZGV2JA")
                    try? await clerk.load()
                    isClerkLoaded = true

                    let savedSelection = SharedData.blockedAppsSelection
                    if !savedSelection.applicationTokens.isEmpty ||
                        !savedSelection.categoryTokens.isEmpty {
                        let blockUtils = AppBlockUtils()
                        blockUtils.applyRestrictions(selection: savedSelection)
                    }
                }
        })
    }
    
}
