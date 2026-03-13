//
//  ParentView.swift
//  BuyTime
//
//  Created by Baalavignesh Arunachalam on 12/21/25.
//

import SwiftUI
import FamilyControls
import Combine

struct ParentView: View {
    @StateObject var authManager = AuthorizationManager()
    @State var selection = FamilyActivitySelection()
    @AppStorage("hasCompletedAppSelection") var hasCompletedAppSelection = false
    @State private var selectedTab: Int = 0
    @State private var showContent = false
    @State private var showMainApp = false

    var hasSelection: Bool {
            !selection.applicationTokens.isEmpty ||
            !selection.categoryTokens.isEmpty ||
            !selection.webDomainTokens.isEmpty
        }

    var body: some View {
        ZStack {
            // Content layer — always rendered underneath, fades in
            Group {
                if authManager.authorizationStatus == .notDetermined {
                    PermissionView(authManager: authManager)
                }
                else if authManager.authorizationStatus == .approved {
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
                            Tab("Home", systemImage: "brain.filled.head.profile", value: 0) {
                                HomeView()
                            }

                            Tab("Time", systemImage: "hourglass", value: 1) {
                                TimeView()
                            }

                            Tab("Settings", systemImage: "gear", value: 2) {
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
                }
                else {
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

@ViewBuilder
private func PermissionView(authManager: AuthorizationManager) -> some View {
    ZStack {
        VStack(spacing: 0) {
            Spacer()

            Button {
                Task {
                    await authManager.requestAuthorization()
                }
            } label: {
                Image("permission")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 32))
                    .padding(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 32)
                            .stroke(Color.blue, lineWidth: 1)
                    )
                    .overlay(alignment: .bottomLeading) {
                        Image(systemName: "arrow.up")
                            .font(.title)
                            .imageScale(.large)
                            .offset(x: 72, y: 52)
                    }
            }
            .buttonStyle(PressableStyle())

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)

        VStack(spacing: 12) {
            Text("Private by Design")
                .font(.largeTitle).multilineTextAlignment(.center)

            Text("We can't see your apps or how you use them. ByTime will need your permission to continue.")
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 24)
        .allowsHitTesting(false)
        
        VStack(spacing: 12) {

            Text("Your sensitive data is handled by Apple and never leaves your device.")
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 32)
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .allowsHitTesting(false)
    }
}

private struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    ParentView()
}
