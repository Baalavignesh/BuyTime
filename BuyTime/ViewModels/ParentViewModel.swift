//
//  ParentViewModel.swift
//  BuyTime
//
//  Created by Baalavignesh Arunachalam on 1/7/26.
//

import Foundation
import FamilyControls
import Combine

@MainActor
class AuthorizationManager: ObservableObject {

    @Published var authorizationStatus: FamilyControls.AuthorizationStatus = .notDetermined
    /// True until the Combine publisher has emitted a non-notDetermined status
    /// (or two emissions total, meaning the system has fully resolved).
    @Published var hasResolved = false

    private var cancellables = Set<AnyCancellable>()

    init() {
        // AuthorizationCenter publishes .notDetermined first, then the real
        // status on the next tick (for returning users). We skip the first
        // .notDetermined so we don't flash the auth prompt for approved users.
        //
        // For fresh installs, the status genuinely IS .notDetermined and no
        // second emission comes — the fallback timer handles that case.
        AuthorizationCenter.shared.$authorizationStatus
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.authorizationStatus = status
                self?.hasResolved = true
            }
            .store(in: &cancellables)

        // Fallback: if the publisher hasn't emitted a resolved status within
        // 1 second, this is likely a fresh install — show the auth prompt.
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard let self, !self.hasResolved else { return }
            self.authorizationStatus = AuthorizationCenter.shared.authorizationStatus
            self.hasResolved = true
        }
    }
    
    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            self.authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        } catch {
            print("Failed to request authorization: \(error)")
            self.authorizationStatus = .denied
        }
    }
}
