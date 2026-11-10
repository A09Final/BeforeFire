//
//  ContentView.swift
//  BeforeFire
//
//  Created by Ibnu Taufick Ahraza on 10/22/26.
//

import ActivityKit
import SwiftUI

struct ContentView: View {
    @State private var alarmPreview = AlarmPreviewModel()
    @State private var sensorBackend = SensorBackendSettingsModel.live()
    @State private var liveReadings = MonitorLiveReadingsModel.live()
    @State private var pushNotifications = PushNotificationManager.shared
    @State private var onboarding = OnboardingProgressStore()
    @State private var navigationPath = NavigationPath()
    @Environment(\.scenePhase) private var scenePhase

    private struct LiveReadingsTaskID: Equatable {
        let link: SensorBackendLink?
        let isActive: Bool
    }

    var body: some View {
        Group {
            if onboarding.hasCompleted {
                NavigationStack(path: $navigationPath) {
                    MonitorView(viewModel: .mock)
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
        .onOpenURL { alarmPreview.open($0, linkedDeviceID: sensorBackend.link?.deviceID) }
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
            if phase == .active { alarmPreview.synchronizeFromLiveActivity() }
            alarmPreview.setApplicationActive(phase == .active)
            presentPendingPushEvent()
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            AlarmLiveActivityRegistration.shared.refreshRegistration()
            await pushNotifications.refreshAuthorization()
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
