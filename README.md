# DayCue

Plan your day with weekly time blocks and gentle reminders from the macOS menu bar.

The menu bar icon follows your current time block's color. Hover to see its name and time, or open the menu to see what's next. DayCue uses your Mac's local time zone.

## Install

Requires macOS 14 or later. Open the DMG, drag **DayCue** to **Applications**, then launch it.

Allow notifications when prompted to receive time-block reminders. Enable **Launch at Login** from the menu bar if you want DayCue to start when you sign in. If approval is required, choose **Open Login Settings…**.

## Plan Your Day

1. Choose **Edit Schedule…** from the menu bar.
2. Select a date. Use the week arrows to browse or **Today** to return to today.
3. Choose **Add Time Block**, or click an existing block to edit it.
4. Set its name, time range, repeat days, and color, then choose **Save**.

Click the time range to open the picker. Scroll the hours and minutes, or click a center number to type. The start must be earlier than the end; only the end can be `24:00`. Blocks cannot overlap on the same weekday or cross midnight.

Changes apply from today across the block's repeat days, even when editing from a future date. Past dates keep their previous schedule and are read-only. Time outside your blocks appears as **Free Time**.

Closing Schedule keeps DayCue running in the menu bar. Use **Quit** to exit. See [Interaction](docs/interaction.md) for keyboard shortcuts and unsaved-change behavior.

## Reminders

DayCue sends silent macOS notifications when a time block starts or ends. Use **Notification Settings…** in the menu bar to adjust permissions and banner style. Focus and other system settings can silence reminders.

Missed reminders are not replayed after startup or wake. Editing your schedule does not trigger a reminder.

## Your Schedule

Your schedule stays on your Mac. To back it up, copy:

```text
~/Library/Application Support/io.github.zxhio.daycue/schedule.json
```

If DayCue cannot load your schedule, it keeps the original file and shows an error. Failed saves leave your draft available to retry.

## Build and Package

Building requires Swift 6 or later through a compatible Command Line Tools installation. Full Xcode is not required.

```sh
swift build
./scripts/build-app.sh
open dist/DayCue.app
```

To create a DMG:

```sh
./scripts/package.sh
```

Outputs are written to `dist/`. Use the packaged app for notifications and Launch at Login. Local builds are not notarized.
