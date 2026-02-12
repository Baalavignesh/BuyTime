# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BuyTime is an iOS screen time management app that implements a "wallet-based" earned time system. Users earn minutes by focusing and can spend them to temporarily unlock blocked apps. The app uses Apple's FamilyControls, ManagedSettings, and DeviceActivity frameworks.

## Build & Run

This is an Xcode project. Open `BuyTime.xcodeproj` in Xcode to build and run.

**Targets:**
- **BuyTime** - Main app
- **BuyTimeDeviceActivityMonitor** - Background extension monitoring app usage
- **BuyTimeShield** - Custom shield UI when apps are blocked
- **BuyTimeShieldActionExtension** - Handles shield button interactions

All extensions require a physical device for testing (Screen Time APIs don't work in Simulator).

## Architecture

### Cross-Process Communication

The main app and three extensions communicate via AppGroup (`group.com.baalavignesh.buytime`):

```
Main App (UI) ←→ SharedData.swift (UserDefaults + AppGroup) ←→ Extensions
```

`SharedData.swift` has target membership in all four targets and provides shared access to:
- `blockedAppsSelection` - FamilyActivitySelection (JSON encoded)
- `earnedTimeMinutes` - Wallet balance
- `spendAmount` - Minutes deducted per spend action
- `userBalanceValues` - 8-8-8 focus/reward configuration

### Earned Time Flow

1. User taps "Spend X minutes" on shield → `ShieldActionExtension`
2. Extension deducts from balance via `TimeBalanceManager`
3. `AppBlockUtils.startEarnedTimeMonitoring(minutes:)` removes shields and starts DeviceActivityEvent
4. After threshold reached → `DeviceActivityMonitorExtension.eventDidReachThreshold()` reapplies shields

### Key Utilities

- **SharedData.swift** (`BuyTime/Utilities/`) - AppGroup UserDefaults wrapper, shared across all targets
- **ManagedSettings.swift** - `AppBlockUtils` class for applying/removing restrictions and monitoring
- **TimeBalanceManager.swift** - ObservableObject singleton for reactive balance updates

### Extension Responsibilities

| Extension | Purpose |
|-----------|---------|
| DeviceActivityMonitor | Background monitoring; fires `eventDidReachThreshold()` when earned time expires |
| ShieldConfiguration | Renders custom shield UI with wallet balance and spend button |
| ShieldAction | Handles "Spend X minutes" tap; deducts balance, starts monitoring |

### Authentication

Uses Clerk for OAuth (Google + Apple sign-in). Configuration is in `BuyTimeApp.swift`.

## Important Patterns

- Extensions cannot import the main app module; they read/write via `SharedData`
- `FamilyActivitySelection` must be JSON encoded/decoded for UserDefaults storage
- Shield UI reads balance directly from SharedData on each render (no persistent state)
- `DeviceActivityCenter` uses named schedules/events (`AppBlockUtils.earnedTimeScheduleName`)
