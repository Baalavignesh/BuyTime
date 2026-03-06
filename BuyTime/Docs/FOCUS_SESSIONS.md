# Focus Sessions — Implementation Plan

## Overview

Focus sessions allow users to lock themselves out of selected apps for a chosen duration. Completing a session **earns reward minutes** into their wallet. During a focus session, the blocked apps still show a shield — but it's a different one that **prevents spending time**. Focus always takes priority over the normal spend shield.

**Core principle:** The ManagedSettingsStore shield is always applied to blocked apps. We only decide *which* ShieldConfiguration to render based on focus state stored in SharedData.

### Session Modes & Reward Multipliers

| Mode | Multiplier | Reward per 60 min focus |
|------|-----------|------------------------|
| `fun` | 100% | 60 min |
| `easy` | 75% | 45 min |
| `medium` | 50% | 30 min |
| `hard` | 25% | 15 min |

`rewardMinutes = floor(actualDurationMinutes × multiplier / 100)` — computed server-side on `POST /api/sessions/end`.

---

## Interaction with Active Earned Time Sessions

When the user starts focus while an earned time session is active (apps are unlocked):

- The earned time DeviceActivity monitoring is stopped
- `remainingEarnedTimeMinutes` is **left as-is** — `earnedTimeEventActive = false` signals the session is paused, not active
- Shields are re-applied immediately
- Focus session begins

When focus ends (naturally or cancelled):
- If `remainingEarnedTimeMinutes > 0`, earned time monitoring is restarted with that exact value
- Apps unlock again — **no "Spend" tap required**
- `remainingEarnedTimeMinutes` resets naturally as the resumed session consumes it

> **Accuracy:** `remainingEarnedTimeMinutes` is decremented by DeviceActivity — only when the blocked app is in the foreground with the screen on. Maximum inaccuracy is 1 minute (the partial minute in progress when focus starts is discarded), always in the user's favour.

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                              MAIN APP TARGET                                  │
│                                                                               │
│  ┌──────────────────────────┐   ┌──────────────────────────────────────────┐  │
│  │  SharedData.swift        │   │  ManagedSettings.swift (AppBlockUtils)   │  │
│  │  ──────────────────────  │   │  ──────────────────────────────────────  │  │
│  │  Focus state:            │   │  • startFocusSession(minutes:mode:)      │  │
│  │  • isFocusActive         │   │  • endFocusSession()                     │  │
│  │  • focusEndTime          │   │  • startEarnedTimeMonitoring(minutes:)   │  │
│  │  • focusSessionId        │   │  • applyRestrictions(selection:)         │  │
│  │  • focusStartTime        │   │  • removeRestriction()                   │  │
│  │                          │   │  Focus activity name:                    │  │
│  │  Earned time state:      │   │  com.baalavignesh.buytime.focusSession   │  │
│  │  • remainingEarnedTimeMin│   └──────────────────────────────────────────┘  │
│  │  • earnedTimeEventActive │   ┌──────────────────────────────────────────┐  │
│  │                          │   │  HomeView.swift                          │  │
│  │  Backend handoff:        │   │  ──────────────────────────────────────  │  │
│  │  • pendingSessionEnd     │   │  • Preset focus duration chips           │  │
│  │  • pendingActualMinutes  │   │  • Mode uses preference default          │  │
│  └──────────────────────────┘   │  • Active focus: countdown + End button  │  │
│                                  │  • Earned time remaining display         │  │
│                                  └──────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────────┘
                                    │
               ┌────────────────────┼─────────────────────┐
               ▼                    ▼                      ▼
┌──────────────────────┐ ┌──────────────────────┐ ┌──────────────────────────┐
│  SHIELD ACTION       │ │  DEVICE ACTIVITY     │ │  SHIELD CONFIGURATION    │
│  EXTENSION           │ │  MONITOR EXTENSION   │ │  EXTENSION               │
│  ─────────────────── │ │  ─────────────────── │ │  ─────────────────────── │
│                       │ │                      │ │                          │
│  handleTemporary      │ │  intervalDidEnd()    │ │  buildConfig()           │
│  Access()             │ │  → focus ends        │ │  → checks isFocusActive  │
│  → check focus first  │ │  → clear flags       │ │                          │
│  → if active: .close  │ │  → resume earned     │ │  if focus:               │
│  → else: normal spend │ │    time if paused    │ │    buildFocusConfig()    │
│                       │ │                      │ │  else:                   │
│                       │ │  eventDidReach        │ │    buildNormalConfig()   │
│                       │ │  Threshold()          │ │                          │
│                       │ │  → earned time ends  │ │                          │
└──────────────────────┘ └──────────────────────┘ └──────────────────────────┘
```

---

## Full Flow Diagrams

### Happy Path: Focus Session (No Collision)

```
User has 20 min balance, apps blocked, no active session
                │
