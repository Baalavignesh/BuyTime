//
//  ParentView.swift
//  BuyTime
//
//  Created by Baalavignesh Arunachalam on 12/21/25.
//

import SwiftUI
import FamilyControls

enum AppTab: Hashable {
    case home, time, settings
}

struct ParentView: View {
    @StateObject var authManager = AuthorizationManager()
    @State private var selection = FamilyActivitySelection()
    @AppStorage("hasCompletedAppSelection") var hasCompletedAppSelection = false
    @State private var selectedTab: AppTab = .home
    @State private var showContent = false
    @State private var showMainApp = false

    private var hasSelection: Bool {
        !selection.applicationTokens.isEmpty ||
        !selection.categoryTokens.isEmpty ||
        !selection.webDomainTokens.isEmpty
    }

    var body: some View {
        ZStack {
            // Content layer — always rendered underneath, fades in
            Group {
                if authManager.authorizationStatus == .approved {
                    if !hasCompletedAppSelection {
                        VStack {
                            Text("Select Distracting Apps to Block")
                                .font(.headline)
                                .padding(.top)

                            FamilyActivityPicker(selection: $selection)

                            Button("Continue") {
                                saveSelection()
                                hasCompletedAppSelection = true
                                showMainApp = false
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(!hasSelection)
                            .padding()
                        }
                    }
                    else {
                        TabView(selection: $selectedTab) {
                            Tab("Home", systemImage: "brain.filled.head.profile", value: .home) {
                                HomeView()
                            }

                            Tab("Time", systemImage: "hourglass", value: .time) {
                                TimeView()
                            }

                            Tab("Settings", systemImage: "gear", value: .settings) {
                                SettingsView()
                            }
                        }
                        .opacity(showMainApp ? 1 : 0)
                        .onAppear {
                            withAnimation(.easeOut(duration: 0.4)) {
                                showMainApp = true
                            }
                        }
                    }
                } else {
                    PermissionView(authManager: authManager)
                }
            }
            .opacity(showContent ? 1 : 0)

            // Launch screen layer — matches the auto-generated LaunchScreen
            // Sits on top, fades out once auth resolves to reveal content
            if !showContent {
                Color(.systemBackground)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.4), value: showContent)
        .onChange(of: authManager.hasResolved) { _, resolved in
            if resolved {
                showContent = true
                if hasCompletedAppSelection {
                    showMainApp = true
                }
            }
        }
    }

    private func saveSelection() {
        SharedData.blockedAppsSelection = selection

        let blockUtils = AppBlockUtils()
        blockUtils.applyRestrictions(selection: selection)

        print("Selection saved: \(selection)")
    }
}

#Preview {
    ParentView()
}
