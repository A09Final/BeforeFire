# BeforeFire Project Specification

Status: Draft. This document describes the intended product. It does not confirm implemented features or validated detection performance.

Source: `C05 - A09 - CBL Canvas3.pdf`, the Miro canvas export supplied by the project owner. The PDF is not stored in this repository.

Architecture update: The project owner changed the architecture on 2026-10-23. The owner-confirmed decisions below replace conflicting architecture concepts from the Miro canvas and earlier proposals. They record the intended design, not verified integration behavior.

- **Owner-confirmed:** The project owner selected this design. Implementation and technical validation may still be required.
- **Board-supported:** The Miro canvas describes the requirement or concept.
- **Proposed:** The requirement was added to make the specification clear and testable. It is not a confirmed project decision.
- **Open or undecided:** The project still needs a decision or validation.

1. **Product purpose — board-supported**

   BeforeFire is an iOS companion app for a connected kitchen monitoring system.

   The system aims to detect conditions that could develop into a kitchen fire. It alerts residents through a physical alarm and phone notifications.

   The main scenario is cooking that continues after the person leaves the kitchen or forgets about it. The intended benefit is earlier awareness and action. Successful fire prevention remains an outcome to validate.

2. **Users and initial scope**

   The board identifies homeowners and household members who cook. Interviews include people who become distracted by childcare, visitors, and phone use.

   **Proposed first version:** Support one home, one kitchen, one sensor unit, and one alarm unit. The selected architecture also uses a HomePod as the Apple home hub. The number of phones that can receive alerts remains open.

   Automatic stove control, gas shutoff, fire suppression, and automatic emergency calls are outside this proposed first version. The board discusses some of these in research, but does not establish them as product requirements.

3. **System responsibilities**

   | Component | Intended responsibility | Status |
   |---|---|---|
   | Thermal sensor | Provide temperature information from the cooking area | Board-supported |
   | Environmental sensor | Provide environmental readings used to assess changing kitchen conditions | Board-supported |
   | Presence sensor | Report whether a person is detected near the monitored area | Board-supported |
   | Sensor unit: ESP32-S3 N16R8 | Read and process sensor readings, determine detection results, and initiate notifications | Owner-confirmed |
   | Alarm unit: ESP32-C3 and speaker | Operate the physical alarm only | Owner-confirmed |
   | HomeSpan firmware | Enable HomeKit support on the ESP32 devices | Owner-confirmed |
   | HomeKit and HomePod | Provide the selected connection and data access arrangement for iOS; HomePod serves as the Apple home hub | Owner-confirmed; exact data path requires validation |
   | HomeKit webhook and APNs notification integration | Deliver sensor-unit-triggered notifications to iOS | Owner-confirmed direction; implementation details open |
   | iOS app | Support setup, monitoring, notifications, and permitted alarm actions | Board-supported |

   **Owner-confirmed responsibility boundary:** The sensor unit processes sensor readings. The ESP32-C3 alarm unit only operates the physical alarm. HomePod has the separate role of Apple home hub. In this specification, use "alarm unit" for the ESP32-C3 to avoid confusing the two devices.

   **Proposed app boundary:** The app displays the sensor unit's detection results and sends permitted user commands. It does not maintain a separate set of detection rules.

   **Selected integration paths:**

   - Sensor readings and status: the sensor unit uses HomeSpan to expose information through HomeKit. HomePod participates as the Apple home hub. The iOS app uses the selected HomeKit arrangement to access information.
   - Notifications: the owner described the route as "homekit-webhook" through "ESP32-APN-ios". This document uses APNs for Apple Push Notification service. The sensor unit initiates notification events. The webhook trigger, receiving service, and APNs provider arrangement remain open.
   - Physical alarm: the sensor unit determines the condition that requires an alarm. The ESP32-C3 operates the alarm. The communication path between these units remains open.

   TODO: Confirm which HomeKit services and characteristics expose readings and detection results. Confirm the local and remote data paths and HomePod dependencies.

   TODO: Identify the component that invokes and receives the webhook, and the component that sends requests to APNs. Define authentication, device token registration, payloads, retries, and duplicate handling. Do not assume that HomeKit or HomeSpan provides a built-in webhook-to-APNs bridge.

   TODO: Define the alarm command and acknowledgement path between the ESP32-S3 sensor unit and ESP32-C3 alarm unit.

