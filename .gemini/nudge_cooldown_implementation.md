# Nudge Cooldown System Implementation

## Overview
Implemented a 1-hour cooldown system for nudges in the group leaderboard that persists across app restarts and devices.

## Key Features
- **1-hour cooldown**: After sending a nudge to a member, the user must wait 1 hour before nudging that same member again
- **Visual feedback**: During cooldown, the nudge button becomes disabled and gray
- **Countdown display**: Shows remaining time (e.g., "45m" or "30s") until the nudge becomes available again
- **Persistent**: Cooldown data is stored in Firestore, so it persists across app restarts and syncs across devices
- **Per-target tracking**: Each user-target pair has its own cooldown, so you can nudge different members independently

## Implementation Details

### 1. Backend (GroupService)
**File**: `lib/services/group_service.dart`

- **`sendNudge()`**: Enhanced to check cooldown before sending and record timestamp after success
  - Checks if a cooldown exists for the target user
  - Throws an error with remaining time if still on cooldown
  - Records the nudge timestamp in Firestore after successful send
  
- **`watchNudgeCooldown()`**: New stream method to monitor cooldown status
  - Returns a stream of the last nudge timestamp for a specific target
  - Automatically updates when cooldown data changes

### 2. Frontend (GroupLeaderboard Widget)
**File**: `lib/widgets/group_leaderboard.dart`

- **`_NudgeHandButton`**: Updated to support cooldown tracking
  - Added `groupId` and `targetUserId` parameters
  - Uses `StreamBuilder` to watch cooldown status in real-time
  - Calculates remaining time and updates UI accordingly
  - Schedules automatic rebuild when cooldown expires
  - Shows countdown timer (minutes or seconds) during cooldown
  - Button becomes disabled and gray during cooldown

### 3. Security Rules
**File**: `firestore.rules`

Added rules for the `nudgeCooldowns` subcollection:
```
match /users/{userId}/nudgeCooldowns/{cooldownId} {
  allow read, write: if isOwner(userId);
}
```

## Data Structure
Cooldown documents are stored at:
```
/users/{userId}/nudgeCooldowns/{groupId-targetUserId}
```

Each document contains:
- `lastNudgeAt`: Timestamp of when the nudge was sent
- `groupId`: The group where the nudge was sent
- `targetUserId`: The user who was nudged

## User Experience
1. **Normal state**: Nudge button shows hand icon and is enabled
2. **Sending**: Shows loading spinner
3. **Cooldown active**: 
   - Button becomes gray and disabled
   - Shows remaining time (e.g., "45m" or "30s")
   - Automatically updates as time passes
4. **Cooldown expired**: Button returns to normal state

## Error Handling
- If user tries to nudge during cooldown, shows error: "Please wait X more minute(s) before nudging this member again"
- All existing validation (allowsNudges, canReceiveNudges, isCurrentUser) still applies
- Cooldown is only recorded after successful nudge send

## Cross-Device Sync
Since cooldown data is stored in Firestore:
- Changes sync automatically across all user's devices
- If user sends a nudge on device A, device B will immediately see the cooldown
- No local storage needed - everything is cloud-based