User opens HomeView → taps "30 min" preset
(mode is loaded from GET /api/preferences → "easy")
                │
                ▼
        startFocusSession(minutes: 30, mode: "easy")
        ─────────────────────────────────────────────
        1. Guard: apps selected ✓
        2. Guard: not already in focus ✓
        3. Call POST /api/sessions/start → get sessionId
        4. SharedData.focusSessionId = sessionId
        5. SharedData.focusStartTime = Date().timeIntervalSince1970
        6. SharedData.isFocusActive = true
        7. SharedData.focusEndTime = now + 30*60
        8. applyRestrictions() (shields already on, ensures they are)
        9. Start DeviceActivitySchedule (now → now+30min) for cleanup
                │
                ▼
        ┌────────────────────────────────────┐
        │  Focus active                       │
        │  HomeView: countdown 30:00 → 0:00  │
        │  Blocked app shield: "Focus Mode"   │
        │  Spend button: BLOCKED             │
        └────────────────────────────────────┘
                │
                ▼ (30 min passes)
        DeviceActivityMonitorExtension.intervalDidEnd()
        ────────────────────────────────────────────────
        1. Clear SharedData.isFocusActive = false
        2. Clear SharedData.focusEndTime = 0
        3. Set SharedData.pendingSessionEnd = true
        4. Set SharedData.pendingActualMinutes = 30
        5. Check pausedEarnedTimeMinutes → 0, nothing to resume
        (Shields remain applied — apps still blocked, normal shield now shows)
                │
                ▼
        App comes to foreground (scenePhase → .active)
        ───────────────────────────────────────────────
        1. Detect pendingSessionEnd == true
        2. Call POST /api/sessions/end(sessionId, actualMinutes: 30)
        3. Response: rewardMinutes = floor(30 × 75/100) = 22 min
        4. TimeBalanceManager.addMinutes(22) → balance becomes 42 min
        5. Clear pendingSessionEnd, pendingActualMinutes, focusSessionId, focusStartTime
```

### Collision Path: Focus Starts During Active Earned Time

```
User has 20 min balance, apps UNLOCKED (10 min earned time session active, ~4 min remaining)
                │
User opens BuyTime app → taps "30 min" focus (mode loaded from preferences → "easy")
                │
                ▼
        startFocusSession(minutes: 30, mode: "easy")
        ─────────────────────────────────────────────
        1. Detect earnedTimeEventActive == true
        2. center.stopMonitoring([earnedTimeActivityName])
        3. SharedData.earnedTimeEventActive = false
           remainingEarnedTimeMinutes stays at 4 ← NOT cleared, used for resume
        4. applyRestrictions() ← RE-APPLIES shields (apps were unlocked)
        5. Proceed with normal focus start steps (sessionId, flags, schedule)
                │
                ▼
        Focus runs for 30 min → intervalDidEnd() fires
        ────────────────────────────────────────────────
        1. Clear focus flags
        2. Set pendingSessionEnd = true
        3. Check: earnedTimeEventActive = false AND remainingEarnedTimeMinutes = 4 → resume
        4. startEarnedTimeMonitoring(minutes: 4) ← apps UNLOCK, 4 one-min events registered
        5. User gets exactly 4 min of actual usage back, no tap needed
```

### User Cancels Focus Early

```
User in focus (15 min elapsed of 30 min session), wallet balance = 20 min
                │
