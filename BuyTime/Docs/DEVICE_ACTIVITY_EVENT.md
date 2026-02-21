# DeviceActivityEvent Implementation Plan (Final)

## Overview

This document outlines the implementation plan for using `DeviceActivityEvent` to track cumulative app usage for earned time. The system works like a **wallet/balance** — users earn time and can spend it in configurable increments.

**Example Flow:**
- User has 30 minutes of earned time (balance)
- User sets spend amount to 10 minutes
- User taps "Spend 10 minutes" on a blocked app
- Balance becomes 30 - 10 = 20 minutes (deducted immediately)
- User uses apps for 10 minutes total, then apps are blocked
- User can tap again to spend another 10 minutes (balance → 10 min)
- Process repeats until balance hits 0

---

## What is DeviceActivityEvent?

`DeviceActivityEvent` is part of Apple's Screen Time API that tracks **cumulative usage** of apps, categories, or web domains. Unlike `DeviceActivitySchedule` (which blocks based on time intervals), `DeviceActivityEvent` monitors usage and triggers when a threshold is reached.

### Key Differences

| Feature | DeviceActivitySchedule | DeviceActivityEvent |
|---------|----------------------|-------------------|
| **Purpose** | Time-based blocking (e.g., "Block from 9 AM to 5 PM") | Usage-based tracking (e.g., "Block after 30 minutes of usage") |
| **Minimum Duration** | 15 minutes minimum | 1 minute minimum |
| **Trigger** | Specific time intervals | Cumulative usage threshold |
| **Persistence** | Resets each interval | Tracks across app sessions within schedule |
| **App Targeting** | Cannot target specific apps | Can target specific ApplicationTokens |
| **Use Case** | "Block during work hours" | "Block after using Instagram for 30 minutes total" |

### How It Works

1. **Create Event**: Define an event with apps to track and a threshold (e.g., 10 minutes)
2. **Register Event**: Associate the event with a monitoring schedule using `startMonitoring(_:during:events:)`
3. **Track Usage**: System automatically tracks cumulative usage across sessions
4. **Warning (Optional)**: `eventWillReachThresholdWarning` fires before threshold if `warningTime` is set
5. **Threshold Reached**: When usage reaches threshold, `eventDidReachThreshold` fires
6. **Take Action**: Block apps and wait for user to spend more time

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              MAIN APP TARGET                                 │
│                                                                              │
│  ┌────────────────────────────────┐  ┌────────────────────────────────────┐ │
│  │  SharedData.swift              │  │  ManagedSettings.swift             │ │
│  │  ─────────────────────────     │  │  ─────────────────────────         │ │
│  │  • earnedTimeMinutes (balance) │  │  • startEarnedTimeMonitoring()     │ │
│  │  • earnedTimeEventActive       │  │  • stopEarnedTimeMonitoring()      │ │
│  │  • spendAmount (user setting)  │  │  • applyRestrictions()             │ │
│  │  • blockedAppsSelection        │  │  • removeRestriction()             │ │
│  └────────────────────────────────┘  └────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
                                       │
                    ┌──────────────────┼──────────────────┐
                    ▼                  ▼                  ▼
