//
//  ContentView.swift
//  BeforeFire
//
//  Created by Ibnu Taufick Ahraza on 10/22/26.
//

import ActivityKit
import OSLog
import SwiftUI
import WidgetKit

struct ContentView: View {
    @State private var alarmPreview = AlarmPreviewModel()
    @State private var sensorBackend = SensorBackendSettingsModel.live()
    @State private var liveReadings = MonitorLiveReadingsModel.live()
    @State private var pushNotifications = PushNotificationManager.shared
    @State private var onboarding = OnboardingProgressStore()
    @State private var navigationPath = NavigationPath()
    @Environment(\.scenePhase) private var scenePhase
    private static let widgetLogger = Logger(subsystem: "BeforeFire", category: "KitchenStatusWidget")

    private struct LiveReadingsTaskID: Equatable {
        let link: SensorBackendLink?
        let isActive: Bool
    }

    var body: some View {
        Group {
            if onboarding.hasCompleted {
                NavigationStack(path: $navigationPath) {
                    MonitorView(viewModel: .unlinked)
                }
            } else {
                OnboardingFlowView(isSimulated: simulatesOnboarding) {
                    onboarding.complete()
                    navigationPath = NavigationPath()
                }
            }
        }
        .environment(alarmPreview)
        .environment(sensorBackend)
        .environment(liveReadings)
        .task(id: LiveReadingsTaskID(link: sensorBackend.link, isActive: scenePhase == .active)) {
            guard scenePhase == .active else { return }
            await liveReadings.refreshRepeatedly(for: sensorBackend.link)
        }
        .onChange(of: liveReadings.lastUpdatedAt) { _, _ in
            guard scenePhase == .active, let deviceID = sensorBackend.link?.deviceID,
                  case .updated(let snapshot) = liveReadings.status else { return }
            alarmPreview.handleLiveReading(snapshot, linkedDeviceID: deviceID)
        }
        .onOpenURL { url in
            if url == KitchenStatusWidgetConnection.monitorURL {
                navigationPath = NavigationPath()
            } else {
                alarmPreview.open(url, linkedDeviceID: sensorBackend.link?.deviceID)
            }
        }
        .task {
            for activity in Activity<AlarmActivityAttributes>.activities {
                await alarmPreview.adoptRemoteActivity(activity, linkedDeviceID: sensorBackend.link?.deviceID)
            }
            for await activity in Activity<AlarmActivityAttributes>.activityUpdates {
                await alarmPreview.adoptRemoteActivity(activity, linkedDeviceID: sensorBackend.link?.deviceID)
            }
        }
        .onChange(of: sensorBackend.link) { oldLink, newLink in
            AlarmLiveActivityRegistration.shared.linkChanged(from: oldLink, to: newLink)
        }
        .onChange(of: sensorBackend.link, initial: true) { _, link in
            updateKitchenStatusWidgetConnection(for: link)
        }
        .onChange(of: liveReadings.kitchenStatus.title) { _, _ in
            WidgetCenter.shared.reloadTimelines(ofKind: KitchenStatusWidgetConnection.kind)
        }
        .onChange(of: alarmPreview.isAlarmPresented) { _, isPresented in
            if isPresented {
                alarmPreview.startLiveActivity(remoteDeviceID: AlarmLiveActivityRegistration.shared.registeredDeviceID)
            }
        }
        .fullScreenCover(isPresented: $alarmPreview.isAlarmPresented, onDismiss: presentPendingPushEvent) {
            AlarmPreviewFlowView()
                .environment(alarmPreview)
                .presentationBackground(.clear)
        }
        .task(id: alarmPreview.alarmState.snoozeEndsAt) {
            guard let deadline = alarmPreview.alarmState.snoozeEndsAt else { return }
            do {
                try await Task.sleep(for: .seconds(max(0, deadline.timeIntervalSinceNow)))
                guard !Task.isCancelled else { return }
                alarmPreview.resumeIfExpired()
            } catch is CancellationError {
                // Resume or a new snooze cancels the previous deadline.
            } catch {
                alarmPreview.resumeIfExpired()
            }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active {
                alarmPreview.synchronizeFromLiveActivity()
                KitchenWidgetPushRegistration.shared.refresh(force: true)
            } else if phase == .background {
                WidgetCenter.shared.reloadTimelines(ofKind: KitchenStatusWidgetConnection.kind)
            }
            alarmPreview.setApplicationActive(phase == .active)
            presentPendingPushEvent()
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            AlarmLiveActivityRegistration.shared.refreshRegistration()
            await pushNotifications.refreshAuthorization()
            await PushTokenRegistrar.shared.retryRevocationsWhileActive()
        }
        .onChange(of: pushNotifications.pendingEvent, initial: true) { _, _ in
            presentPendingPushEvent()
        }
        .onChange(of: alarmPreview.isEndingActivity) { _, isEnding in
            if !isEnding { presentPendingPushEvent() }
        }
        .onReceive(NotificationCenter.default.publisher(for: AlarmActivityAttributes.previewStateDidChange)) { _ in
            alarmPreview.synchronizeFromLiveActivity()
        }
    }

    private var simulatesOnboarding: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-simulateOnboarding")
        #else
        false
        #endif
    }

    private func updateKitchenStatusWidgetConnection(for link: SensorBackendLink?) {
        do {
            let connection = try KitchenStatusWidgetConnection()
            if try connection.update(link?.readingsAccess) {
                WidgetCenter.shared.reloadTimelines(ofKind: KitchenStatusWidgetConnection.kind)
            }
            KitchenWidgetPushRegistration.shared.refresh(force: true)
        } catch {
            Self.widgetLogger.error("Cannot update the widget sensor connection: \(String(describing: error), privacy: .private)")
        }
    }

    private func presentPendingPushEvent() {
        guard scenePhase == .active, !alarmPreview.isEndingActivity,
              let event = pushNotifications.pendingEvent else { return }
        if let linkedDevice = sensorBackend.link?.deviceID, event.deviceID != linkedDevice {
            _ = pushNotifications.takePendingEvent()
            pushNotifications.reportPayloadError(.differentDevice)
            return
        }
        switch event.assessment.validCondition {
        case .normal, .warning1, .warning2:
            // Keep an active alarm visible. Route the notification when it closes.
            guard !alarmPreview.isAlarmPresented else { return }
            _ = pushNotifications.takePendingEvent()
            navigationPath = NavigationPath()
        case .alarm:
            _ = pushNotifications.takePendingEvent()
            alarmPreview.openPushAlarm(event)
        case nil:
            _ = pushNotifications.takePendingEvent()
        }
    }
}

#Preview {
    ContentView()
}
