//
//  ContentView.swift
//  BeforeFire
//
//  Created by Ibnu Taufick Ahraza on 10/22/26.
//

import SwiftUI

struct ContentView: View {
    @State private var alarmPreview = AlarmPreviewModel()
    @State private var sensorBackend = SensorBackendSettingsModel.live()
    @State private var liveReadings = MonitorLiveReadingsModel.live()
    @State private var pushNotifications = PushNotificationManager.shared
    @State private var notificationDetails: KitchenPushEvent?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            MonitorView(viewModel: .mock)
        }
        .environment(alarmPreview)
        .environment(sensorBackend)
        .environment(liveReadings)
        .onOpenURL { alarmPreview.open($0) }
        .onChange(of: alarmPreview.isAlarmPresented) { _, isPresented in
            if isPresented { alarmPreview.startLiveActivity() }
        }
        .fullScreenCover(isPresented: $alarmPreview.isAlarmPresented, onDismiss: presentPendingPushEvent) {
            AlarmPreviewFlowView()
                .environment(alarmPreview)
                .presentationBackground(.clear)
        }
        .sheet(item: $notificationDetails, onDismiss: presentPendingPushEvent) { event in
            KitchenNotificationDetailsView(event: event)
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

    private func presentPendingPushEvent() {
        guard scenePhase == .active, !alarmPreview.isEndingActivity,
              let event = pushNotifications.pendingEvent else { return }
        if let linkedDevice = sensorBackend.link?.deviceID, event.deviceID != linkedDevice {
            _ = pushNotifications.takePendingEvent()
            pushNotifications.reportPayloadError(.differentDevice)
            return
        }
        switch event.assessment.validCondition {
        case .normal:
            // Normal does not create a CTA or clear a previous alarm locally.
            _ = pushNotifications.takePendingEvent()
            notificationDetails = nil
        case .alarm:
            if notificationDetails != nil {
                notificationDetails = nil
                return
            }
            _ = pushNotifications.takePendingEvent()
            alarmPreview.openPushAlarm(event)
        case .warning1, .warning2, nil:
            guard !alarmPreview.isAlarmPresented else { return }
            notificationDetails = pushNotifications.takePendingEvent()
        }
    }
}

#Preview {
    ContentView()
}