┌─────────────────────────┐ ┌─────────────────────────┐ ┌─────────────────────────┐
│  SHIELD ACTION          │ │  DEVICE ACTIVITY        │ │  SHIELD CONFIGURATION   │
│  EXTENSION TARGET       │ │  MONITOR EXTENSION      │ │  EXTENSION TARGET       │
│  ─────────────────────  │ │  TARGET                 │ │  ─────────────────────  │
│                         │ │  ─────────────────────  │ │                         │
│  ShieldActionExtension  │ │                         │ │  ShieldConfiguration    │
│  .swift                 │ │  DeviceActivity         │ │  Extension.swift        │
│                         │ │  MonitorExtension       │ │                         │
│  • handle(action:for:)  │ │  .swift                 │ │  • configuration()      │
│  • handleTemporary      │ │                         │ │    - Dynamic button     │
│    Access()             │ │  • eventDidReach        │ │      label showing      │
│  • Deduct from balance  │ │    Threshold()          │ │      spend amount       │
│  • Start monitoring     │ │  • eventWillReach       │ │                         │
│                         │ │    ThresholdWarning()   │ │                         │
│                         │ │  • reapplyRestrictions  │ │                         │
└─────────────────────────┘ └─────────────────────────┘ └─────────────────────────┘
```

### Data Flow (Wallet System)

```
                    ┌─────────────────────────────┐
                    │  Balance: 30 min            │
                    │  Spend Amount: 10 min       │
                    └─────────────────────────────┘
                                  │
                                  ▼
                    ┌─────────────────────────────┐
                    │  User taps                  │
                    │  "Spend 10 minutes"         │
                    └─────────────────────────────┘
                                  │
                                  ▼
                    ┌─────────────────────────────┐
                    │  ShieldActionExtension      │
                    │  ─────────────────────────  │
                    │  1. Check: 30 >= 10? ✓      │
                    │  2. Deduct: 30 - 10 = 20    │
                    │  3. Start monitoring (10m)  │
                    └─────────────────────────────┘
                                  │
                                  ▼
                    ┌─────────────────────────────┐
                    │  Balance: 20 min            │
                    │  All blocked apps unlocked  │
                    │  Tracking usage...          │
                    └─────────────────────────────┘
                                  │
                                  ▼ (after 10 min usage)
                    ┌─────────────────────────────┐
                    │  DeviceActivityMonitor      │
                    │  eventDidReachThreshold()   │
                    │  ─────────────────────────  │
                    │  1. Re-apply shields        │
                    │  2. Stop monitoring         │
                    │  (Balance stays at 20 min)  │
                    └─────────────────────────────┘
                                  │
                                  ▼
                    ┌─────────────────────────────┐
                    │  Apps blocked again         │
                    │  User can spend again       │
                    │  Balance: 20 min remaining  │
                    └─────────────────────────────┘
```

---

## Implementation Checklist

### Phase 1: Data Storage Setup

- [ ] **Step 1.1**: Update `SharedData.swift` - Add earned time storage
  - Add `earnedTimeMinutes` key (the balance)
  - Add `earnedTimeEventActive` key (monitoring state)
  - Add `spendAmount` key (user-configurable spend amount)

- [ ] **Step 1.2**: Test data persistence
  - Verify all values save/load correctly
  - Test across app restarts

### Phase 2: DeviceActivityEvent Setup

- [ ] **Step 2.1**: Update `ManagedSettings.swift` - Add event constants
  - Add `earnedTimeActivityName` constant
  - Add `earnedTimeEventName` constant

- [ ] **Step 2.2**: Create `startEarnedTimeMonitoring(minutes:)` method
  - Accept `minutes` parameter (the amount to monitor)
  - Guard: Check if minutes > 0
  - Guard: Check if apps are selected to monitor
  - Remove shields to allow app usage
  - Create a daily repeating schedule
  - Create `DeviceActivityEvent` with threshold = minutes parameter
  - Start monitoring with event

- [ ] **Step 2.3**: Create `stopEarnedTimeMonitoring()` method
  - Stop monitoring the earned time activity
  - Reapply restrictions (block apps)
  - Set earnedTimeEventActive to false
  - **DO NOT reset earnedTimeMinutes** (balance persists)

### Phase 3: Monitor Extension Implementation

- [ ] **Step 3.1**: Update `DeviceActivityMonitorExtension.swift`
  - Implement `eventDidReachThreshold()` for earned time event
  - Block apps when threshold reached
  - **DO NOT reset balance** (already deducted)
  - Add logging for debugging

- [ ] **Step 3.2**: Implement `eventWillReachThresholdWarning()` (optional)
  - Warn user when warning time is reached

### Phase 4: Shield Action Integration

- [ ] **Step 4.1**: Update `ShieldActionExtension.swift`
  - Read `spendAmount` from SharedData
  - Check if balance >= spendAmount
  - Deduct spendAmount from balance **before** starting monitoring
  - Start monitoring with the spendAmount

- [ ] **Step 4.2**: Test shield button flow
  - Verify deduction happens correctly
  - Verify balance persists after threshold reached

### Phase 5: Shield Configuration Update

- [ ] **Step 5.1**: Update `ShieldConfigurationExtension.swift`
  - Make button label dynamic: "Spend X minutes"
  - Read spendAmount from SharedData

### Phase 6: Testing & Validation

- [ ] **Step 6.1**: Test wallet flow
  - Set balance to 30 minutes
  - Set spendAmount to 10 minutes
  - Spend 10 → verify balance is 20
  - Use apps for 10 min → verify blocked
  - Spend 10 again → verify balance is 10
  - Repeat until balance is 0

- [ ] **Step 6.2**: Test edge cases
  - Insufficient balance (balance < spendAmount)
  - Zero balance
  - Change spendAmount mid-session
  - App restart during active monitoring

### Phase 7: Code Cleanup

- [ ] **Step 7.1**: Remove old temporary unlock code if not needed

- [ ] **Step 7.2**: Add code comments and documentation

---

## Detailed Code Changes

### File 1: `SharedData.swift`

```swift
import Foundation
import FamilyControls

