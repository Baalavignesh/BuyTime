//
//  PreferencesViewModel.swift
//  BuyTime
//
//  Manages focus duration and mode preferences with a write-through
//  UserDefaults cache and daily background revalidation from the API.
//
//  Created by Baalavignesh Arunachalam on 2/20/26.
//

import Foundation

import SwiftUI
internal import Combine

class PreferencesViewModel: ObservableObject {
    
    // MARK: - Published State
    @Published var focusDuration: Double = 30.0
    @Published var focusMode: Mode = .easy
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    // MARK: - Cache Keys
    private enum CacheKey {
        static let focusDurationMinutes = "preferences_focusDurationMinutes"
        static let focusMode            = "preferences_focusMode"
        static let lastFetchedAt        = "preferences_lastFetchedAt"
    }
    

    private let ttl: TimeInterval = 24 * 60 * 60 // 24 hours
    
    // MARK: - Snapshot (for rollback on PATCH failure)

    // Holds the last server-confirmed values. Set after a successful GET or PATCH.
    // On PATCH failure, the UI and cache are restored to these values.
    private var lastConfirmedDuration: Double = 30.0
    private var lastConfirmedMode: Mode = .easy

    // MARK: - Debounce
    private var debounceTask: Task<Void, Never>?

    // MARK: - Init
    init() {
        loadFromCache()
    }
    
    // MARK: - Cache Helpers
    private func loadFromCache() {
        let defaults = UserDefaults.standard
        if let stored = defaults.object(forKey: CacheKey.focusDurationMinutes) as? Int {
            focusDuration = Double(stored)
            lastConfirmedDuration = focusDuration
        }
        
        if let raw = defaults.string(forKey: CacheKey.focusMode),
            let mode = Mode(rawValue: raw) {
            focusMode = mode
            lastConfirmedMode = mode
        }
        
    }
    
    private func writeToCache(duration: Double, mode: Mode) {
            let defaults = UserDefaults.standard
            defaults.set(Int(duration), forKey: CacheKey.focusDurationMinutes)
            defaults.set(mode.rawValue, forKey: CacheKey.focusMode)
        }

        private func stampFetchedAt() {
            UserDefaults.standard.set(Date(), forKey: CacheKey.lastFetchedAt)
        }

        private var isCacheStale: Bool {
            guard let last = UserDefaults.standard.object(forKey: CacheKey.lastFetchedAt) as? Date else {
                return true  // never fetched → stale
            }
            return Date().timeIntervalSince(last) > ttl
        }

        private var isCacheEmpty: Bool {
            UserDefaults.standard.object(forKey: CacheKey.focusDurationMinutes) == nil
        }
    
    
    // MARK: - Load on Appear
    
    /// Call this from the view's `.onAppear`. Shows a loading spinner only on first
    /// launch (empty cache). All subsequent visits render from cache instantly.
    func onAppear() {
            guard isCacheStale else { return }
            Task { await backgroundFetch() }
        }

        private func backgroundFetch() async {
            let firstLoad = isCacheEmpty
            if firstLoad { isLoading = true }
            defer { if firstLoad { isLoading = false } }

            do {
                let prefs = try await BuyTimeAPI.shared.getPreferences()
                let fetchedDuration = Double(prefs.focusDurationMinutes)
                let fetchedMode = Mode(rawValue: prefs.focusMode) ?? .easy

                // Only update state if API returned something different (avoids UI flicker)
                if fetchedDuration != focusDuration || fetchedMode != focusMode {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        focusDuration = fetchedDuration
                        focusMode = fetchedMode
                    }
                }

                lastConfirmedDuration = focusDuration
                lastConfirmedMode = focusMode
                writeToCache(duration: focusDuration, mode: focusMode)
                stampFetchedAt()
            } catch {
                // Silent failure — cache remains valid.
            }
        }
    
    // MARK: - Write Path

        /// Call this whenever the user changes focusDuration or focusMode.
        /// Updates the cache immediately and fires a debounced PATCH after 500ms.
        func onPreferenceChanged() {
            writeToCache(duration: focusDuration, mode: focusMode)

            debounceTask?.cancel()
            debounceTask = Task {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                await patchPreferences()
            }
        }

        private func patchPreferences() async {
            let durationToSend = Int(focusDuration)
            let modeToSend = focusMode.rawValue

            // Snapshot the last confirmed state in case we need to roll back
            let previousDuration = lastConfirmedDuration
            let previousMode = lastConfirmedMode

            do {
                _ = try await BuyTimeAPI.shared.updatePreferences(
                    focusDurationMinutes: durationToSend,
                    focusMode: modeToSend
                )
                // Success — update confirmed snapshot
                lastConfirmedDuration = focusDuration
                lastConfirmedMode = focusMode
                errorMessage = nil
            } catch {
                // Failure — rollback cache and UI to last confirmed state
                focusDuration = previousDuration
                focusMode = previousMode
                writeToCache(duration: previousDuration, mode: previousMode)

                errorMessage = "Couldn't save preferences. Check your connection."

                // Auto-dismiss the error banner after 3 seconds
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    if errorMessage != nil { errorMessage = nil }
                }
            }
        }
    
}


