//
//  SettingsView.swift
//  BuyTime
//
//  Created by Baalavignesh Arunachalam on 12/21/25.
//

import SwiftUI
import Clerk

struct SettingsView: View {
    
    @Environment(\.clerk) private var clerk
    @State var isPresented = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    NavigationLink(value: "Personal Info") {
                        Label("Personal Info", systemImage: "person.circle")
                    }
                    
//                    Button("App Picker") { isPresented = true }
//                           .familyActivityPicker(isPresented: $isPresented,
//                                                selection: $selection)
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

