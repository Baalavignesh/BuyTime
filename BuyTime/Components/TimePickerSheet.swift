//
//  TimePickerSheet.swift
//  BuyTime
//
//  Reusable time-picker sheet used by HomeView and SettingsView.
//

import SwiftUI

struct TimePickerSheet: View {

  // The value the picker is bound to
  @Binding var selectedMinutes: Int

  // Customizable properties
  var title: String = "Select Time"
  var buttonLabel: String = "Done"
  var range: [Int] = Array(stride(from: 5, through: 60, by: 5))

  // What happens when the button is tapped
  var onConfirm: () -> Void
  // Optional cancel action
  var onCancel: (() -> Void)? = nil

  var body: some View {
    NavigationStack {
      VStack {
        Picker("Duration", selection: $selectedMinutes) {
          ForEach(range, id: \.self) { minute in
            Text(formatDuration(minute)).tag(minute)
          }
        }
        .pickerStyle(.wheel)
        .labelsHidden()

        Spacer()

        Button {
          onConfirm()
        } label: {
          Text(buttonLabel)
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(14)
        }
        .padding(.horizontal)
        .padding(.bottom)
      }
      .navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        if let onCancel = onCancel {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { onCancel() }
          }
        }
      }
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