class SharedData {
    
    // App Group identifier - must match your App Group configuration
    static let appGroupIdentifier = "group.com.baalavignesh.buytime"
    
    static let defaultsGroup = UserDefaults(suiteName: appGroupIdentifier)
    
    enum Keys: String {
        case blockedApps = "blockedAppsSelection"
        
        // Earned time tracking (wallet system)
        case earnedTimeMinutes = "earnedTimeMinutes"
        case earnedTimeEventActive = "earnedTimeEventActive"
        case spendAmount = "spendAmount"
    }
    
    // ============================================================
    // MARK: - Blocked Apps Selection
    // ============================================================
    
    static var blockedAppsSelection: FamilyActivitySelection {
        get {
            guard let data = defaultsGroup?.data(forKey: Keys.blockedApps.rawValue),
                  let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
                return FamilyActivitySelection()
            }
            return selection
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaultsGroup?.set(data, forKey: Keys.blockedApps.rawValue)
            }
        }
    }
    
    // ============================================================
    // MARK: - Earned Time (Balance)
    // ============================================================
    
    /// The user's earned time balance in minutes (like a wallet)
    /// This is the total available time that can be spent
    static var earnedTimeMinutes: Int {
        get {
            defaultsGroup?.integer(forKey: Keys.earnedTimeMinutes.rawValue) ?? 0
        }
        set {
            defaultsGroup?.set(max(0, newValue), forKey: Keys.earnedTimeMinutes.rawValue)
        }
    }
    
    /// Whether earned time monitoring is currently active
    static var earnedTimeEventActive: Bool {
        get {
            defaultsGroup?.bool(forKey: Keys.earnedTimeEventActive.rawValue) ?? false
        }
        set {
            defaultsGroup?.set(newValue, forKey: Keys.earnedTimeEventActive.rawValue)
        }
    }
    
    /// The amount of time user wants to spend per session (user-configurable)
    /// Default is 5 minutes if not set
    static var spendAmount: Int {
        get {
            let value = defaultsGroup?.integer(forKey: Keys.spendAmount.rawValue) ?? 0
            return value > 0 ? value : 5  // Default to 5 if not set or invalid
        }
        set {
            defaultsGroup?.set(max(1, newValue), forKey: Keys.spendAmount.rawValue)
        }
    }
}
```

---

### File 2: `ManagedSettings.swift`

```swift
import Foundation
import ManagedSettings
import FamilyControls
import DeviceActivity

class AppBlockUtils {

    // ============================================================
    // MARK: - Activity Names
    // ============================================================
    
