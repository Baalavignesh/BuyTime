//
//  TimeBalanceManager.swift
//  BuyTime
//
//  Created by Baalavignesh Arunachalam on 1/26/26.
//

import Foundation
internal import Combine
import UIKit

class TimeBalanceManager: ObservableObject  {
    static let shared = TimeBalanceManager()
    
    private var cancellables = Set<AnyCancellable>()
    
    @Published private(set) var earnedTimeMinutes: Int = 0
    
    private init() {

        self.earnedTimeMinutes = SharedData.earnedTimeMinutes
    }
    
    /// Call this to sync from SharedData (useful after extensions modify values)
    func refreshFromSharedData() {
        let newValue = SharedData.earnedTimeMinutes
        if earnedTimeMinutes != newValue {
            earnedTimeMinutes = newValue
        }
    }
    
    func addMinutes(_ minutes: Int) {
        let newValue = earnedTimeMinutes + minutes
        earnedTimeMinutes = newValue
        SharedData.earnedTimeMinutes = newValue
    }
    
    func setMinutes(_ minutes: Int) {
        earnedTimeMinutes = minutes
        SharedData.earnedTimeMinutes = minutes
    }
}

