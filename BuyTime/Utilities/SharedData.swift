//
//  SharedData.swift
//  BuyTime
//
//  Created by Baalavignesh Arunachalam on 1/7/26.
//

import Foundation
import FamilyControls

class SharedData {
    static let defaultsGroup: UserDefaults? = UserDefaults(suiteName: "group.com.baalavignesh.buytime")
    
    enum Keys: String {
        case blockedApps = "blockedAppsSelection"
        
        var key: String {
            self.rawValue
        }
    }
    
    static var blockedAppsSelection: FamilyActivitySelection {
        get {
            guard let data = defaultsGroup?.data(forKey: Keys.blockedApps.key) else {
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
                defaultsGroup?.set(data, forKey: Keys.blockedApps.key)
            } catch {
                print("Failed to encode FamilyActivitySelection: \(error)")
            }
        }
    }
}