    /// Activity name for general blocking schedule
    static let blockerActivityName = DeviceActivityName("com.baalavignesh.buytime.blockerActivity")
    
    /// Activity name for earned time tracking
    static let earnedTimeActivityName = DeviceActivityName("com.baalavignesh.buytime.earnedTime")
    
    /// Event name for earned time threshold
    static let earnedTimeEventName = DeviceActivityEvent.Name("com.baalavignesh.buytime.earnedTimeEvent")

    // ============================================================
    // MARK: - Properties
    // ============================================================
    
    let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("buytimeAppRestriction"))
    let center = DeviceActivityCenter()
    
    // ============================================================
    // MARK: - Basic Blocking Methods
    // ============================================================
    
    /// Start monitoring schedule for blocking
    func startMonitoringSchedule() {
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true,
            warningTime: nil
        )
        
        do {
            try center.startMonitoring(Self.blockerActivityName, during: schedule)
            print("✓ Monitoring started")
        } catch {
            print("✗ Error starting Device Activity monitoring: \(error)")
        }
    }
    
    /// Stop all monitoring
    func stopMonitoring() {
        center.stopMonitoring([Self.blockerActivityName, Self.earnedTimeActivityName])
        print("✓ Monitoring stopped")
    }
    
    /// Apply restrictions (block apps)
    func applyRestrictions(selection: FamilyActivitySelection) {
        let applicationTokens = selection.applicationTokens
        let categoryTokens = selection.categoryTokens
        let webDomainTokens = selection.webDomainTokens
        
        store.shield.applications = applicationTokens.isEmpty ? nil : applicationTokens
        store.shield.applicationCategories = categoryTokens.isEmpty ? nil : .specific(categoryTokens)
        store.shield.webDomains = webDomainTokens.isEmpty ? nil : webDomainTokens
        
        print("✓ Restrictions applied")
    }
    
    /// Remove all restrictions (unblock apps)
    func removeRestriction() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        
        print("✓ Restrictions removed")
    }
    
    // ============================================================
    // MARK: - Earned Time Monitoring (Wallet System)
    // ============================================================
    
    /// Start monitoring earned time usage with DeviceActivityEvent
    /// - Parameter minutes: The amount of time to monitor (from user's spend amount)
    func startEarnedTimeMonitoring(minutes: Int) {
        // Guard 1: Check if minutes is valid
        guard minutes > 0 else {
            print("✗ Invalid time amount: \(minutes)")
            return
        }
        
        // Guard 2: Check if apps are selected to monitor
        let selection = SharedData.blockedAppsSelection
        guard !selection.applicationTokens.isEmpty || 
              !selection.categoryTokens.isEmpty ||
              !selection.webDomainTokens.isEmpty else {
            print("✗ No apps selected to monitor")
            return
        }
        
        // Step 1: Remove shields to allow app usage
        removeRestriction()
        
        // Step 2: Create a daily schedule (container for the event)
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true,
            warningTime: nil
        )
        
        // Step 3: Create the DeviceActivityEvent
        // Track all blocked apps, trigger at specified minutes
        let event = DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens,
            threshold: DateComponents(minute: minutes),
            warningTime: minutes > 1 ? DateComponents(minute: 1) : nil  // Warn 1 min before if possible
        )
        
        // Step 4: Start monitoring with the event
        do {
            try center.startMonitoring(
                Self.earnedTimeActivityName,
                during: schedule,
                events: [Self.earnedTimeEventName: event]
            )
            SharedData.earnedTimeEventActive = true
            print("✓ Started earned time monitoring: \(minutes) minutes")
            print("  - Tracking \(selection.applicationTokens.count) apps")
            print("  - Tracking \(selection.categoryTokens.count) categories")
            print("  - Tracking \(selection.webDomainTokens.count) web domains")
        } catch {
            print("✗ Failed to start earned time monitoring: \(error)")
        }
    }
    
    /// Stop earned time monitoring and block apps
    /// Called when threshold is reached
    /// NOTE: Does NOT reset balance - balance was already deducted when spending
    func stopEarnedTimeMonitoring() {
        // Stop monitoring
        center.stopMonitoring([Self.earnedTimeActivityName])
        
        // Update state
        SharedData.earnedTimeEventActive = false
        
        // Re-apply restrictions (block apps again)
        applyRestrictions(selection: SharedData.blockedAppsSelection)
        
        print("✓ Earned time session ended, apps blocked")
        print("  - Remaining balance: \(SharedData.earnedTimeMinutes) minutes")
    }
}
```

---

### File 3: `DeviceActivityMonitorExtension.swift`

```swift
import DeviceActivity
import ManagedSettings
import FamilyControls
import Foundation