4. **Main user flow**

   The resident installs and powers the sensor unit and alarm unit. Setup includes the selected HomeKit and HomePod arrangement. The exact Wi-Fi provisioning and HomeKit pairing steps, including which steps occur in BeforeFire or Apple's Home app, remain open.

   After setup, the resident can check kitchen conditions. Monitoring continues without requiring the resident to keep the app open.

   When the system detects a condition that requires attention, it produces an appropriate alert. The resident opens the alert, checks the kitchen, and addresses the cause.

   The earlier flow allows the resident to stop the physical alarm after the cause has ended. The exact control rules remain open.

5. **Functional requirements for the iOS app**

   | Area | Draft requirement | Basis |
   |---|---|---|
   | Setup | Guide the user through the selected HomeKit setup for the sensor unit, alarm unit, and HomePod arrangement | Owner-confirmed architecture; setup steps open |
   | Setup verification | Show which required devices are connected and ready | Proposed |
   | Kitchen overview | Show the current condition and the reason for a warning or alarm | Board-supported |
   | Sensor readings | Show cooking-area temperature, presence, and environmental readings obtained through the selected HomeKit integration | Board-supported content; owner-confirmed integration |
   | Reading validity | Show the last update time and identify unavailable or old readings | Proposed |
   | Notifications | Present sensor-unit-triggered notifications through the selected webhook and APNs integration | Owner-confirmed direction; delivery details open |
   | Alert details | Show the affected kitchen, detected condition, time, and suggested next action | Proposed |
   | Alarm control | Request an allowed alarm action and show whether the ESP32-C3 alarm unit completed it | Board-supported intent; owner-confirmed hardware; proposed confirmation behavior |
   | Device status | Show connection failures and steps to restore the connection | Proposed |
   | Settings | Provide device information and notification setup guidance | Proposed |
   | Emergency contact | Let the user initiate a call to a configured contact | Mentioned in board feedback; scope open |

   **Proposed screen structure:** Setup, Kitchen Overview, Alert Details, and Devices/Settings. This is a suggested structure, not a final navigation design.

6. **Monitoring states — proposed**

   Risk and monitoring availability should be separate. A connection failure must not appear as a normal kitchen condition.

   | State type | State | Meaning |
   |---|---|---|
   | Risk | Normal | Valid readings do not meet the configured warning or alarm conditions |
   | Risk | Warning 1 (Unsafe) | A detected condition requires the resident to check the kitchen |
   | Risk | Warning 2 (Dangerous) | A detected condition requires more urgent action |
   | Risk | Alarm | A detected condition requires urgent attention |
   | Risk | Unknown | Available information is insufficient to determine the current risk |
   | Monitoring | Starting | Devices are connecting or preparing readings |
   | Monitoring | Available | Required readings are current and valid |
   | Monitoring | Degraded | Some required readings are unavailable or invalid |
   | Monitoring | Offline | Communication with the monitoring system is unavailable |

   “Normal” should not make an absolute claim that the kitchen is safe. Acknowledging an alert should also remain separate from resolving its cause.

7. **Detection and alarm behavior**

   The board proposes using temperature, environmental changes, and human presence together. It also explores temperature trends and machine learning.

   The ESP32-S3 N16R8 sensor unit performs sensor processing and initiates notification events. The ESP32-C3 alarm unit does not perform sensor processing or determine risk.

   The following rules remain **undecided**:

   - Conditions that start a warning or alarm.
   - How long a condition must continue before the state changes.
   - How presence changes the interpretation of other readings.
   - Conditions that reduce or clear an alert.
   - Handling of missing, delayed, or invalid readings.
   - When alarm silence is allowed and when the alarm sounds again.
   - Validation and deployment of the sensor-side fuzzy rules. The app does not evaluate fuzzy rules or classify risk from raw values.

   The numerical examples in the canvas are draft research notes. They should not become production thresholds without validation.

   **Proposed requirement:** Local monitoring and the physical alarm continue when internet access fails, provided the required local devices remain connected. Remote notification availability must be shown separately.

   This offline behavior is not verified. Validate sensor processing, physical alarm delivery, HomeKit data access, and webhook/APNs delivery separately. Define the behavior when HomePod, Wi-Fi, internet access, or the notification service is unavailable.

