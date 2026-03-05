# BuyTime

A wallet-based screen time management app for iOS. Earn minutes by focusing, spend them to temporarily unlock blocked apps.

## Why BuyTime?

Most screen time apps feel punishing — you set limits, break them, and eventually uninstall. BuyTime flips the model: you **earn** time through focused work and **spend** it like currency. This makes managing screen time feel rewarding instead of restrictive.

## How It Works

1. **Sign in** with Google or Apple
2. **Select apps** to block (Instagram, TikTok, YouTube, etc.)
3. **Configure** your focus duration and reward mode
4. **Focus** for your set duration to earn minutes
5. **Spend** earned minutes from the shield screen to temporarily unlock apps
6. Apps **re-lock** automatically once your earned time runs out

## Features

- **Wallet System** — Earned minutes are stored as a spendable balance
- **Custom Shield UI** — Blocked apps show your balance and a "Spend X minutes" button
- **Flexible Rewards** — Four difficulty modes control how much time you earn:
  - Fun (100%) · Easy (75%) · Medium (50%) · Hard (25%)
- **Focus/Reward Configuration** — Adjustable focus duration (15–60 min) with automatic reward calculation
- **Cloud Sync** — Balance syncs across sessions via a REST backend with delta-based updates
- **Offline-First** — Balance displays instantly from local state; API syncs in the background

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI |
| App Blocking | FamilyControls, ManagedSettings |
| Usage Monitoring | DeviceActivity (DeviceActivityEvent) |
| Auth | Clerk (Google + Apple OAuth) |
| Backend | REST API with JWT auth |
| State Sharing | AppGroup UserDefaults |

## Architecture

The project has four targets that communicate via an AppGroup:

```
┌──────────────┐     SharedData (AppGroup UserDefaults)     ┌──────────────────────────┐
│   Main App   │ ◄─────────────────────────────────────────► │ DeviceActivityMonitor    │
│  (UI + API)  │                                             │ (re-blocks after timeout) │
└──────────────┘                                             └──────────────────────────┘
       ▲                                                              ▲
       │                    ┌──────────────────┐                      │
       └────────────────────│   SharedData     │──────────────────────┘
                            │  (UserDefaults)  │
       ┌────────────────────│                  │──────────────────────┐
       ▼                    └──────────────────┘                      ▼
┌──────────────┐                                             ┌──────────────────────────┐
│ Shield UI    │                                             │ ShieldAction Extension   │
│ (blocked     │                                             │ (handles "Spend" tap,    │
│  app screen) │                                             │  deducts balance)        │
└──────────────┘                                             └──────────────────────────┘
```

### Key Components

| Component | Location | Purpose |
|-----------|----------|---------|
| `SharedData` | `Utilities/SharedData.swift` | AppGroup UserDefaults wrapper shared across all targets |
| `AppBlockUtils` | `Utilities/ManagedSettings.swift` | Applies/removes app restrictions and starts monitoring |
| `BalanceViewModel` | `ViewModels/BalanceViewModel.swift` | Balance management with delta-based API sync |
| `PreferencesViewModel` | `ViewModels/PreferencesViewModel.swift` | Focus/reward duration with debounced saves and caching |
| `BuyTimeAPI` | `Services/BuyTimeAPI.swift` | REST client with Clerk JWT authentication |

### Earned Time Flow

```
User taps "Spend X minutes" on shield
  → ShieldActionExtension deducts balance via SharedData
  → AppBlockUtils removes shields and starts DeviceActivityEvent
  → User uses unlocked apps
  → DeviceActivityMonitor fires eventDidReachThreshold()
  → Shields reapplied, apps blocked again
```

## Project Structure

```
BuyTime/
├── BuyTimeApp.swift              # Entry point, Clerk init
├── ContentView.swift             # Auth screen
├── Config/Secrets.swift          # API keys (gitignored)
├── Models/                       # Data models
├── ViewModels/                   # MVVM view models
├── Views/                        # SwiftUI views
├── Services/BuyTimeAPI.swift     # Backend API client
├── Utilities/
│   ├── SharedData.swift          # Cross-target state (AppGroup)
│   └── ManagedSettings.swift     # App blocking logic
└── Docs/                         # Internal documentation

BuyTimeDeviceActivityMonitor/     # Monitors usage, re-blocks apps
BuyTimeShield/                    # Custom blocked-app UI
BuyTimeShieldActionExtension/     # Handles "Spend" button tap
```

## Setup

1. Clone the repo
2. Open `BuyTime.xcodeproj` in Xcode
3. Create `BuyTime/Config/Secrets.swift` with your API keys:
   ```swift
   struct Secrets {
       static let clerkPublishableKey = "pk_test_..."
       static let apiBaseURL = "https://your-api.com"
   }
   ```
4. Configure your Apple Developer account with FamilyControls capability
5. Build and run on a **physical device** (Screen Time APIs don't work in Simulator)

## Requirements

- iOS 16.1+
- Xcode 15+
- Physical iPhone or iPad (Simulator not supported for Screen Time APIs)
- Apple Developer account with FamilyControls entitlement

## License

All rights reserved.