class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    
    let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("buytimeAppRestriction"))
    
    // ============================================================
    // MARK: - Interval Callbacks
    // ============================================================
    
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        print("📍 Interval started: \(activity.rawValue)")
    }
    
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        print("📍 Interval ended: \(activity.rawValue)")
    }
    
    // ============================================================
    // MARK: - Event Callbacks (DeviceActivityEvent)
    // ============================================================
    
    /// Called when usage threshold is reached
    /// This is the KEY method for earned time tracking
    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)
        
        print("🎯 Event threshold reached: \(event.rawValue)")
        
        // Check if this is our earned time event
        if activity == DeviceActivityName("com.baalavignesh.buytime.earnedTime") {
            print("✓ Earned time session complete")
            print("  - Remaining balance: \(SharedData.earnedTimeMinutes) minutes")
            
            // Update state (DO NOT reset balance - already deducted)
            SharedData.earnedTimeEventActive = false
            
            // Re-apply shields
            reapplyRestrictions()
            
            // Stop monitoring this activity
            let center = DeviceActivityCenter()
            center.stopMonitoring([activity])
        }
    }
    
    /// Called before threshold is reached (if warningTime is set)
    override func eventWillReachThresholdWarning(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventWillReachThresholdWarning(event, activity: activity)
        
        print("⚠️ Event warning: \(event.rawValue)")
        
        if activity == DeviceActivityName("com.baalavignesh.buytime.earnedTime") {
            print("⚠️ 1 minute remaining in this session")
            // TODO: Show local notification to user
        }
    }
    
    // ============================================================
    // MARK: - Interval Warnings (Optional)
    // ============================================================
    
    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        super.intervalWillStartWarning(for: activity)
    }
    
    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
    }
    
    override func eventWillReachThresholdWarning(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventWillReachThresholdWarning(event, activity: activity)
    }
    
    // ============================================================
    // MARK: - Helper Methods
    // ============================================================
    
    /// Re-apply all restrictions from SharedData
    private func reapplyRestrictions() {
        let selection = SharedData.blockedAppsSelection
        
        store.shield.applications = selection.applicationTokens.isEmpty 
            ? nil 
            : selection.applicationTokens
        
        store.shield.applicationCategories = selection.categoryTokens.isEmpty 
            ? nil 
            : .specific(selection.categoryTokens)
        
        store.shield.webDomains = selection.webDomainTokens.isEmpty 
            ? nil 
            : selection.webDomainTokens
        
        print("✓ Shields re-applied")
    }
}
```

---

### File 4: `ShieldActionExtension.swift`

```swift
import ManagedSettings
import Foundation
import FamilyControls
import DeviceActivity

class ShieldActionExtension: ShieldActionDelegate {