User taps "End Focus Early" in HomeView
                │
                ▼
        endFocusSession(abandoned: true)
        ─────────────────────────────────
        1. center.stopMonitoring([focusSessionActivityName])
        2. SharedData.isFocusActive = false
        3. SharedData.focusEndTime = 0
        4. actualMinutes = Int((Date().now - focusStartTime) / 60) = 15

        5. ABANDON PENALTY (applied to wallet balance, not paused time):
           currentBalance = SharedData.earnedTimeMinutes  → 20 min
           if currentBalance > 0:
               newBalance = currentBalance / 2            → 10 min
               TimeBalanceManager.setMinutes(newBalance)
               Call PATCH /api/balance(availableMinutes: 10)  ← sync server
           else:
               no change (balance stays at 0)

        6. Call POST /api/sessions/abandon(sessionId) ← records failure, no reward
        7. Clear focusSessionId, focusStartTime
        8. Check: earnedTimeEventActive = false AND remainingEarnedTimeMinutes > 0 → resume
           (earned time is NOT penalised — it was already spent from wallet before focus)
        (Shields remain applied, normal spend shield is shown again)
```

> **Penalty scope:** Only the wallet balance (`earnedTimeMinutes`) is halved. The `remainingEarnedTimeMinutes` (time the user already paid for before focus started) is unaffected.

---

## SharedData Changes

Six new keys needed. Four are for focus state, one tracks earned time remaining (doubles as the pause/resume value), and two bridge the background-extension → main-app API handoff.

| Key | Type | Purpose |
|-----|------|---------|
| `isFocusActive` | `Bool` | True while a focus session is running |
| `focusEndTime` | `Double` (TimeInterval) | Timestamp when focus ends; 0 = not set |
| `focusSessionId` | `String` | Backend UUID from `POST /api/sessions/start` |
| `focusStartTime` | `Double` (TimeInterval) | When focus started; used to compute `actualDurationMinutes` for the API |
| `remainingEarnedTimeMinutes` | `Int` | Decremented by 1 each time a one-minute DeviceActivity event fires. When `earnedTimeEventActive = true` it is the live session counter. When `earnedTimeEventActive = false` and value is > 0, it is the paused amount waiting to resume after focus ends. 0 = nothing active or paused. Repurposes existing `currentEventTimeLeft` key |
| `pendingSessionEnd` | `Bool` | Set by the extension when focus ends in background; main app calls `POST /api/sessions/end` on next foreground then clears it |
| `pendingActualMinutes` | `Int` | How many minutes the focus session actually ran. Set alongside `pendingSessionEnd`. Sent to `POST /api/sessions/end` so the server computes the reward. Unrelated to earned time — this is focus session duration |

> `isFocusActive` is checked alongside `focusEndTime` in every consumer. The date is the authoritative truth:
> ```swift
> var isFocusCurrentlyActive: Bool {
>     guard SharedData.isFocusActive else { return false }
>     let end = SharedData.focusEndTime
>     guard end > 0 else { return false }
>     return Date().timeIntervalSince1970 < end
> }
> ```
> This means even if `isFocusActive` is stale (not cleared by extension yet), the date comparison gives the correct answer.

---

## Files to Change

### 1. `SharedData.swift` — All Targets

Add new keys to the `Keys` enum and new computed properties.

```swift
// New keys
case isFocusActive = "isFocusActive"
case focusEndTime = "focusEndTime"
case focusSessionId = "focusSessionId"
case focusStartTime = "focusStartTime"
case remainingEarnedTimeMinutes = "currentEventTimeLeft"  // repurpose existing key
case pendingSessionEnd = "pendingSessionEnd"
case pendingActualMinutes = "pendingActualMinutes"

// Computed properties
static var isFocusActive: Bool { get/set }
static var focusEndTime: Double { get/set }              // 0 = not set
static var focusSessionId: String { get/set }            // "" = not set
static var focusStartTime: Double { get/set }            // 0 = not set
static var remainingEarnedTimeMinutes: Int { get/set }   // 0 = nothing active or paused
static var pendingSessionEnd: Bool { get/set }
static var pendingActualMinutes: Int { get/set }

// Convenience: true if focus session is currently active (flag + date check)
static var isFocusCurrentlyActive: Bool {
    guard isFocusActive, focusEndTime > 0 else { return false }
    return Date().timeIntervalSince1970 < focusEndTime
}
```

---

### 2. `ManagedSettings.swift` — Main App + Extensions

Add focus activity name constant and two new methods.

```swift
static let focusSessionActivityName = DeviceActivityName("com.baalavignesh.buytime.focusSession")

