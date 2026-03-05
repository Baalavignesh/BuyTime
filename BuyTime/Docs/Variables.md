spendAmount

This is the amount that the user can spend when they are in the Shield UI

earnedTimeMinutes

User's total earned minutes wallet balance. Decremented when user spends time; incremented when a focus session completes with a reward.

userBalanceValues

Dictionary where user sets the 8-8-8 value for focus mode, reward time and the difficulty chosen.

currentEventTimeLeft (key for remainingEarnedTimeMinutes)

Tracks actual remaining in-app screen-on time for the current earned time session.
Decremented by 1 each time a one-minute DeviceActivity event fires.
- earnedTimeEventActive = true  → live counter (ticking down as user uses apps)
- earnedTimeEventActive = false AND value > 0 → paused session waiting to resume after focus ends
- value = 0 → nothing active or paused
This single key serves both the live counter and the pause/resume value.

isFocusActive

Bool. True while a focus session is running. Always checked alongside focusEndTime.
Even if this flag is stale, isFocusCurrentlyActive (which also checks the date) is authoritative.

focusEndTime

Double (TimeInterval since 1970). Timestamp when the current focus session ends.
0 = not set. This is the authoritative truth for whether focus is active — always compared
with Date() rather than relying on the flag alone.

focusSessionId

String. The backend UUID returned by POST /api/sessions/start. Used by the main app to call
sessions/end or sessions/abandon. Empty string means not set.

focusStartTime

Double (TimeInterval since 1970). When the current focus session started. Used to compute
actualDurationMinutes for the session end API call. 0 = not set.

focusMode

String (fun/easy/medium/hard). The mode of the current focus session. Stored so the active
focus UI can display mode and estimated reward on app recovery without an API call.

focusPlannedMinutes

Int. The planned duration of the current focus session. Used to display estimated reward in
the active focus UI and as a fallback for actualDurationMinutes if focusStartTime is 0.

pendingSessionEnd

Bool. Set by DeviceActivityMonitorExtension when focus ends naturally in the background.
Main app reads this on next foreground and calls POST /api/sessions/end.
Cleared after successful API call (or on 404 — orphaned session).

pendingActualMinutes

Int. How many minutes the focus session actually ran. Set alongside pendingSessionEnd by the
extension. Sent to POST /api/sessions/end so the server can compute rewardMinutes.
This is focus session duration — unrelated to remainingEarnedTimeMinutes (earned time counter).