8. **Interface and engineering requirements**

   The board calls for a calm interface, short wording, clear status information, SF Pro, and SF Symbols. It explores granite, marble, and graphite visual styles. The final style still needs confirmation.

   The app should support Dynamic Type and readable contrast. **Proposed:** Use text and symbols with color to distinguish states, and provide VoiceOver labels.

   The existing project uses SwiftUI. Implementation should follow the repository rules: separate presentation, application state, detection logic, communication, and persistence where needed. Do not add package dependencies without an explicit request.

   **Implemented UI preview (2026-10-27):** The app includes an ActivityKit Live Activity and a WidgetKit extension for the alarm design. It provides Lock Screen, expanded, compact, and minimal presentations. Opening Preview Alarm automatically starts a local Live Activity, or reuses the existing preview without resetting its countdown. Developer Settings retains an End Live Activity Preview button. The Snooze action starts a local preview countdown, with a default duration of 60 seconds. Developer Settings can change the next snooze duration from 5 to 3600 seconds. The snoozed screen uses a remaining-time ring and a Resume Alarm button. The snoozed Live Activity uses the same Onyx and system-orange appearance, a native timer ring, and a Resume Alarm action. Compact presentation shows the remaining time. Resume updates only the local preview state. Resume or countdown expiry returns to the alarm preview. The app checks the saved deadline when it becomes active; this is not a background alarm scheduling guarantee. Snooze sends no hardware command. Tapping the Live Activity outside its Snooze button opens the existing full-screen alarm preview. The header shows the alarm status beside its icon; there is no app-name label or separate Open app button. Live Activity state can remain after the app closes, until the preview ends or the system removes it. Remote Live Activity starts and updates, production sensor-triggered notifications, and hardware snooze behavior are not implemented. The push notification test path is described in section 10. Local preview sound and haptics are described below. Developer Settings also includes a Hub disconnected simulation. The alarm screen shows Hub offline, the last known alarm state, and unavailable live status. The same offline state appears in the Live Activity and remains set during snooze and resume. It does not change a real connection. This preview does not establish AlarmKit integration or replace the notification-path decisions above.

   **Local alarm feedback (2026-11-05):** The preview uses a bundled original tone with AVAudioPlayer and a repeating Core Haptics pattern. Feedback runs only while the alarm screen is open, the app is active, and the preview is not snoozed. Silence stops both outputs. Resume and countdown expiry restart feedback only while those conditions apply. Closing the preview, ending the Live Activity preview, or leaving the foreground stops feedback. The audio uses the playback session category and the current device volume. The app does not change the system volume or add background audio. Devices without haptic support play audio only. Playback failures appear in the preview and in logs. System audio interruptions stop feedback; playback can resume when the system permits it and the preview still requires it. This does not implement background alert delivery, Critical Alerts, AlarmKit, or a physical alarm command. Haptic output requires validation on a physical iPhone.

   **Sensor-triggered alarm while the app is active (2026-11-06):** A current and valid `alarm` reading from the linked sensor opens the full-screen alarm and starts the local Live Activity when enabled. The app checks readings while active, including in Settings. Repeated alarm readings do not reopen the screen or reset snooze. A current non-alarm reading lets a later alarm open again. The app does not close the alarm on recovery. Remote Live Activity start still requires backend integration.

   **Owner-confirmed Monitoring design (2026-11-01):** The Monitoring preview uses a dark background and alternating charcoal and off-white sensor cards. SF Pro Compressed provides uppercase headings, large sensor values, and separate units. SF Symbols provide the sensor illustrations, with red flame and cyan temperature and humidity accents. The Settings control retains Liquid Glass. The grid fills the available height; larger text uses a scrolling layout when required. These visual changes do not add sensor integration or detection rules.

   **Proposed:** Only authorized users can access household readings or send device commands. Wi-Fi credentials and other secrets must not appear in logs.

