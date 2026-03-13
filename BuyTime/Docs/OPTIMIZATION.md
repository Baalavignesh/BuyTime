# Optimization & Deprecation Fixes

This document tracks all code quality improvements made across the BuyTime codebase.

## Deprecated API Replacements

### `foregroundColor()` → `foregroundStyle()`
**Files:** ContentView, RewardModification, BuyTimeCard, ActiveFocusCard, FocusSessionSheet, TimePickerSheet, ButtonStyle
**Reason:** `foregroundColor()` is deprecated in modern SwiftUI. `foregroundStyle()` supports richer styling (gradients, hierarchical styles) and is the official replacement.

### `cornerRadius()` → `clipShape(.rect(cornerRadius:))`
**Files:** TimePickerSheet, ButtonStyle
**Reason:** `cornerRadius()` is deprecated. `clipShape(.rect(cornerRadius:))` is the modern equivalent and supports continuous corner curves.

### `overlay(Shape())` → `overlay { Shape() }`
**Files:** ContentView
**Reason:** The non-trailing-closure `overlay(_:alignment:)` variant is deprecated. The trailing closure form `overlay(alignment:content:)` is preferred.

### `UIImpactFeedbackGenerator` / `UINotificationFeedbackGenerator` → `sensoryFeedback()`
**Files:** FocusSessionSheet (SwipeToStartSlider)
**Reason:** UIKit haptic generators are the legacy approach. SwiftUI's `.sensoryFeedback()` modifier is declarative, tied to the view lifecycle, and doesn't require manual generator instantiation.

### `DispatchQueue.main.asyncAfter` → `Task.sleep(for:)`
**Files:** ParentViewModel (AuthorizationManager), FocusSessionSheet (SwipeToStartSlider)
**Reason:** GCD is legacy in Swift concurrency. `Task.sleep(for:)` integrates with structured concurrency and supports cancellation.

### `Task.sleep(nanoseconds:)` → `Task.sleep(for:)`
**Files:** BuyTimeAPI
**Reason:** The nanoseconds variant is error-prone. `Task.sleep(for: .seconds(n))` is clearer and type-safe.

### `DateFormatter` → `Text(date, format:)`
**Files:** FocusSessionSheet
**Reason:** Creating `DateFormatter` instances in view methods is wasteful. SwiftUI's built-in date formatting is cached and locale-aware.

### `.navigationBarTitle()` usage note
**Files:** SettingsView (deferred)
**Reason:** `.navigationBarTitle()` is deprecated in favor of `.navigationTitle()`.

## Dead Code Removal

### `AppPickerView.swift` — deleted
**Reason:** Entirely unused. The button action was commented out. `FamilyActivityPicker` is used directly in ParentView and SettingsView.

### `Account` and `Support` structs in SettingsModel — removed
**Reason:** Neither struct was referenced anywhere in the codebase. Only `legalList` is used (from SettingsView).

### `printJWTToken()` — guarded with `#if DEBUG`
**Reason:** Was running on every launch including production builds. Dev-only code must be compile-time excluded.

### Empty DeviceActivityMonitor overrides — removed
**Reason:** `intervalWillStartWarning`, `intervalWillEndWarning`, and `eventWillReachThresholdWarning` only called `super` with no custom logic. Unnecessary overrides.

### `import Combine` — kept where required by `ObservableObject`
**Note:** `import Combine` is required in any file using `ObservableObject`, `@Published`, `@StateObject`, or `.onReceive` with a Combine publisher. SwiftUI no longer re-exports Combine automatically. Files using these APIs must explicitly `import Combine`.

### `import Foundation` — removed where redundant
**Files:** ButtonStyle, PreferencesViewModel
**Reason:** `import SwiftUI` implicitly imports Foundation.

### Commented-out code — removed
**Files:** HomeView (commented `selectedTab` binding)
**Reason:** Dead commented code adds noise. Git history preserves it if needed.

## Repetitive Code Consolidation

### `formatDuration()` — centralized into `Utilities/FormatUtils.swift`
**Files affected:** FocusSessionSheet, TimePickerSheet (SettingsView deferred)
**Reason:** Identical function duplicated in 3+ files. Single source of truth prevents drift and reduces maintenance.

### `reapplyRestrictions()` in DeviceActivityMonitorExtension — now calls `AppBlockUtils`
**Reason:** The extension had a hand-rolled copy of the same shield-application logic already in `AppBlockUtils.applyRestrictions()`. Uses the shared implementation now (with `clearAllSettings()` before).

### Sync operation enqueue in FocusViewModel — extracted helper
**Reason:** The same `SyncOperation(.start, ...)` construction was duplicated in two catch blocks. Extracted to `enqueueStartOp()`.

## Safety Fixes

### `URL(string:)!` force unwrap → `guard let` with thrown error
**Files:** BuyTimeAPI
**Reason:** Force unwrapping crashes on malformed URLs. Throwing `APIError.badRequest` is recoverable.

### `@unknown default: fatalError()` → `completionHandler(.close)`
**Files:** ShieldActionExtension
**Reason:** `fatalError()` crashes the extension process on future OS versions that add new shield actions. Graceful fallback is safer.

### `Date()` → `Date.now`
**Files:** BuyTimeApp
**Reason:** `Date.now` is the preferred Swift idiom for clarity.

### `if let body = body` → `if let body` shorthand
**Files:** BuyTimeAPI
**Reason:** Modern Swift supports the shorter `if let` rebinding syntax.

## Unnecessary Code Removal

### `UserDefaults.synchronize()` calls removed
**Files:** SharedData
**Reason:** Apple's documentation explicitly states `synchronize()` is unnecessary — UserDefaults auto-persists. The calls waste I/O.

### Redundant nested `VStack` in ContentView sign-in screen
**Reason:** Outer `VStack` wrapping an inner `VStack` with identical alignment served no purpose.

### `PermissionView` free function → proper `View` struct
**Files:** ParentView → new PermissionView.swift
**Reason:** SwiftUI best practice is to extract views into structs for proper identity tracking and performance. Free `@ViewBuilder` functions don't get the same optimizations.

### Duplicate `PermissionView` branches collapsed
**Files:** ParentView
**Reason:** Both `.notDetermined` and the `else` (denied) branches rendered the identical `PermissionView`. Collapsed into a single `else` branch.

## Performance

### `Timer.publish` moved to stored property
**Files:** HomeView
**Reason:** Creating `Timer.publish(...).autoconnect()` inline in `.onReceive` inside `body` creates a new publisher reference on every view evaluation. Storing it as a `let` property ensures a single stable publisher.

### `onTapGesture` → `Button` for interactive elements
**Files:** ContentView (sign-in images), HomeView (ActiveFocusCard tap)
**Reason:** `Button` provides built-in accessibility traits (VoiceOver announces it as a button), proper hit testing, and keyboard/switch control support. `onTapGesture` is invisible to assistive technologies.

## Accessibility

### Icon-only button in ActiveFocusCard — added text label
**Reason:** VoiceOver cannot describe icon-only buttons. Adding a text label (with `.labelStyle(.iconOnly)` for visual appearance) makes the button accessible.
