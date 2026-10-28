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
   | Risk | Warning | A detected condition requires the resident to check the kitchen |
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
   - Whether detection uses fixed rules, machine learning, or both.

   The numerical examples in the canvas are draft research notes. They should not become production thresholds without validation.

   **Proposed requirement:** Local monitoring and the physical alarm continue when internet access fails, provided the required local devices remain connected. Remote notification availability must be shown separately.

   This offline behavior is not verified. Validate sensor processing, physical alarm delivery, HomeKit data access, and webhook/APNs delivery separately. Define the behavior when HomePod, Wi-Fi, internet access, or the notification service is unavailable.

8. **Interface and engineering requirements**

   The board calls for a calm interface, short wording, clear status information, SF Pro, and SF Symbols. It explores granite, marble, and graphite visual styles. The final style still needs confirmation.

   The app should support Dynamic Type and readable contrast. **Proposed:** Use text and symbols with color to distinguish states, and provide VoiceOver labels.

   The existing project uses SwiftUI. Implementation should follow the repository rules: separate presentation, application state, detection logic, communication, and persistence where needed. Do not add package dependencies without an explicit request.

   **Implemented UI preview (2026-10-27):** The app includes an ActivityKit Live Activity and a WidgetKit extension for the alarm design. It provides Lock Screen, expanded, compact, and minimal presentations. Developer Settings can start and end a local preview. The Snooze action changes only the preview state; it does not send a hardware command or start a timer. Tapping the Live Activity outside its Snooze button opens the existing full-screen alarm preview. The header shows the alarm status beside its icon; there is no app-name label or separate Open app button. Live Activity state can remain after the app closes, until the preview ends or the system removes it. Remote starts, push updates, sensor events, sound, and real snooze behavior are not implemented. This preview does not establish AlarmKit integration or replace the notification-path decisions above.

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
