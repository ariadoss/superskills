---
name: swiftui-alarmkit
description: Schedule alarms and countdown timers in iOS apps using AlarmKit. Use when implementing alarm functionality, timer features, AlarmKit integration, snooze/stop controls, Dynamic Island alarm displays, or focus mode override. Requires iOS 18+.
metadata:
  author: rshankras
---

# AlarmKit

iOS 18+ framework for scheduling alarms and countdown timers with custom UI, Live Activities, and focus/silent mode override capabilities.

## When This Skill Activates

Use this skill when the user needs to:
- Implement alarm or timer functionality
- Reference AlarmKit, AlarmManager, or AlarmPresentation
- Create one-time, repeating, or countdown alarms
- Add snooze/stop controls
- Display content on Dynamic Island or Lock Screen
- Override Focus or silent mode

## Reference Structure

- **scheduling.md**: Authorization setup, alarm creation, management, state observation
- **presentation.md**: Alert/countdown/paused UI customization, buttons, tint colors
- **live-activities.md**: Widget integration, AlarmAttributes, Dynamic Island display

All APIs require **iOS 18 or later**.

## Critical Mistakes to Avoid

| # | Mistake | Correct Approach |
|---|---------|-----------------|
| 1 | Using `.authorizationStatus` | Use `.authorizationState` |
| 2 | Missing Info.plist entry | Add `NSAlarmKitUsageDescription` before requesting authorization |
| 3 | Schedule parameter with countdown timers | Timers use only `CountdownDuration` — no schedule parameter |
| 4 | No widget extension | Countdown and paused presentations require an `ActivityConfiguration(for: AlarmAttributes.self)` widget |
| 5 | Not persisting alarm UUIDs | Store alarm IDs for pause/resume/cancel operations |
| 6 | Not observing state changes | Subscribe to `alarmUpdates` async sequence for synchronization |

## Quick Start Pattern

```swift
import AlarmKit

// 1. Request authorization
let manager = AlarmManager.shared
guard await manager.requestAuthorization() == .authorized else { return }

// 2. Create an alarm
let alarm = try await manager.schedule(
    AlarmRequest(
        id: UUID(),
        schedule: .oneTime(date: targetDate),
        presentation: .alert
    )
)

// 3. Persist the alarm ID
UserDefaults.standard.set(alarm.id.uuidString, forKey: "savedAlarmId")

// 4. Observe state changes
for await update in manager.alarmUpdates {
    // Handle alarm state changes
}
```

## Validation Checklist

Before deploying:
- [ ] `NSAlarmKitUsageDescription` in Info.plist
- [ ] Authorization flow implemented and tested
- [ ] Using `.authorizationState` (not `.authorizationStatus`)
- [ ] Alarm UUIDs persisted
- [ ] `alarmUpdates` sequence observed
- [ ] Widget extension present (if countdown/paused UI needed)
- [ ] Error handling for all alarm operations
- [ ] Tested on real device (not simulator)