9. **Acceptance criteria — proposed**

   The first version is ready for evaluation when:

   - A user can complete setup or understand why setup failed.
   - The overview distinguishes valid readings from unavailable readings.
   - Test scenarios produce the expected warning, alarm, and recovery states.
   - Opening a notification shows the relevant alert.
   - Failed alarm commands remain visible as failures.
   - HomeKit setup and reading updates work through the agreed HomeSpan and HomePod arrangement.
   - The ESP32-S3 sensor unit processes readings and triggers the expected ESP32-C3 alarm behavior.
   - The agreed webhook and APNs path delivers an alert to the intended iOS device.
   - Internet loss produces the agreed local and remote behavior.
   - HomePod and notification service failures produce the agreed availability states.
   - Users can identify the current condition and required action during usability testing.
   - Detection testing measures false alerts, missed events, and warning lead time against agreed targets.

   Simulated readings can verify app behavior. They cannot establish real detection performance.

The main decisions needed before implementation are the first-version scope, HomeKit data mapping and setup flow, sensor-to-alarm communication, webhook and APNs responsibilities, alert rules, offline behavior, and supported iOS versions. Sensor processing now belongs to the ESP32-S3 N16R8 sensor unit. The physical alarm now belongs to the ESP32-C3 alarm unit.


10. **Push notification setup and testing — iOS code; device delivery unverified**

   The selected app identifier is `com.ibnu.BeforeFire`. The app requests notification permission from Settings > Notifications. It checks existing permission when it becomes active. If alerts are allowed, it registers with APNs. Registration is repeated on a new app launch. The app keeps the latest device token in memory. It does not log the token or save it as a permanent device identifier.

   The Debug entitlement uses `development`. The Release entitlement uses `production`. The final signed app and provisioning profile must match the APNs environment used by the sender. The `.p8` key stays on the provider server or the developer's test machine. Do not add it to the app, Assets, or Git.

   **Current behavior:** Notifications received in the foreground can show a banner, appear in the notification list, and play the system notification sound. A tap on a valid Alarm notification opens the local alarm screen. A tap on an Unsafe or Dangerous notification returns to Monitor. The notification text asks the user to check or act on the condition. The full-screen Alarm shows instructions for immediate action and getting help. Normal does not open a CTA or an alarm screen. A tap received before the scene is active waits for that scene. Dismiss actions and unrelated notification payloads do not open the alarm screen. A malformed alarm payload is rejected and recorded without logging the payload.

   **Backend payload contract — aligned with Derick's backend, 2026-11-06:** Use the JSON files in `Examples/PushNotifications`. The `beforefire` object requires `deviceId`, `alertId`, `condition`, and integer `issuedAt` (Unix seconds). `score` is optional. Device IDs follow `DAPUR_(ALM_)?[0-9A-F]{6}`. Alert IDs contain 1–64 ASCII letters, digits, underscores, or hyphens. Conditions are `normal`, `warning1`, `warning2`, and `alarm`. The app preserves the condition and does not classify the score. This replaces the proposed version-2 payload. The backend does not send `assessment`, rule ID, reasons, or absence duration. The app therefore uses general condition guidance. Reuse an alert ID for the same event. A repeated alarm tap preserves that event's snooze deadline while its local state or Live Activity remains available. A new alert ID resumes the local alarm. A notification for a different linked sensor does not open the alarm screen.

   The test payload opens the existing preview guidance. It does not provide live sensor readings or prove that a kitchen condition is current. Event freshness, recovery events, device-to-household authorization, and history after the system removes a Live Activity remain provider integration decisions.

   **Provider boundary:** Derick's backend supplies discovery, readings, an APNs relay, and signed commands at `POST /v1/devices/{deviceId}/commands`. Commands include `register_push_token` and `unregister_push_token`. The iOS token upload is not connected yet; `PushNotificationManager.didRegister(deviceToken:)` retains that integration TODO. Registration must use the backend's signed command contract and the device PoP, not the readings key. The sensor command handler and end-to-end delivery still need verification. This payload adaptation does not change backend or firmware code.

   **Build and test on Ibnu's Mac:**

   1. Select the Apple Developer Team that owns `com.ibnu.BeforeFire`. Use the same team's signing setup for the app, widget extension, and notification service extension. Do not use the local `com.ranggarijasa.BeforeFire.debug` override for this test.
   2. Enable Push Notifications for the app target and App ID. Refresh the development provisioning profile if it does not include the APNs entitlement. Keep the HomeKit entitlement.
   3. Build the Debug configuration and run it on a physical iPhone. Open Settings > Notifications > Enable Notifications. Accept the system request. Confirm that Push registration changes to Registered with APNs.
   4. In the Debug-only APNs Testing section, confirm Bundle ID is `com.ibnu.BeforeFire`. Tap Copy Device Token. The clipboard entry expires after five minutes. Use it only with the team's APNs test sender. Registration with APNs does not mean registration with a backend provider.
   5. In Apple's Push Notifications Console, select the app and development/sandbox environment. Send `Examples/PushNotifications/warning1.json`, `warning2.json`, and `alarm.json` to that token. These examples match the backend and omit `mutable-content`. Background banners use the backend title and body. Update `issuedAt` to the current Unix time for a new test. To test the optional service extension separately, add `mutable-content: 1` inside `aps`. For an HTTP/2 test sender, use `apns-topic: com.ibnu.BeforeFire`, `apns-push-type: alert`, and `apns-priority: 10`. Match the `.p8` key's team, topic permissions, and environment. No `.p8` key is required inside the iOS project.
   6. Test foreground delivery, background delivery, a locked iPhone, and a tap that launches the app from a stopped state. Confirm that a tap on Unsafe or Dangerous returns to Monitor, including from Settings. Confirm that a tap on Alarm opens the alarm screen.
   7. Silence the preview, then tap a notification with the same event ID. Confirm that the snooze deadline stays the same. Send a new event ID and confirm that the alarm resumes. Test missing and malformed custom fields; they must not open an alarm screen.
   8. Deny notification permission, then enable it in iOS Settings and return to the app. Confirm that registration runs. Test registration failure and Retry Registration. Reinstall the app and use the new token rather than a saved token from an earlier installation.
   9. Run `KitchenGuidanceTests`, `PushNotificationTests`, `MonitorPreviewTests`, `MonitorReadingsFormatterTests`, `SensorReadingsSnapshotTests`, `AlarmActivityTests`, and `AlarmFeedbackTests` in the BeforeFire test plan. The new tests cover authorization, cancellation, token conversion and replacement, registration failures, payload validation, cold-launch routing, and event identity during snooze. On 2026-11-06, the focused `KitchenGuidanceTests`, `PushNotificationTests`, and `AlarmActivityTests` run passed on the iPhone 17e simulator (iOS 27.2): 59 tests in 3 suites. Physical-device delivery is not verified by these tests.
   10. Before a TestFlight test, inspect the exported app's signed APNs entitlement. Use its production token with the production APNs environment. A development token cannot be reused for a production build.

   The APNs notification sound is `default`. The looping in-app audio and haptic pattern run only while the app is active and the alarm screen is open. No background audio mode, Critical Alerts entitlement, AlarmKit integration, or remote Live Activity push token is added by this change.

   Apple references: [Registering with APNs](https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns), [Push Notifications Console](https://developer.apple.com/documentation/usernotifications/testing-notifications-using-the-push-notification-console), [APNs token authentication](https://developer.apple.com/documentation/usernotifications/establishing-a-token-based-connection-to-apns).


11. **Status and CTA mapping — owner-confirmed presentation decisions, 2026-11-05**

   The sensor owns fuzzy evaluation. The iOS app uses the reported condition. It does not compute rule strengths, combine memberships, classify a score, or choose a risk level from temperature, IAQ, presence, or absence duration.

   | Sensor condition | Monitor and notification label | Monitor CTA |
   | --- | --- | --- |
   | `normal` | Normal | None |
   | `warning1` | Unsafe | Only the reported reasons: Poor Air Quality, No Presence Detected, High Heat Detected. If reasons are missing, use a general request to check the kitchen. |
   | `warning2` | Dangerous | Only the reported reasons: Concerning Air Quality Detected, No Presence Detected, Abnormally High Heat Detected. Then ask the user to check the kitchen now and turn off the stove if safe. |
   | `alarm` | Alarm | Turn stove off NOW. Call closest available person if you are not able to reach the stove. |
   | Invalid or unknown result | Unknown | No condition-specific CTA. Do not interpret an invalid default Normal enum as a valid Normal result. |

   Active Alarm and Snoozed Alarm describe presentation state. Snooze does not change the sensor's risk label. Active Alarm uses “Turn stove off NOW” and “Call closest available person if you are not able to reach the stove”. Snoozed Alarm uses “Turn stove off or call the closest available person”. The same strings are used by the app and Live Activity.

   Monitor uses the supplied 32-rule message table for Warning 1 and Warning 2 when the backend reports a rule that matches the condition. The table above describes the fallback when a matching rule is unavailable. The same catalog supplies notification text when the sender provides the necessary metadata. Normal rules have no action text. Unsafe and Dangerous use checking and handling instructions. Alarm notification text is urgent. The full-screen alarm adds the instruction to call the closest available person. The catalog contains messages, not detection logic. A rule-specific message is used only if the sender supplies a recognized `rule_id` whose output label matches the reported final condition. Fuzzy aggregation can produce a final label that differs from an individual rule. In that case, use the general message for the final condition. Never replace the sensor label with the rule's label.

   **Optional assessment metadata:** The proposed `assessment` object uses `condition` (`normal`, `warning1`, `warning2`, or `alarm`), required Boolean `valid`, optional integer `rule_id`, optional string array `reasons`, and optional integer `absence_duration_seconds`. Recognized reasons are `poor_air_quality`, `no_presence`, and `high_heat`. Unknown reason strings are ignored. Missing or false `valid` inside this object means the result is unavailable. A missing or negative absence duration is not replaced with an invented time. Notification messages then say that no one is detected without stating a duration.

   The existing readings endpoint still supports its nullable top-level `condition`. For compatibility, the app treats that existing value as the backend's validated result unless top-level `valid` is false. It accepts a new optional `assessment` object for richer messages. The top-level `valid: false` overrides a Normal value or any nested result. Conflicting top-level and nested condition labels are shown as Unknown. Old or offline readings do not supply a CTA. Reasons from unavailable sensors are not shown. The app does not infer High Heat or Poor Air Quality reasons from raw measurements.

   **Backend integration TODO:** Confirm the new metadata names and forward fuzzy validity. If the backend does not send validity yet, it must keep `condition` null for invalid fuzzy results. The app cannot recover a validity flag that the backend drops. The supplied C++ module returns only condition, score, and valid; it does not currently supply a selected rule ID or reason list. Add those fields on the sensor/backend side when they can be reported reliably. Until then, the app uses general messages. The prototype numeric thresholds in the supplied fuzzy files remain unvalidated and are not copied into the iOS app.

   **Notification service:** Derick's current payload does not include `mutable-content: 1`, so it does not request the service extension. Background banners retain the backend title and body. The app reads the backend payload when a user taps the notification, and returns to Monitor or opens the alarm screen. If a future sender enables the service extension, it maps a valid condition to the shared general guidance. Rule-specific push messages are not available with the current backend fields. Normal pushes are allowed by the backend and can appear as silent recovery information in the background. The app suppresses Normal notifications in the foreground and does not open an alarm for them. A malformed payload cannot open the alarm screen. The extension, when invoked, maps it to a silent status-unavailable message.

   The new service target uses bundle ID `com.ibnu.BeforeFire.NotificationService`. Its shared mapping sources are also included in the widget target. These changes to `project.pbxproj` are required shared project configuration, not a local signing override. Keep them in the feature commit even though `*.pbxproj` appears in `.gitignore`.

   **Validation:** The 2026-11-06 payload adaptation built successfully and passed 59 focused tests in `KitchenGuidanceTests`, `PushNotificationTests`, and `AlarmActivityTests` on the iPhone 17e simulator (iOS 27.2). Notification extension delivery, background behavior, and physical-device APNs delivery still need device testing. The new mapping tests cover all four labels, all 32 rule entries, missing reasons and duration, invalid results, stale readings, wrong rule IDs, snooze state, and notification content. Simulated examples do not validate sensor detection performance.
