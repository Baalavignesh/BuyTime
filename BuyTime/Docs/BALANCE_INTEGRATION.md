# Balance API Integration Plan

> **Status:** Pending implementation approval
> **Scope:** Integrate `GET /api/balance` and `PATCH /api/balance` with `HomeView`, with offline-first,
> multi-device safe, delta-based sync.

---

## Goals

1. Display the user's `availableMinutes` in `HomeView` via `BuyTimeCard`
2. Offline-first: local `SharedData.earnedTimeMinutes` is always displayed — no blocking network call
3. Multi-device safe: sync uses a delta model, not absolute overwrite, so laptop/other device deductions are preserved
4. API never called on every screen visit — only on first launch and pull-to-refresh (explicit user intent)
5. Silent background sync when extension-made changes are detected on foreground return

---

## Source of Truth Model

```
               [Shield Extension]        [Focus Session (future)]
                      │                          │
                      │ deduct                   │ earn
                      ▼                          ▼
         SharedData.earnedTimeMinutes   ◄─────────────────────
              (AppGroup UserDefaults)        BalanceViewModel.addMinutes()
                      │
                      │ displayed instantly (no wait)
                      ▼
                  HomeView
                      │
                      │ on foreground / pull-to-refresh
                      ▼
               BalanceViewModel
                 (delta sync)
                      │
               GET /api/balance
               PATCH /api/balance
                      ▼
                 Backend API
              (aggregates all devices)
```

**Key principle:** `SharedData.earnedTimeMinutes` is the local truth. The API is the aggregate truth
across all devices. They are reconciled via delta, not absolute overwrite.

---

## Delta Sync Model

### Why delta, not absolute?

If the iPhone has a local balance of 90 (after earning 30, spending 10 from base of 70), and
simultaneously the user spent 20 minutes on their laptop (API is now 50), a naive `PATCH 90`
would erase the laptop's deduction. Instead:

```
pendingDelta = SharedData.earnedTimeMinutes - lastAPIValue

On sync:
  GET /api/balance  → apiBalance (e.g. 50)
  newAbsolute = apiBalance + pendingDelta  (e.g. 50 + 20 = 70)
  PATCH newAbsolute
```

### `lastAPIValue` — the only thing we track

Stored in `UserDefaults.standard` (main app only, not AppGroup).

| Stored Value | Type | Meaning |
|---|---|---|
| `balance_lastAPIValue` | `Int` | Last `availableMinutes` value confirmed from the API. `-1` = never synced. |

`pendingDelta` is always **computed on the fly**: `SharedData.earnedTimeMinutes - lastAPIValue`
No need to persist it separately — it's always derivable.

---

## When API is Called

| Scenario | API Calls | User sees |
|---|---|---|
| First launch (`lastAPIValue == -1`) | `GET` | Brief skeleton/loading in card |
| Normal screen visit | **None** | Instant render from local |
| Foreground return, delta != 0 | Background `GET` → `PATCH` | Nothing (silent) |
| Foreground return, delta == 0 | **None** | Nothing |
| Pull-to-refresh | `GET` always + `PATCH` if delta != 0 | Refresh spinner |
| Offline on first launch | `GET` fails silently | Shows 0 (SharedData default) |
| Focus session completes (future) | Background sync after `addMinutes()` | Instant balance update |

---

## Files to Change

### 1. `Services/BuyTimeAPI.swift` — Add balance methods

Add `Balance` response struct and two methods:

```swift
struct Balance: Decodable {
    let availableMinutes: Int
    let currentStreakDays: Int
    let lastSessionDate: String?
    let updatedAt: String
    let today: TodayStats?

    struct TodayStats: Decodable {
        let earnedMinutes: Int
        let spentMinutes: Int
        let sessionsCompleted: Int
        let sessionsFailed: Int
    }
}

/// GET /api/balance
func getBalance() async throws -> Balance

/// PATCH /api/balance
func updateBalance(availableMinutes: Int) async throws -> Balance
```

### 2. `ViewModels/BalanceViewModel.swift` — Create (new file)

```swift
@MainActor
class BalanceViewModel: ObservableObject {

    // MARK: - Published
    @Published private(set) var availableMinutes: Int = 0
    @Published var isRefreshing: Bool = false

    // MARK: - UserDefaults
    // Key: "balance_lastAPIValue", Int, default -1 (never synced)

    // MARK: - Computed
    // pendingDelta: Int  →  SharedData.earnedTimeMinutes - lastAPIValue

    // MARK: - Methods
    func onAppear()            // First launch only: background GET to seed local
    func onForeground()        // If delta != 0: silent background sync
    func refresh() async       // Pull-to-refresh: GET always, PATCH if delta != 0
    func addMinutes(_ n: Int)  // Focus session reward: update local + sync
}
```

#### `onAppear()` logic
```
if lastAPIValue == -1 (never synced):
    background GET /api/balance
    → SharedData.earnedTimeMinutes = api.availableMinutes
    → lastAPIValue = api.availableMinutes
    → availableMinutes = api.availableMinutes
else:
    do nothing (render from SharedData instantly)
```

