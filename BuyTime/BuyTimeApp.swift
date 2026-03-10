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

                    // Recover any focus state that resolved while the app was closed
                    await recoverFocusState()

                    let savedSelection = SharedData.blockedAppsSelection
                    if !savedSelection.applicationTokens.isEmpty ||
                        !savedSelection.categoryTokens.isEmpty {
                        let blockUtils = AppBlockUtils()
                        blockUtils.applyRestrictions(selection: savedSelection)
                    }
                }
        })
    }

    // MARK: - Focus State Recovery

    /// Called on every launch after Clerk loads.
    /// Handles two scenarios:
    /// 1. Focus ended in background — DeviceActivityMonitor wrote pendingSessionEnd.
    ///    Reward is calculated locally and credited immediately; API call is non-blocking.
    /// 2. Stale isFocusActive flag — focus expired while app was closed, extension didn't run.
    private func recoverFocusState() async {
        // Scenario 1: Focus ended in background, extension set the pending flags
        if SharedData.pendingSessionEnd {
            SharedData.pendingSessionEnd = false

            let sessionId = SharedData.focusSessionId
            let actualMinutes = SharedData.pendingActualMinutes
            let modeStr = SharedData.focusMode
            let plannedMinutes = SharedData.focusPlannedMinutes

            // Credit reward locally using Mode.multiplier — no network needed
            let mode = Mode(rawValue: modeStr) ?? .easy
            let reward = Int(Double(actualMinutes) * mode.multiplier)
            if reward > 0 {
                SharedData.earnedTimeMinutes = max(0, SharedData.earnedTimeMinutes + reward)
            }

            SharedData.pendingActualMinutes = 0
            SharedData.clearFocusSessionState()

            // Fire API in background, queue on failure
            if !sessionId.isEmpty && actualMinutes > 0 {
                Task {
                    do {
                        _ = try await BuyTimeAPI.shared.endSession(
                            sessionId: sessionId,
                            actualDurationMinutes: actualMinutes
                        )
                    } catch {
                        SharedData.enqueueSyncOperation(SyncOperation(
                            kind: .end,
                            sessionId: sessionId,
                            mode: modeStr,
                            plannedMinutes: plannedMinutes,
                            actualMinutes: actualMinutes,
                            penaltyMinutes: 0,
                            createdAt: Date()
                        ))
                    }
                }
            }
        }

        // Scenario 2: Stale flag — focus end time already passed but flag wasn't cleared
        if SharedData.isFocusActive && !SharedData.isFocusCurrentlyActive {
            SharedData.isFocusActive = false
            SharedData.focusEndTime = 0
        }
    }

    // MARK: - DEV ONLY: Remove before production

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
