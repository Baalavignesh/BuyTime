# Future Fixes & Improvements

> Deferred improvements identified during design review. None of these are blocking for the current phase.

---

## Preferences Caching

- [ ] **App foreground revalidation** — The stale-cache check only fires on `.onAppear`. If the user leaves the app open on `RewardModification` for >24h and returns, the view never re-triggers `.onAppear` and the cache won't revalidate. Hook into `scenePhase` changes (`.active`) to run the same TTL check.

- [ ] **Sign-out cache invalidation** — On sign-out, clear all `preferences_*` UserDefaults keys. Otherwise a second user on the same device (or the same user after re-login) will briefly see stale preferences before the background GET corrects them.

- [ ] **Offline / no-network fallback** — On first launch with an empty cache and no network, the loading indicator will hang indefinitely. Define a timeout (e.g. 10s) after which the ViewModel falls back to hardcoded defaults (`focusDurationMinutes: 25`, `focusMode: "easy"`) and marks the cache as dirty so the next available network attempt fetches real data.

---

## API & Networking

- [ ] **`waitForUserCreation` exponential backoff** — The current implementation retries every 1s for 5 attempts (5s max). Clerk webhook delivery can exceed this. Switch to exponential backoff (1s, 2s, 4s, 8s, 16s) and consider raising `maxRetries` to 6–8. See `API_REFERENCE.md` for the current implementation.

- [ ] **JWT expiry mid-session** — No handling for a 401 response on authenticated requests after a long session. On receiving a 401, the client should attempt a silent token refresh via `Clerk.shared.session?.getToken(template:)` and retry the original request once before surfacing an auth error.

- [ ] **Planned endpoints stub in API_REFERENCE.md** — As Phase 3+ endpoints (session tracking, balance deduction, spending history) are built, add them to `API_REFERENCE.md` immediately. Consider adding a `## Planned` section now as a placeholder to avoid the doc going stale.

- [ ] **Client-side guard for empty `PATCH /api/preferences`** — `BuyTimeAPI.updatePreferences(focusDurationMinutes:focusMode:)` accepts both params as optional. If both are `nil`, the call will hit a 400. Add a guard at the call site (or inside the function) to no-op early if both values are nil.

---

## Balance Sync

- [ ] **Sign-out cache invalidation** — On sign-out, clear `balance_lastAPIValue` from `UserDefaults.standard`. Otherwise the delta model will compute an incorrect `pendingDelta` for the next user session or after re-login. Mirror the same pattern needed for `preferences_*` keys (see above).

- [ ] **Offline first-launch fallback** — If `lastAPIValue == -1` (never synced) and the device is offline, `onAppear()` fires a GET that fails silently. Balance shows 0. Define a timeout so the VM retries on the next `onForeground()` without the user needing to pull-to-refresh.

---

## Dead Code

- [ ] **`AppPickerView.swift`** — This view is never referenced anywhere. The app selection flow is handled inline in `ParentView`. Safe to delete once confirmed.

- [ ] **`SharedData.userBalanceValues`** — Property is defined and the `Keys.userBalanceValues` case exists, but neither is called anywhere in the codebase. If this was intended for the 8-8-8 focus/reward configuration, implement it; otherwise remove both the property and the key.

---

## Pre-Launch Checklist

- [ ] **Remove dev-only code** — Before shipping:
  - `BuyTimeApp.swift`: delete `printJWTToken()` and its call site (prints JWT to console)
  - `HomeView.swift`: remove the "Add 5 minutes" and "Set Time to 0" debug buttons
  - `BalanceViewModel.swift`: remove `debugSetMinutes()` or gate it behind `#if DEBUG`

- [ ] **Reset Clerk JWT token lifetime** — Token lifetime was increased for development/API testing. Before going to production, go to **Clerk Dashboard → Sessions** and reset the JWT token lifetime back to the default (**60 seconds**). A long-lived JWT is a security risk — if leaked, it can be used until it expires.