#### `onForeground()` logic
```
availableMinutes = SharedData.earnedTimeMinutes   // pick up extension changes
let delta = availableMinutes - lastAPIValue
if delta != 0 AND lastAPIValue != -1:
    Task { await performSync(showSpinner: false) }
```

#### `refresh()` logic (pull-to-refresh)
```
isRefreshing = true
await performSync(showSpinner: true)
isRefreshing = false
```

#### `performSync(showSpinner:)` — shared internal method
```
let currentLocal = SharedData.earnedTimeMinutes
let delta = currentLocal - lastAPIValue

GET /api/balance → apiBalance

if delta != 0:
    let newAbsolute = max(0, apiBalance.availableMinutes + delta)
    PATCH newAbsolute → confirmed
    SharedData.earnedTimeMinutes = confirmed.availableMinutes
    lastAPIValue = confirmed.availableMinutes
else:
    // No local changes — accept server value (picks up other device changes)
    SharedData.earnedTimeMinutes = apiBalance.availableMinutes
    lastAPIValue = apiBalance.availableMinutes

availableMinutes = SharedData.earnedTimeMinutes

// Failures are swallowed silently.
// pendingDelta remains non-zero → will retry on next foreground.
```

#### `addMinutes(_ n:)` logic (for future focus sessions)
```
SharedData.earnedTimeMinutes += n
availableMinutes = SharedData.earnedTimeMinutes
Task { await performSync(showSpinner: false) }
```

### 3. `Views/HomeView.swift` — Update

Changes:
- Replace `@ObservedObject var timeManager = TimeBalanceManager.shared`
  with `@StateObject private var balanceVM = BalanceViewModel()`
- Wrap content in `ScrollView` to enable pull-to-refresh
- Add `.refreshable { await balanceVM.refresh() }`
- Wire `scenePhase` change to `.active` → `balanceVM.onForeground()`
- Wire `.onAppear` → `balanceVM.onAppear()`
- Pass `balanceVM.availableMinutes` to `BuyTimeCard`
- Debug buttons ("Add 5 minutes", "Set Time to 0") updated to use `balanceVM`

### 4. `Utilities/TimeBalanceManager.swift` — Delete

`TimeBalanceManager` is only used in `HomeView`. Extensions use `SharedData` directly and are
unaffected. `BalanceViewModel` fully replaces its role with better API-awareness.

---

## Utilities: Debounce & Cache — Decision

**Question:** Should debounce and cache logic be extracted into shared utilities?

**Decision: No — not yet.**

| Pattern | PreferencesViewModel | BalanceViewModel |
|---|---|---|
| Debounce (continuous input) | ✅ slider writes | ❌ not needed — balance changes are discrete events |
| TTL-based cache (`lastFetchedAt`, 24h) | ✅ | ❌ not needed — uses delta tracking, not TTL |
| UserDefaults get/set | ✅ | ✅ — 2 lines, not worth abstracting |

The two VMs use structurally different sync patterns. Abstracting now would mean building a utility
for one consumer. **Extract when a third ViewModel needs the same pattern** (rule of three).

**When to revisit:** If a `FocusSessionViewModel` or `StatsViewModel` needs debounced writes
or TTL caching, that's the right time to extract a `Debouncer` helper class. Leave a `// TODO: extract Debouncer when third consumer appears` comment in PreferencesViewModel as a marker.

---

## Error Handling

All API failures in `BalanceViewModel` are **silent**:
- No error banners shown to the user (balance already shows correctly from local)
- Failed PATCH leaves `pendingDelta` non-zero → retried on next foreground or pull-to-refresh
- Failed GET on pull-to-refresh: stop spinner, show no error (user can retry)

The only visible loading state is `isRefreshing` during pull-to-refresh.

---

## Edge Cases

| Case | Behaviour |
|---|---|
| App offline on first launch | GET fails silently, shows 0 (SharedData default). Retries on next foreground. |
| Extension spends time while app is foregrounded | Extension writes SharedData directly. BalanceViewModel won't detect it until next `onForeground()`. Acceptable — the extension's shield UI already shows the correct value. |
| Delta is negative (spent more than synced) | `max(0, apiBalance + delta)` prevents negative PATCH values |
| `lastAPIValue == -1` on foreground (never synced, offline first launch) | Skip sync — don't PATCH with a meaningless delta. Wait until first successful GET. |
| Two rapid foreground events | `performSync` is async; second call computes fresh delta from latest SharedData — safe. |

---

## What This Plan Does NOT Cover

- Focus session completion flow (future) — `addMinutes()` is stubbed and ready
- Streak / today stats display (future) — `Balance.today` struct is modelled, not yet shown in UI
- Laptop/web client implementation (future) — this plan makes iOS safe for it when it arrives

---

*Created: February 21, 2026*
*Phase: Balance API Integration*
