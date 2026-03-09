//
//  HelpSheet.swift
//  BuyTime
//
//  Created by Baalavignesh Arunachalam on 3/9/26.
//

import SwiftUI

struct HelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    helpRow(icon: "timer", title: "Focus to Earn", description: "Start a focus session to earn minutes for your wallet.")
                    helpRow(icon: "hourglass", title: "Spend Minutes", description: "When blocked apps show a shield, spend your earned minutes to unlock them temporarily.")
                    helpRow(icon: "creditcard", title: "Your Card", description: "The card shows your current wallet balance — minutes you can spend on screen time.")
                    helpRow(icon: "xmark.circle", title: "Ending Early", description: "If you end a focus session early, half your wallet balance is deducted as a penalty.")
                }
            }
            .navigationTitle("How It Works")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func helpRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
