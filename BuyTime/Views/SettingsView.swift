//
//  SettingsView.swift
//  BuyTime
//
//  Created by Baalavignesh Arunachalam on 12/21/25.
//

import SwiftUI
import Clerk
import FamilyControls

struct SettingsView: View {
    
    @Environment(\.clerk) private var clerk
    @State var isPresented = false
    @State var selection = SharedData.blockedAppsSelection
    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    NavigationLink(value: "Personal Info") {
                        Label("Personal Info", systemImage: "person.circle")
                    }
                    

                    Button {
                        Task {
                            await handleLogout()
                        }
                    } label: {
                        HStack {
                            Label("Log out", systemImage: "arrow.left.circle")
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                
                Section("Preference") {
                    Button { isPresented = true } label: {
                        HStack {
                            Label("Blocked Apps", systemImage: "apps.iphone.badge.plus")
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                           .familyActivityPicker(isPresented: $isPresented,
                                                selection: $selection)
                    
                    NavigationLink(value: "Reward Time") {
                        Label("Edit Reward Time", systemImage: "creditcard.rewards")
                    }
                    
                }
                Section("Support") {
                    Label("Get Help", systemImage: "questionmark.circle")
                    Label("Feedback", systemImage: "exclamationmark.message")
                    
                }
                Section("Legal") {
                    ForEach(legalList, id: \.name) { account in
                        NavigationLink(value: account) {
                            Label(account.name, systemImage: account.imageName)
                        }
                    }
                    
                }
                
            }.navigationBarTitle(Text("Settings"))
            .navigationDestination(for: String.self) { value in
                if value == "Reward Time" {
                    RewardModification()
                }
            }
        }.onChange(of: selection) { oldValue, newValue in
            SharedData.blockedAppsSelection = newValue
            print("Saved \(newValue.applicationTokens.count) apps")
        }
    }
    
    func handleLogout() async {
        print("Logging out...")

        do {
            try await clerk.signOut()
            // Your logout logic goes here
        } catch {
            print("Error signing out: \(error)")
        }
    }
}

#Preview {
    SettingsView()
}

