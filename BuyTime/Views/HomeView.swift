//
//  HomeView.swift
//  BuyTime
//
//  Created by Baalavignesh Arunachalam on 12/18/25.
//

import SwiftUI
import Combine

struct FocusMinutes: Identifiable {
    let id = UUID()
    let value: Int
}

struct HomeView: View {
    // @Binding var selectedTab: Int

    @StateObject private var balanceVM = BalanceViewModel()
    @StateObject private var prefsVM = PreferencesViewModel()
    @StateObject private var focusVM: FocusViewModel

    @Environment(\.scenePhase) private var scenePhase

    // Focus start UI
    @State private var isShowingCustomPicker = false
    @State private var focusSheetMinutes: FocusMinutes? = nil
    @State private var customMinutes: Int = 30

    // Focus abandon UI
    @State private var isShowingEndFocusAlert = false

    // Help
    @State private var isShowingHelp = false

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
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    BuyTimeCard(timeBalance: balanceVM.availableMinutes)

                    todayStatsSection

                    if focusVM.isFocusActive {
                        activeFocusSection
                    } else {
                        startFocusSection
                    }
                }
                .padding(.horizontal, 20)
            }
            .refreshable {
                await balanceVM.refresh()
            }
            .navigationTitle("ByTime Platinum")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { isShowingHelp = true } label: {
                        Image(systemName: "questionmark.circle")
                    }
                }
            }
            .contentMargins(.top, 0, for: .scrollContent)
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
                        focusSheetMinutes = FocusMinutes(value: customMinutes)
                    }
                },
                onCancel: { isShowingCustomPicker = false }
            )
            .presentationDetents([.height(300)])
        }
        .sheet(item: $focusSheetMinutes) { item in
            FocusSessionSheet(
                selectedMinutes: item.value,
                onConfirm: {
                    focusSheetMinutes = nil
                    focusVM.startFocusSession(minutes: item.value)
                },
                onCancel: { focusSheetMinutes = nil }
            )
            .presentationDetents([.height(350)])
        }
        .sheet(isPresented: $isShowingHelp) {
            HelpSheet()
                .presentationDetents([.large])
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
            // Total Balance label + large time
            VStack(alignment: .leading, spacing: 6) {
                Text("Total Balance")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))

                Text("\(balanceVM.availableMinutes) min")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 14)

            Divider().padding(.horizontal, 16)

            // Detail rows
            VStack(spacing: 0) {
                detailRow(label: "Time Spent", value: "\(balanceVM.todaySpentMinutes)", "min")
                detailRow(label: "Today's Sessions", icon: "checkmark", value: "\(balanceVM.todaySessionsCompleted)", "")
            }
            .padding(.vertical, 10)

            Divider().padding(.horizontal, 16)

            Button {
                // selectedTab = 1
            } label: {
                Text("Statement and Activity")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
        }
        .background(Color(white: 0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func detailRow(label: String, icon: String? = nil, value: String, _ suffix: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
            Spacer()
            HStack(spacing: 2) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.8))
                }
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                Text(suffix)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
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
                        focusSheetMinutes = FocusMinutes(value: focusPresets[0].minutes)
                    }
                    focusButton(label: focusPresets[1].label) {
                        focusSheetMinutes = FocusMinutes(value: focusPresets[1].minutes)
                    }
                }
                HStack(spacing: 12) {
                    focusButton(label: focusPresets[2].label) {
                        focusSheetMinutes = FocusMinutes(value: focusPresets[2].minutes)
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
