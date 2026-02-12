//
//  SharedData.swift
//  BuyTime
//
//  Created by Baalavignesh Arunachalam on 1/7/26.
//

import Foundation
import FamilyControls

class SharedData {
    
    static let appGroupIdentifier = "group.com.baalavignesh.buytime"
    static let defaultsGroup: UserDefaults? = UserDefaults(suiteName: appGroupIdentifier)
    
    enum Keys: String {
        case blockedApps = "blockedAppsSelection"

        
        case earnedTimeEventActive = "earnedTimeEventActive"
        

        case currentEventTimeLeft = "currentEventTimeLeft"
        case earnedTimeMinutes = "earnedTimeMinutes"
        case spendAmount = "spendAmount"
        
        case userBalanceValues = "userBalanceValues"
    }
    
//    Blocked App Selection
    static var blockedAppsSelection: FamilyActivitySelection {
        get {
            guard let data = defaultsGroup?.data(forKey: Keys.blockedApps.rawValue) else {
                return FamilyActivitySelection()
            }

            do {
                return try JSONDecoder().decode(FamilyActivitySelection.self, from: data)
            } catch {
                print("Failed to decode FamilyActivitySelection: \(error)")
                return FamilyActivitySelection()
            }
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                defaultsGroup?.set(data, forKey: Keys.blockedApps.rawValue)
            } catch {
                print("Failed to encode FamilyActivitySelection: \(error)")
            }
        }
    }
    
    static var userBalanceValues: [String: Int] {
        get {
            defaultsGroup?.integer(forKey: Keys.userBalanceValues.rawValue) as? [String: Int] ?? [:]
        }
        set {
            defaultsGroup?.set(newValue, forKey: Keys.userBalanceValues.rawValue)
        }
    }
    
    
    
    static var earnedTimeMinutes: Int {
        get {
            defaultsGroup?.synchronize()
            return defaultsGroup?.integer(forKey: Keys.earnedTimeMinutes.rawValue) ?? 0
        }
        set {
            defaultsGroup?.set(max(0, newValue), forKey: Keys.earnedTimeMinutes.rawValue)
            defaultsGroup?.synchronize()
        }
    }
    
    static var earnedTimeEventActive: Bool {
        get {
            defaultsGroup?.bool(forKey: Keys.earnedTimeEventActive.rawValue) ?? false
        }
        set {
            defaultsGroup?.set(newValue, forKey: Keys.earnedTimeEventActive.rawValue)
        }
    }
    
    static var spendAmount: Int {
        get {
            let value = defaultsGroup?.integer(forKey: Keys.spendAmount.rawValue) ?? 0
            return value > 0 ? value : 1  // Default to 1 if not set or invalid
        }
        set {
            defaultsGroup?.set(max(1, newValue), forKey: Keys.spendAmount.rawValue)
        }
    }


}
