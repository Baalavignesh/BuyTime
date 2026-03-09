//
//  SettingsView.swift
//  BuyTime
//
//  Created by Baalavignesh Arunachalam on 12/21/25.
//

import Clerk
import FamilyControls
import SwiftUI

struct SettingsView: View {

  @Environment(\.clerk) private var clerk
  @State var isPresented = false
  @State var selection = SharedData.blockedAppsSelection
  @State private var blockedAppsSheet: Bool = false
  @State private var spendAmount: Int = SharedData.spendAmount
  @State private var showTimePickerSheet = false

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
          Button {
            blockedAppsSheet = true
          } label: {
            HStack {
              Label("Blocked Apps", systemImage: "apps.iphone.badge.plus")
              Spacer()
            }
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .familyActivityPicker(
            isPresented: $blockedAppsSheet,
            selection: $selection)
          Button {
            showTimePickerSheet = true
          } label: {
HStack {
            Label("Set Spend Time", systemImage: "clock")
            Spacer()
            Text(formatDuration(spendAmount)).foregroundStyle(.secondary).padding(.trailing, 8)
}.contentShape(Rectangle())

          }.buttonStyle(.plain)
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
    }.onChange(of: spendAmount) { oldValue, newValue in
      SharedData.spendAmount = newValue
      print("Saved spend amount: \(newValue)")

    }.sheet(isPresented: $showTimePickerSheet) {
      TimePickerSheet(
        selectedMinutes: $spendAmount,
        title: "Set Spend Time",
        buttonLabel: "Set Time",
        range: Array(stride(from: 5, to: 60, by: 5)),
        onConfirm: {
          showTimePickerSheet = false
        }
      )
      .presentationDetents([.height(300)])
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

  private func formatDuration(_ minutes: Int) -> String {
    if minutes >= 60 {
      let h = minutes / 60
      let m = minutes % 60
      return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }
    return "\(minutes) min"
  }
}

#Preview {
  SettingsView()
}
