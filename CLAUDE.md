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

### ViewModels

Each ViewModel owns a single domain. Views compose them as needed.

| ViewModel | Domain | Used By |
|-----------|--------|---------|
| `BalanceViewModel` | Wallet balance sync (delta-based API sync) | HomeView, potentially other views |
| `PreferencesViewModel` | Focus duration/mode preferences (24h cached) | HomeView, RewardModification, FocusSessionSheet |
| `FocusViewModel` | Focus session lifecycle (start/abandon/pending/timer/sync queue) | HomeView |
| `ParentViewModel` | Parent view logic (onboarding, tab state) | ParentView |

`FocusViewModel` takes `BalanceViewModel` and `PreferencesViewModel` as `init` dependencies — it doesn't own them. HomeView creates all three as `@StateObject` and wires them together in its `init()`.

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

## Documentation Policy

When making **significant changes** to the codebase — such as modifying core logic, adding/removing features, changing architecture, updating APIs, or altering data flows — **you must update the relevant documentation** in `BuyTime/Docs/` if that folder exists.

**What counts as significant:**
- Changes to SharedData keys/properties → update `Variables.md`
- Changes to API endpoints or backend communication → update `API_REFERENCE.md`
- Changes to the earned time flow, wallet system, or extension logic → update `DEVICE_ACTIVITY_EVENT_PLAN_FINAL.md`
- New files, new extensions, or architectural changes → update the relevant doc or create a new one in `BuyTime/Docs/`

**What does NOT need doc updates:**
- UI-only tweaks (colors, layout, styling)
- Bug fixes that don't change behavior
- Refactors that don't change the public interface

## Design Context

### Users
Adults self-managing their screen time. They open the app with intentionality — either to start a focus session or check their balance. They want the experience to feel like a tool they respect, not a chore. The "wallet" metaphor reinforces ownership and discipline.

### Brand Personality
**Premium, minimal, calm.** BuyTime should feel like a luxury fintech card — confident and understated. No cheerleading, no gamification noise. The interface earns trust through restraint and craft.

### Aesthetic Direction
- **Primary references**: Apple Wallet (metallic card aesthetic, status-driven), Nothing Phone / Teenage Engineering (dot-matrix patterns, industrial minimalism, distinctive identity)
- **Anti-references**: Generic corporate SaaS, childish/cartoonish UI, cluttered dashboards, flat/boring screens
- **Theme**: Dark-first with glassmorphism. Premium surfaces with subtle depth — glows, blur, fine borders. Pixel/grid patterns as a signature texture (inspired by Nothing/TE aesthetic).
- **Color**: Primarily monochrome (black, white, grays) with system blue as the sole accent. Opacity layering over solid colors. No bright palettes.
- **Typography**: System SF with rounded variants for numbers, monospaced for balances. Generous letter-tracking on labels. Hierarchy through weight and size, not color.
- **Motion**: Fluid and organic (6s blob loops, spring animations), never jarring. Haptics reinforce key moments.

### Design Principles
1. **Restraint is luxury** — Every element must earn its place. White space is a feature, not a gap.
2. **Tactile and physical** — The card metaphor should feel real: metallic gradients, embossed textures, chip/NFC details. UI should feel like holding something.
3. **Distinctive, not decorative** — Pixel grids, dot patterns, and industrial details give BuyTime a recognizable identity without being ornamental.
4. **Calm confidence** — No anxiety-inducing countdowns or aggressive alerts. The UI should feel like a quiet, capable tool.
5. **Dark craft** — Dark mode is the canvas. Depth comes from subtle glows, blur layers, and fine 0.5pt borders — never from drop shadows or loud gradients.