func startFocusSession(minutes: Int, mode: String) async throws {
    // Guard 1: apps selected
    // Guard 2: not already in focus
    // Guard 3: if earnedTimeEventActive →
    //   center.stopMonitoring([earnedTimeActivityName])
    //   SharedData.earnedTimeEventActive = false
    //   remainingEarnedTimeMinutes is NOT cleared — read on focus end to resume
    //   applyRestrictions() ← re-lock apps (they were unlocked)
    // Call POST /api/sessions/start(mode: mode, plannedDurationMinutes: minutes)
    // Store SharedData.focusSessionId, focusStartTime, isFocusActive, focusEndTime
    // Start DeviceActivitySchedule (now → now+minutes) for cleanup via intervalDidEnd
    // applyRestrictions() to ensure shields are on
}

func endFocusSession(abandoned: Bool) {
    // Stop DeviceActivitySchedule monitoring
    // Clear focus flags in SharedData
    // Compute actualMinutes from focusStartTime
    // If abandoned:
    //   Apply balance penalty (earnedTimeMinutes / 2 if > 0)
    //   Call PATCH /api/balance to sync halved balance
    //   Call POST /api/sessions/abandon
    // If remainingEarnedTimeMinutes > 0 (was paused when focus started):
    //   startEarnedTimeMonitoring(minutes: remainingEarnedTimeMinutes) ← resumes session
}
```

**Important:** `startEarnedTimeMonitoring(minutes:)` is updated to use the multi-event approach:
```swift
func startEarnedTimeMonitoring(minutes: Int) {
    // Guard: minutes > 0, apps selected
    removeRestriction()  // unlock apps

    SharedData.remainingEarnedTimeMinutes = minutes  // set the live counter

    // Register one DeviceActivityEvent per minute (e.g. 10 min → 10 events)
    var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
    for minute in 1...minutes {
        let name = DeviceActivityEvent.Name("buytime.earnedTime.m\(minute)")
        events[name] = DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens,
            threshold: DateComponents(minute: minute)
        )
    }

    // Single startMonitoring call — no chaining, no restarts
    try center.startMonitoring(earnedTimeActivityName, during: schedule, events: events)
    SharedData.earnedTimeEventActive = true
}
```

---

### 3. `DeviceActivityMonitorExtension.swift` — Monitor Extension

Two callbacks need updating:

**`eventDidReachThreshold` — earned time counter (multi-event approach)**

```swift
override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
    super.eventDidReachThreshold(event, activity: activity)

    if activity == AppBlockUtils.earnedTimeActivityName {
        SharedData.remainingEarnedTimeMinutes -= 1

        if SharedData.remainingEarnedTimeMinutes <= 0 {
            // Final event — all earned time consumed, lock apps
            SharedData.earnedTimeEventActive = false
            SharedData.remainingEarnedTimeMinutes = 0
            reapplyRestrictions()
            DeviceActivityCenter().stopMonitoring([activity])
        }
        // Intermediate events: do nothing to shields — apps stay open
        // No stop/restart needed; remaining events continue firing as usage accumulates
    }
}
```

**`intervalDidEnd` — focus session completion**

```swift
override func intervalDidEnd(for activity: DeviceActivityName) {
    super.intervalDidEnd(for: activity)

    if activity == AppBlockUtils.focusSessionActivityName {
        // 1. Compute actual duration
        let startTime = SharedData.focusStartTime
        let actualMinutes = startTime > 0
            ? max(1, Int((Date().timeIntervalSince1970 - startTime) / 60))
            : SharedData.pendingActualMinutes

        // 2. Signal main app to call API (extension cannot make Clerk-auth'd calls)
        SharedData.pendingSessionEnd = true
        SharedData.pendingActualMinutes = actualMinutes

        // 3. Clear focus flags
        SharedData.isFocusActive = false
        SharedData.focusEndTime = 0

        // 4. Resume earned time if it was paused when focus started
        //    earnedTimeEventActive = false AND remainingEarnedTimeMinutes > 0 means paused
        let remaining = SharedData.remainingEarnedTimeMinutes
        if remaining > 0 {
            AppBlockUtils().startEarnedTimeMonitoring(minutes: remaining)
            // startEarnedTimeMonitoring sets remainingEarnedTimeMinutes = remaining and
            // calls removeRestriction() internally → apps unlock
        }
        // If remaining = 0, shields stay applied (apps remain blocked)
    }
}
```

---

### 4. `ShieldConfigurationExtension.swift` — Shield Extension

Branch on `SharedData.isFocusCurrentlyActive` before building config.

```swift
private func buildConfig(appName: String?) -> ShieldConfiguration {
    if SharedData.isFocusCurrentlyActive {
        return buildFocusConfig(appName: appName)
    } else {
        return buildNormalConfig(appName: appName)  // existing logic
    }
}

