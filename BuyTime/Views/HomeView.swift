//
//  HomeView.swift
//  BuyTime
//
//  Created by Baalavignesh Arunachalam on 12/18/25.
//

import SwiftUI
import Combine

struct HomeView: View {
    // @Binding var selectedTab: Int

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
        // _selectedTab = selectedTab
        let balance = BalanceViewModel()
        let prefs = PreferencesViewModel()
        _balanceVM = StateObject(wrappedValue: balance)
        _prefsVM = StateObject(wrappedValue: prefs)
        _focusVM = StateObject(wrappedValue: FocusViewModel(balanceVM: balance, prefsVM: prefs))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                BuyTimeCard(timeBalance: balanceVM.availableMinutes).padding(.top, 32)

                todayStatsSection

                if focusVM.isFocusActive {
                    activeFocusSection
                } else {
                    // startFocusSection
                    activeFocusSection
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

    // MARK: - Today Stats

    @ViewBuilder
    private var todayStatsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Today")
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .tracking(1)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 16)

            HStack(spacing: 0) {
                statColumn(value: "\(balanceVM.todayEarnedMinutes)m", label: "Earned")
                statColumn(value: "\(balanceVM.todaySpentMinutes)m", label: "Spent")
                statColumn(value: "\(balanceVM.todaySessionsCompleted)", label: "Sessions")
            }
            .padding(.bottom, 20)

            Divider().padding(.horizontal, 16)

            Button {
                // selectedTab = 1
            } label: {
                Text("History and Activity")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func statColumn(value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Start Focus Section

    @ViewBuilder
    private var startFocusSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Focus Session")
                .font(.headline)

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    focusButton(label: focusPresets[0].label) {
                        customMinutes = focusPresets[0].minutes
                        isShowingFocusSheet = true
                    }
                    focusButton(label: focusPresets[1].label) {
                        customMinutes = focusPresets[1].minutes
                        isShowingFocusSheet = true
                    }
                }
                HStack(spacing: 12) {
                    focusButton(label: focusPresets[2].label) {
                        customMinutes = focusPresets[2].minutes
                        isShowingFocusSheet = true
                    }
                    focusButton(label: "Custom") {
                        isShowingCustomPicker = true
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func focusButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Active Focus Section

    @ViewBuilder
    private var activeFocusSection: some View {
        let mode = Mode(rawValue: SharedData.focusMode) ?? .easy
        let plannedMinutes = SharedData.focusPlannedMinutes
        let estimatedReward = Int(Double(plannedMinutes) * mode.multiplier)

        ActiveFocusCard(
            countdown: focusVM.formatCountdown(focusVM.focusTimeRemaining),
            mode: mode,
            estimatedReward: estimatedReward,
            onEndEarly: { isShowingEndFocusAlert = true }
        )
    }
}


#Preview {
    HomeView()
}
