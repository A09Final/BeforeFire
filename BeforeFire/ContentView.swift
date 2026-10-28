//
//  ContentView.swift
//  BeforeFire
//
//  Created by Ibnu Taufick Ahraza on 10/22/26.
//

import SwiftUI

struct ContentView: View {
    @State private var alarmPreview = AlarmPreviewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            MonitorView(viewModel: .mock)
        }
        .environment(alarmPreview)
        .onOpenURL { alarmPreview.open($0) }
        .onChange(of: alarmPreview.isAlarmPresented) { _, isPresented in
            if isPresented { alarmPreview.startLiveActivity() }
        }
        .fullScreenCover(isPresented: $alarmPreview.isAlarmPresented) {
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
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { alarmPreview.synchronizeFromLiveActivity() }
        }
        .onReceive(NotificationCenter.default.publisher(for: AlarmActivityAttributes.previewStateDidChange)) { _ in
            alarmPreview.synchronizeFromLiveActivity()
        }
    }
}

#Preview {
    ContentView()
}
