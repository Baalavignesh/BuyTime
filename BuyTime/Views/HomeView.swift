//
//  HomeView.swift
//  BuyTime
//
//  Created by Baalavignesh Arunachalam on 12/18/25.
//

import SwiftUI

struct HomeView: View {
    @State var path = NavigationPath()
    @StateObject private var balanceVM = BalanceViewModel()
    @StateObject private var prefsVM = PreferencesViewModel()
    @StateObject private var focusVM: FocusViewModel

    @Environment(\.scenePhase) private var scenePhase

    // Focus start UI
    @State private var isShowingCustomPicker = false
    @State private var isShowingFocusSheet = false
    @State private var customMinutes: Int = 30

    // Focus abandon UI
    @State private var isShowingEndFocusAlert = false

    private let focusPresets: [(label: String, minutes: Int)] = [
        ("15m", 15),
        ("30m", 30),
        ("1hr", 60)
    ]

    init() {
        let balance = BalanceViewModel()
        let prefs = PreferencesViewModel()
        _balanceVM = StateObject(wrappedValue: balance)
        _prefsVM = StateObject(wrappedValue: prefs)
        _focusVM = StateObject(wrappedValue: FocusViewModel(balanceVM: balance, prefsVM: prefs))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                BuyTimeCard(timeBalance: balanceVM.availableMinutes).padding(.top, 32)

                if focusVM.isFocusActive {
                    activeFocusSection
                } else {
                    startFocusSection
                }

                // Debug buttons
                VStack(spacing: 12) {
                    Button("Add 5 minutes") {
                        balanceVM.addMinutes(5)
                    }.buttonStyle(PrimaryButtonStyle())

                    Button("Set Time to 0") {
                        balanceVM.debugSetMinutes(0)
                    }.buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
        .refreshable {
            await balanceVM.refresh()
        }
        .onAppear {
            balanceVM.onAppear()
            prefsVM.onAppear()
            customMinutes = Int(prefsVM.focusDuration)
            focusVM.syncFocusState()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                balanceVM.onForeground()
                focusVM.checkPendingSessionEnd()
                focusVM.syncFocusState()
                Task { await focusVM.drainSyncQueue() }
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            focusVM.tick()
        }
        .sheet(isPresented: $isShowingCustomPicker) {
            TimePickerSheet(
                selectedMinutes: $customMinutes,
                title: "Custom Duration",
                buttonLabel: "Continue",
                range: Array(stride(from: 10, through: 240, by: 5)),
                onConfirm: {
                    isShowingCustomPicker = false
                    Task {
                        try? await Task.sleep(for: .milliseconds(50))
                        isShowingFocusSheet = true
                    }
                },
                onCancel: { isShowingCustomPicker = false }
            )
            .presentationDetents([.height(300)])
        }
        .sheet(isPresented: $isShowingFocusSheet) {
            FocusSessionSheet(
                selectedMinutes: customMinutes,
                onConfirm: {
                    isShowingFocusSheet = false
                    focusVM.startFocusSession(minutes: customMinutes)
                },
                onCancel: { isShowingFocusSheet = false }
            )
            .presentationDetents([.height(350)])
        }
        .alert("End Focus Early?", isPresented: $isShowingEndFocusAlert) {
            Button("End Focus", role: .destructive) {
                focusVM.abandonFocusSession()
            }
            Button("Keep Focusing", role: .cancel) {}
        } message: {
            let balance = SharedData.earnedTimeMinutes
            if balance > 0 {
                Text("Your wallet balance of \(balance) min will be halved to \(balance / 2) min as a penalty.")
            } else {
                Text("Your focus session will end with no reward.")
            }
        }
    }

    // MARK: - Start Focus Section

    @ViewBuilder
    private var startFocusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupBox {
                HStack(spacing: 10) {
                    ForEach(focusPresets, id: \.minutes) { preset in
                        Button(preset.label) {
                            customMinutes = preset.minutes
                            isShowingFocusSheet = true
                        }
                    }

                    Button {
                        isShowingCustomPicker = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            } label: {
                Text("Start Focus Session")
                    .font(.headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Active Focus Section

    @ViewBuilder
    private var activeFocusSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 10) {
                HStack {
                    Text("Focus Session Active")
                        .font(.headline)
                    Spacer()
                }

                Text(focusVM.formatCountdown(focusVM.focusTimeRemaining))
                    .font(.system(size: 52, weight: .light, design: .monospaced))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)

                let mode = Mode(rawValue: SharedData.focusMode) ?? .easy
                let plannedMinutes = SharedData.focusPlannedMinutes
                let estimatedReward = Int(Double(plannedMinutes) * mode.multiplier)

                HStack(spacing: 6) {
                    Text("Mode: \(mode.rawValue)")
                    Text("•")
                    Text("Reward: ~\(estimatedReward) min")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(20)
            .background(Color(.systemIndigo).opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Button("End Focus Early") {
                isShowingEndFocusAlert = true
            }
            .foregroundStyle(.red)
        }
    }
}


#Preview {
    HomeView()
}
