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

