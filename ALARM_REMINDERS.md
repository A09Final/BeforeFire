# Repeated iPhone Alarm alerts

The backend requests a Critical Alert every 30 seconds during an unresolved Alarm. The app registers its APNs token and installation ID automatically. Install both updates. The backend needs persistent `LIVE_ACTIVITY_STATE_FILE` storage and `ALARM_INTERRUPTION_LEVEL=critical`.

Snooze affects this iPhone only. The app and Lock Screen actions send the snooze deadline to the backend. The deadline uses Unix seconds. The change time uses Unix milliseconds. The app saves a pending change and retries it when registration refreshes. If the server cannot receive a change, it can continue to send alerts. A request already sent to APNs cannot be recalled.

The backend holds Alarm through Warning 1, Warning 2, and missing or stale data. A fresh, complete Normal measurement ends the session. Reminder pushes keep the same Alarm event ID. They do not start another Live Activity. When snooze expires, the server requests an alert on its next one-second check. It repeats every 30 seconds from that request. Each iPhone has its own deadline. APNs can still delay delivery.

The card uses its snooze deadline as the ActivityKit `staleDate`. When the system marks that content stale, the widget shows Active Alarm. This display change does not need the app to open or another push to arrive. The backend also sends an update when an ActivityKit update token is available. The app observes tokens again when registration refreshes and uploads the current token from Lock Screen actions.

## Sound changes

- `BeforeFire/Assets.xcassets/AlarmPreview.dataset/AlarmPreview.wav` is the 2.4-second source tone.
- `BeforeFire/Shared/AlarmFeedback/BeforeFireCriticalSiren.caf` repeats that tone 12 times, for 28.8 seconds.
- Both files use mono, 44.1 kHz, signed 16-bit PCM.
- Peak normalization increased the signal by 7.52 dB. The measured peak changed from 0.39966 to 0.94998 of full scale. No samples reached the clipping limit. The pulse timing did not change.
- The in-app player volume changed from 0.7 to 1.0. APNs Critical Alert volume remains 1.0.

These measurements describe the digital file. They do not measure the loudness of an iPhone speaker. APNs delivery and iOS sound controls still apply. The result does not guarantee continuous sound.

## Physical iPhone verification

1. Deploy the backend update and run the app update.
2. Allow notifications, Critical Alerts, and Live Activities. Link the test sensor and wait for Normal.
3. Close the app and lock the iPhone. Send one test Alarm.
4. Check that one Live Activity appears. Listen for the siren and at least two repeated alerts, with requests about 30 seconds apart.
5. Snooze from the card. Check that this phone stops receiving reminders after the server accepts the change. Another linked phone must keep its own state.
6. Wait past the snooze deadline. Check that reminders resume and the same card becomes active again.
7. Send Warning 1 or Warning 2. Check that Alarm remains active.
8. Send a newer, complete Normal reading. Check that the card ends and no further reminders arrive.

Unit tests and build checks do not replace this physical-device test.

Apple references: [notification sound requirements](https://developer.apple.com/documentation/usernotifications/unnotificationsound), [critical sound volume](https://developer.apple.com/documentation/usernotifications/unnotificationsound/criticalsoundnamed(_:withaudiovolume:)), [Live Activity intent execution](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities).

## Physical test observations (2026-11-18)

The project owner confirmed repeated sirens, stopped sound after pressing Snooze, and no Critical Alerts during snooze on the test iPhone. The owner reported a delay after snooze and a card that stayed in snooze until the app opened. The individual deadline schedule and stale-content display address these two reports. Unit tests cover both changes. Their behavior on the locked iPhone still needs confirmation after installing this update.