private func buildFocusConfig(appName: String?) -> ShieldConfiguration {
    let displayName = appName ?? "This app"
    let remaining = SharedData.focusEndTime - Date().timeIntervalSince1970
    let remainingMin = max(0, Int(remaining / 60))
    let remainingDisplay = remainingMin > 0 ? "\(remainingMin) min left" : "Almost done"

    return ShieldConfiguration(
        backgroundColor: UIColor.systemIndigo,
        icon: UIImage(named: "dark_logo"),
        title: ShieldConfiguration.Label(text: "Focus Mode Active", color: .white),
        subtitle: ShieldConfiguration.Label(
            text: "\(displayName) is blocked\n\(remainingDisplay)",
            color: UIColor(white: 1, alpha: 0.7)
        ),
        primaryButtonLabel: ShieldConfiguration.Label(text: "Keep Focusing", color: .white),
        primaryButtonBackgroundColor: UIColor(white: 1, alpha: 0.15),
        secondaryButtonLabel: ShieldConfiguration.Label(text: "Close", color: .white)
    )
}
```

Visual distinction: focus shield uses `systemIndigo` background vs the normal `black`. This makes it immediately obvious the user is in focus mode.

---

### 5. `ShieldActionExtension.swift` — Shield Action Extension

Add focus check at the top of `handleTemporaryAccess`.

```swift
private func handleTemporaryAccess(completionHandler: @escaping (ShieldActionResponse) -> Void) {
    // Focus takes priority — spending is blocked during focus sessions
    if SharedData.isFocusCurrentlyActive {
        completionHandler(.close)
        return
    }

    // ... existing spend logic unchanged ...
}
```

This is the enforcement point. Even if the shield UI somehow showed the spend button, this guard blocks the action.

---

### 6. `HomeView.swift` + `FocusViewModel.swift` + `FocusSessionSheet.swift` — Main App

**Architecture:** HomeView owns three `@StateObject` ViewModels:
- `BalanceViewModel` — wallet balance
- `PreferencesViewModel` — focus prefs
- `FocusViewModel(balanceVM:, prefsVM:)` — session lifecycle, injected with the other two

HomeView only holds UI state (sheet/alert booleans, `customMinutes`). All business logic lives in `FocusViewModel`.

**Focus start flow:** Preset buttons (15m/30m/1hr) or custom picker → `FocusSessionSheet` confirmation → swipe-to-start slider → `focusVM.startFocusSession(minutes:)`.

`FocusSessionSheet` is a confirmation sheet that shows duration, mode (from `PreferencesViewModel`), estimated reward, and end time. It uses a `SwipeToStartSlider` (80% threshold) with haptic feedback.

Two UI states:

**State A — No active focus:**

```
┌─────────────────────────────────────┐
│  [BuyTime card — balance display]   │
│                                     │
│  Start Focus Session                │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌────┐ │
│  │ 15m  │ │ 30m  │ │ 1hr  │ │ ⚙️ │ │  ← custom opens wheel picker
│  └──────┘ └──────┘ └──────┘ └────┘ │
│                                     │
│  Tap preset/custom → FocusSession-  │
│  Sheet (confirmation) → swipe to    │
│  start slider → session begins      │
└─────────────────────────────────────┘
```

Custom wheel picker → "Continue" → FocusSessionSheet confirmation → swipe to start.

Mode is **not shown as a selector** — it is loaded from `PreferencesViewModel` (cached from `GET /api/preferences`). Displayed read-only in the confirmation sheet.

**State B — Focus active:**

```
┌─────────────────────────────────────┐
│  Focus Session Active               │
│                                     │
│         ┌─────────────┐             │
│         │   23:41     │  countdown  │
│         └─────────────┘             │
│                                     │
│  Mode: easy  •  Reward: ~18 min     │
│                                     │
│  [ End Focus Early ]  ← destructive │
└─────────────────────────────────────┘
```

**Implementation notes:**
- Countdown uses `focusVM.tick()` called by a 1-second `Timer` via `.onReceive`
- On `scenePhase → .active`: `focusVM.checkPendingSessionEnd()` handles reward credit + API, `focusVM.drainSyncQueue()` retries failed ops
- "End Focus Early" calls `focusVM.abandonFocusSession()` which applies the balance penalty then queues `POST /api/sessions/abandon`

---

### 7. `BuyTimeApp.swift` — App Launch Recovery

On every app launch, recover any in-progress or just-completed state:

```swift
// In .task block after clerk.load()
func recoverFocusState() async {
    if SharedData.pendingSessionEnd {
        // Focus ended in background, extension left us the result
        let sessionId = SharedData.focusSessionId
        let actualMinutes = SharedData.pendingActualMinutes
        if !sessionId.isEmpty && actualMinutes > 0 {
            let result = try? await BuyTimeAPI.shared.endSession(
                sessionId: sessionId,
                actualDurationMinutes: actualMinutes
            )
            if let reward = result?.session.rewardMinutes {
                TimeBalanceManager.shared.addMinutes(reward)
            }
        }
        // Clear all pending state
        SharedData.pendingSessionEnd = false
        SharedData.pendingActualMinutes = 0
        SharedData.focusSessionId = ""
        SharedData.focusStartTime = 0
    }

    // Stale focus flag cleanup (focus expired while app was closed, extension didn't run)
    if SharedData.isFocusActive && !SharedData.isFocusCurrentlyActive {
        SharedData.isFocusActive = false
        SharedData.focusEndTime = 0
        // Also check if we missed a session end — fall back to GET /api/sessions/current
    }
}
```

---

## Edge Cases

| Scenario | Handling |
|----------|----------|
| **Start focus with no apps selected** | Guard in `startFocusSession` — return early, show error in UI |
| **Start focus while already in focus** | Guard — second tap is ignored, UI shows active session |
| **App crashes mid-focus** | On relaunch: `GET /api/sessions/current` → if active session found, reconcile; `isFocusCurrentlyActive` check restores UI |
| **Device reboot mid-focus** | UserDefaults persists. `isFocusActive = true`, `focusEndTime` still set. DeviceActivitySchedule may or may not survive reboot (system-dependent). Date check on shield render is always correct regardless |
| **Focus ends exactly at midnight** | DateComponents schedule edge case for the DeviceActivity cleanup. The date-comparison in shields is unaffected. If `intervalDidEnd` doesn't fire, `pendingSessionEnd` won't be set → on foreground, stale flag cleanup runs and falls back to `GET /api/sessions/current` |
| **User changes apps selection during focus** | New selection is saved to SharedData. DeviceActivity schedule for focus doesn't track apps, so no conflict. After focus, shields re-apply using the new selection |
| **Cancel focus with paused earned time** | `endFocusSession(abandoned: true)` still resumes earned time — `remainingEarnedTimeMinutes > 0` check triggers the resume. Earned time is NOT penalised (it was already spent from wallet before focus) |
| **Abandon with 0 balance** | Penalty skipped entirely — no change to balance, just call `POST /api/sessions/abandon` |
| **Abandon with 1 min balance** | `1 / 2 = 0` (integer division) — balance goes to 0. No negative values |
| **Paused earned time is 0 when focus ends** | `remainingEarnedTimeMinutes = 0` → nothing to resume. Earned time was fully consumed before focus started |
| **API call fails on session end** | Retry on next foreground via `pendingSessionEnd` flag — it stays true until cleared by a successful API call |
| **Backend returns 404 on session end** | Session was likely orphaned (e.g. server restart). Clear local state, don't credit reward |
| **Two rapid focus starts** | Second start is guarded by `isFocusCurrentlyActive` check — ignored |
| **earnedTimeEventActive when focusEndTime passes** | If somehow both are active, date checks are independent. `isFocusCurrentlyActive` returns false once time passes, normal spend shield shows |

---

## API Calls Summary

| Action | Endpoint | Called From |
|--------|----------|-------------|
| Start focus | `POST /api/sessions/start` | `startFocusSession()` in main app |
| Natural completion | `POST /api/sessions/end` | `BuyTimeApp.recoverFocusState()` on foreground |
| User abandons | `POST /api/sessions/abandon` | `endFocusSession(abandoned: true)` in main app |
| Orphan recovery | `GET /api/sessions/current` | App launch recovery |

Extensions **do not** make API calls — they write to SharedData and the main app handles all network communication.

---

## Implementation Checklist

### Phase 1: SharedData
- [ ] Add 6 new keys to `Keys` enum
- [ ] Add computed properties for all new keys
- [ ] Add `isFocusCurrentlyActive` convenience computed property

### Phase 2: AppBlockUtils
- [ ] Add `focusSessionActivityName` constant
- [ ] Add `startFocusSession(minutes:mode:)` — guards, stop earned time monitoring if active (leave `remainingEarnedTimeMinutes` intact), SharedData writes, DeviceActivity schedule, API call
- [ ] Add `endFocusSession(abandoned:)` — stop schedule, balance penalty if abandoned, API calls, resume earned time if `remainingEarnedTimeMinutes > 0`
- [ ] Update `startEarnedTimeMonitoring(minutes:)` — set `remainingEarnedTimeMinutes = minutes`, register N events (one per minute) in a single `startMonitoring` call

### Phase 3: DeviceActivityMonitorExtension
- [ ] Update `eventDidReachThreshold` — decrement `remainingEarnedTimeMinutes`; only call `reapplyRestrictions` when counter hits 0
- [ ] Implement `intervalDidEnd` — handle focus completion, set pending flags, resume paused earned time using exact counter

### Phase 4: Shield Extensions
- [ ] `ShieldConfigurationExtension`: add `buildFocusConfig()`, branch in `buildConfig()`
- [ ] `ShieldActionExtension`: add focus guard in `handleTemporaryAccess()`

### Phase 5: HomeView
- [ ] Add preset duration chips (15 min, 30 min, 1 hr, Custom)
- [ ] Custom option: wheel picker sheet (1–480 min range)
- [ ] On session start: fetch mode from `PreferencesViewModel` (no UI mode selector)
- [ ] Add active focus state: countdown timer + End Focus button
- [ ] Add earned time remaining display (from `remainingEarnedTimeMinutes`)
- [ ] Handle `scenePhase → .active` cleanup and pending session end detection
- [ ] "End Focus Early": show confirmation alert explaining the half-balance penalty before proceeding

### Phase 6: BuyTimeApp
- [ ] Add `recoverFocusState()` called on launch after `clerk.load()`

### Phase 7: Variables.md
- [ ] Document all 8 new SharedData keys

---

## Variables.md Additions

```
isFocusActive
Bool. True while a focus session is running. Always checked alongside focusEndTime.

