# Kitchen Status widget refresh

The widget uses WidgetKit push notifications on iOS 26 and later. It keeps its periodic timeline.

1. Build the app and widget from `feature/status_widget`.
2. Run a backend with `/v1/devices/{deviceId}/widget-token` and the WidgetKit push worker.
3. Open BeforeFire and save the sensor connection. Add Kitchen Status to the Home Screen.
4. The widget obtains its own token through `WidgetPushHandler`. The shared Keychain record keeps this token and pending removals. The sensor setup code is not shared with the widget.
5. The registration uses the sensor read key. Token changes, sensor replacement, widget removal, and app launch retry the registration or removal.
6. The backend sends a `widgets` push when the displayed status can change. WidgetKit then fetches the current sensor response. It does not classify sensor readings.
7. Periodic entries show the measurement time. After 15 minutes without a replacement entry, the heading becomes Last known status. That transition does not report a sensor disconnection.

Use sandbox for Xcode and production for TestFlight. The widget extension has separate Debug and Release APNs entitlements. Automatic signing must update its profile.

Test Normal, Unsafe, Dangerous, and Alarm with BeforeFire in the background. Check removal/relinking, network loss, and stale readings. Physical-device APNs delivery and update timing still need validation. iOS can delay widget updates, so the widget is not the alarm channel. Critical Alerts and ActivityKit remain separate.

Reference: https://developer.apple.com/documentation/widgetkit/updating-widgets-with-widgetkit-push-notifications
