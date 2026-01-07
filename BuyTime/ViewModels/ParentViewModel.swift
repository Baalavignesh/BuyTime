//
//  ParentViewModel.swift
//  BuyTime
//
//  Created by Baalavignesh Arunachalam on 1/7/26.
//

import Foundation
import FamilyControls
internal import Combine

@MainActor
class AuthorizationManager: ObservableObject {
    
    @Published var authorizationStatus: FamilyControls.AuthorizationStatus = .notDetermined
    @Published var isLoading = true

    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Get initial status
        self.authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        
        // Subscribe to authorization status changes
        AuthorizationCenter.shared.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.authorizationStatus = status
                self?.isLoading = false
            }
            .store(in: &cancellables)
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