focusEndTime
Double (TimeInterval since 1970). Timestamp when the current focus session ends. 0 means not
set. Authoritative truth for whether focus is active — always compared with Date() rather than
relying on the flag alone.

focusSessionId
String. The backend UUID returned by POST /api/sessions/start. Used by the main app to call
sessions/end or sessions/abandon. Empty string means not set.

focusStartTime
Double (TimeInterval since 1970). When the current focus session started. Used to compute
actualDurationMinutes for the session end API call.

remainingEarnedTimeMinutes (currentEventTimeLeft key)
Int. Decremented by 1 each time a one-minute DeviceActivity event fires — counts actual
in-app screen-on time only.
- earnedTimeEventActive = true  → live session counter (ticking down as user uses apps)
- earnedTimeEventActive = false AND value > 0 → paused session waiting to resume after focus
- value = 0 → nothing active or paused
This single key replaces what would have been two separate keys (live counter + paused snapshot).

pendingSessionEnd
Bool. Set by DeviceActivityMonitorExtension when focus ends in background. Main app reads
this on next foreground and calls POST /api/sessions/end. Cleared after successful API call.

pendingActualMinutes
Int. How many minutes the focus session actually ran. Set alongside pendingSessionEnd by the
extension. Sent to POST /api/sessions/end so the server can compute rewardMinutes. This is
the focus session duration — completely unrelated to remainingEarnedTimeMinutes.
```

---

*Last Updated: March 2026*
*Status: Implemented — February 26, 2026*
*Feature: Focus Sessions v1*
*Architecture Update: March 2026 — Extracted FocusViewModel, added FocusSessionSheet with swipe-to-start*
