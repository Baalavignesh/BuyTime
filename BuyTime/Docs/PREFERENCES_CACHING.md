# Preferences Caching Strategy

> How `focusDurationMinutes` and `focusMode` are stored, cached, and synced with the backend.

## Overview

User preferences (focus duration, difficulty mode) are persisted on the **backend API** (`/api/preferences`) and cached locally in **UserDefaults** using a write-through cache with daily revalidation.

**Goal**: The user never waits for a network call — preferences render instantly from cache on every visit.

## Architecture

```
┌──────────────────┐     instant read      ┌──────────────────┐
│  RewardModif.    │◄─────────────────────►│   UserDefaults   │
│  View            │                        │   (Cache)        │
└────────┬─────────┘                        └────────┬─────────┘
         │                                           │
         │  .onAppear                                │ write-through
         ▼                                           ▼
┌──────────────────┐     GET/PATCH          ┌──────────────────┐
│  Preferences     │──────────────────────►│   Backend API    │
│  ViewModel       │                        │  /api/preferences│
└──────────────────┘                        └──────────────────┘
```

## Data Flow

### Reading Preferences

1. **View appears** → ViewModel reads from `UserDefaults` cache → renders instantly
2. **Cache check**: If `lastFetchedAt` is missing or >24h old → background `GET /api/preferences`
3. **Background refresh**: If API returns different data, update cache silently (no UI flicker)

### Writing Preferences

1. User drags slider or taps difficulty mode
2. **Immediately**: Snapshot previous cache value, update `UserDefaults` cache + UI state
3. **Debounced 500ms**: `PATCH /api/preferences` fires after user stops adjusting
4. **On success**: No-op — cache is already correct
5. **On failure**:
   - Rollback `UserDefaults` and UI state to the snapshotted previous value
   - Surface a brief non-blocking error (e.g. a toast/banner — no modal)
   - Do **not** retry automatically; the next user interaction will trigger a fresh PATCH

## When API is Called

| Scenario | API Call | User Sees |
|---|---|---|
| First login (no cache) | `GET` | Brief loading indicator |
| Normal page visit (<24h) | **None** | Instant render |
| Stale cache (>24h) | Background `GET` | Instant render, silent refresh |
| User changes a value | `PATCH` (debounced) | Instant UI, API fires after 500ms; rolls back on failure |
| App reinstall / new device | `GET` | Brief loading (cache empty) |

## Cache Keys (UserDefaults)

| Key | Type | Description |
|---|---|---|
| `preferences_focusDurationMinutes` | `Int` | Focus duration in minutes (15–60) |
| `preferences_focusMode` | `String` | `fun`, `easy`, `medium`, or `hard` |
| `preferences_lastFetchedAt` | `Date` | Timestamp for 24h TTL check |

## API Endpoints Used

- **`GET /api/preferences`** → Returns `{ focusDurationMinutes, focusMode, updatedAt }`
- **`PATCH /api/preferences`** → Sends partial update, returns updated preferences

See [API_REFERENCE.md](./API_REFERENCE.md) for full details.

## Why Not Write-Only?

The daily revalidation (`GET` once per 24h) is a safety net for:
- App reinstall (empty cache)
- Login on a new device
- Future multi-platform support (web dashboard, etc.)

Cost: 1 lightweight request per day. Benefit: guaranteed correctness.

## Files Involved

| File | Role |
|---|---|
| `ViewModels/PreferencesViewModel.swift` | Cache logic, API calls, debouncing |
| `Services/BuyTimeAPI.swift` | `getPreferences()` / `updatePreferences()` |
| `Views/RewardModification.swift` | UI — binds to ViewModel |