    let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("buytimeAppRestriction"))
    
    // ============================================================
    // MARK: - Shield Action Handlers
    // ============================================================
    
    /// Handle action for Application
    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        print("🔘 ShieldAction triggered for app: \(action)")
        
        switch action {
        case .primaryButtonPressed:
            handleTemporaryAccess(completionHandler: completionHandler)
        case .secondaryButtonPressed:
            completionHandler(.close)
        @unknown default:
            fatalError()
        }
    }
    
    /// Handle action for WebDomain
    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        switch action {
        case .primaryButtonPressed:
            handleTemporaryAccess(completionHandler: completionHandler)
        case .secondaryButtonPressed:
            completionHandler(.close)
        @unknown default:
            fatalError()
        }
    }
    
    /// Handle action for Category
    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        switch action {
        case .primaryButtonPressed:
            handleTemporaryAccess(completionHandler: completionHandler)
        case .secondaryButtonPressed:
            completionHandler(.close)
        @unknown default:
            fatalError()
        }
    }
    
    // ============================================================
    // MARK: - Temporary Access (Wallet System)
    // ============================================================
    
    /// Handle temporary access request using earned time (wallet system)
    private func handleTemporaryAccess(
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        let spendAmount = SharedData.spendAmount
        let currentBalance = SharedData.earnedTimeMinutes
        
        print("💰 Spend request: \(spendAmount) min")
        print("   Current balance: \(currentBalance) min")
        
        // Check if user has enough balance
        guard currentBalance >= spendAmount else {
            print("✗ Insufficient balance: need \(spendAmount), have \(currentBalance)")
            // TODO: Could show a message to user here
            completionHandler(.close)
            return
        }
        
        // Deduct from balance FIRST (like a debit card)
        SharedData.earnedTimeMinutes = currentBalance - spendAmount
        print("✓ Deducted \(spendAmount) min")
        print("   New balance: \(SharedData.earnedTimeMinutes) min")
        
        // Start monitoring for the spend amount
        let blockUtils = AppBlockUtils()
        blockUtils.startEarnedTimeMonitoring(minutes: spendAmount)
        
        completionHandler(.close)
    }
}
```

---

### File 5: `ShieldConfigurationExtension.swift`

```swift
import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    // ============================================================
    // MARK: - Dynamic Configuration
    // ============================================================
    
    /// Generate shield configuration with dynamic button label
    private var dynamicConfig: ShieldConfiguration {
        let spendAmount = SharedData.spendAmount
        let balance = SharedData.earnedTimeMinutes
        
        // Customize button text based on balance
        let buttonText: String
        if balance >= spendAmount {
            buttonText = "Spend \(spendAmount) minutes"
        } else if balance > 0 {
            buttonText = "Spend \(balance) minutes"  // Show available balance
        } else {
            buttonText = "No time available"
        }
        
        return ShieldConfiguration(
            backgroundColor: UIColor.black,
            icon: UIImage(systemName: "hourglass"),
            title: ShieldConfiguration.Label(
                text: "App Blocked",
                color: .white
            ),
            subtitle: ShieldConfiguration.Label(
                text: balance > 0 
                    ? "Balance: \(balance) minutes available"
                    : "Earn more time to unlock",
                color: .gray
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: buttonText,
                color: .white
            ),
            primaryButtonBackgroundColor: balance >= spendAmount 
                ? UIColor.systemBlue 
                : UIColor.systemGray,
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "Close",
                color: .white
            )
        )
    }
    
    // ============================================================
    // MARK: - Configuration Overrides
    // ============================================================
    
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        dynamicConfig
    }
    
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        dynamicConfig
    }
    
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        dynamicConfig
    }
    
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        dynamicConfig
    }
}
```

---

## Testing Guide

### Wallet Flow Test

1. **Setup**:
   ```swift
   SharedData.earnedTimeMinutes = 30  // Set balance to 30 min
   SharedData.spendAmount = 10         // Set spend amount to 10 min
   ```

2. **Test Spending**:
   | Action | Expected Balance | Expected Behavior |
   |--------|------------------|-------------------|
   | Initial | 30 min | Apps blocked |
   | Tap "Spend 10 minutes" | 20 min | Apps unlock, monitoring starts |
   | Use apps for 10 min | 20 min | Apps block again |
   | Tap "Spend 10 minutes" | 10 min | Apps unlock |
   | Use apps for 10 min | 10 min | Apps block again |
   | Tap "Spend 10 minutes" | 0 min | Apps unlock |
   | Use apps for 10 min | 0 min | Apps block again |
   | Tap "Spend 10 minutes" | 0 min | Nothing happens (insufficient balance) |

3. **Verify Console Logs**:
   ```
   💰 Spend request: 10 min
      Current balance: 30 min
   ✓ Deducted 10 min
      New balance: 20 min
   ✓ Started earned time monitoring: 10 minutes
   ... (after usage) ...
   🎯 Event threshold reached: com.baalavignesh.buytime.earnedTimeEvent
   ✓ Earned time session complete
     - Remaining balance: 20 minutes
   ✓ Shields re-applied
   ```

### Edge Case Tests

| Test Case | Setup | Expected Behavior |
|-----------|-------|-------------------|
| Insufficient balance | balance=5, spend=10 | Logs "Insufficient balance", stays blocked |
| Zero balance | balance=0 | Logs "Insufficient balance", stays blocked |
| Exact balance | balance=10, spend=10 | Works, balance becomes 0 |
| Change spend mid-session | Change spendAmount while monitoring | Next session uses new amount |
| Partial usage | Use 5 min of 10 min session, close app | Resumes tracking when app reopens |

---

## Common Issues & Solutions

### Issue: Balance Not Deducting

**Symptoms**: Balance stays the same after tapping spend button

**Solutions**:
1. Verify SharedData is using correct App Group identifier
2. Check that `SharedData.earnedTimeMinutes -= spendAmount` is executing
3. Ensure App Group is properly configured in all targets

### Issue: Button Shows Wrong Amount

**Symptoms**: Shield button shows old spend amount

**Solutions**:
1. Shield extensions cache configurations — may need to re-block apps
2. Verify `SharedData.spendAmount` is being read correctly
3. Check App Group sharing between main app and extension

### Issue: Balance Resets to Zero

**Symptoms**: Balance becomes 0 after session ends

**Solutions**:
1. Ensure `stopEarnedTimeMonitoring()` does NOT reset `earnedTimeMinutes`
2. Check `eventDidReachThreshold()` does NOT reset balance
3. Verify no other code is resetting the balance

---

## API Quick Reference

### SharedData Properties

| Property | Type | Purpose |
|----------|------|---------|
| `earnedTimeMinutes` | Int | User's balance (wallet) |
| `spendAmount` | Int | Amount to spend per session |
| `earnedTimeEventActive` | Bool | Is monitoring active? |
| `blockedAppsSelection` | FamilyActivitySelection | Which apps are blocked |

### AppBlockUtils Methods

| Method | Purpose |
|--------|---------|
| `startEarnedTimeMonitoring(minutes:)` | Start tracking usage for X minutes |
| `stopEarnedTimeMonitoring()` | Stop tracking and re-block apps |
| `applyRestrictions(selection:)` | Block apps |
| `removeRestriction()` | Unblock all apps |

---

## File Summary

| File | Target | Key Changes |
|------|--------|-------------|
| `SharedData.swift` | Main App | Add `earnedTimeMinutes`, `spendAmount`, `earnedTimeEventActive` |
| `ManagedSettings.swift` | Main App | Add `startEarnedTimeMonitoring(minutes:)`, update `stopEarnedTimeMonitoring()` |
| `DeviceActivityMonitorExtension.swift` | Monitor Extension | Handle threshold without resetting balance |
| `ShieldActionExtension.swift` | ShieldAction Extension | Deduct balance before monitoring |
| `ShieldConfigurationExtension.swift` | ShieldConfig Extension | Dynamic button label showing spend amount |

---

## Next Steps (After MVP)

1. **Focus Mode Integration** — Earn time by completing focus sessions
2. **UI for spend amount** — Let user choose how much to spend
3. **Balance history** — Track earning and spending over time
4. **Notifications** — Alert when balance is low or session ending
5. **Per-app limits** — Different spend limits for different apps

---

**Last Updated**: January 2026  
**Status**: Implementation Plan - Final Version  
**Version**: 3.0 (Wallet System)
