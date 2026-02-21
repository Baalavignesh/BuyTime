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

    var hasSelection: Bool {
            !selection.applicationTokens.isEmpty ||
            !selection.categoryTokens.isEmpty ||
            !selection.webDomainTokens.isEmpty
        }
    
    var body: some View {
        
        if authManager.isLoading {
            VStack {
                Image(systemName: "hourglass")
                    .font(.system(size: 60))
                    .foregroundStyle(.tint)
                Text("BuyTime")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
        }
        else if authManager.authorizationStatus == .notDetermined {
            VStack {
                
                Text("BuyTime").font(.largeTitle)
                Image(systemName: "hourglass.badge.lock")
                    .font(.title)
                    .imageScale(.large).padding(.vertical, 10)
                Text("ScreenTime protects your privacy. BuyTime cannot see which apps are on your device or which app you have selected")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
                Button("Allow ScreenTime Access") {
                    Task {
                        await authManager.requestAuthorization()
                    }
                }.buttonStyle(PrimaryButtonStyle())
                
            }
            
            
        }
        else if authManager.authorizationStatus == .approved {
            if !hasCompletedAppSelection {
                VStack {
                                    Text("Select Distracting Apps to Block")
                                        .font(.headline)
                                        .padding(.top)
                                    
                                    FamilyActivityPicker(selection: $selection)
                                    
                                    Button("Continue") {
                                        // Save selection and proceed
                                        saveSelection()
                                        hasCompletedAppSelection = true
                                    }
                                    .buttonStyle(PrimaryButtonStyle())
                                    .disabled(!hasSelection) // Disable if no apps selected
                                    .padding()
                                }
            }
            else {
                TabView {
                    Tab("Home", systemImage: "brain.filled.head.profile") {
                        HomeView()
                    }

                    Tab("Time", systemImage: "hourglass") {
                        TimeView()
                    }


                    Tab("Settings", systemImage: "gear") {
                        SettingsView()
                    }
                }
            }
        }
        else {
            VStack {
                Text("BuyTime").font(.largeTitle)
                Image(systemName: "hourglass.badge.lock")
                    .font(.title)
                    .imageScale(.large).padding(.vertical, 10)
                Text("ScreenTime Authorization Denied. Please enable in Settings.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
                Button("Allow ScreenTime Access") {
                    Task {
                        await authManager.requestAuthorization()
                    }
                }.buttonStyle(PrimaryButtonStyle())
                
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
