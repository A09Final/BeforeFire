import AVFAudio
import Foundation
import Testing
import UIKit
@testable import BeforeFire

@MainActor
struct AlarmFeedbackTests {
    private let start = Date(timeIntervalSince1970: 1000)

    @Test func feedbackNeedsAnOpenAlarmAndAnActiveApp() {
        let output = RecordingAlarmFeedback()
        let model = AlarmPreviewModel(feedback: output)
        model.isAlarmPresented = true
        #expect(output.requests.isEmpty)
        model.setApplicationActive(true)
        #expect(output.requests == [true])
        model.isAlarmPresented = false
        #expect(output.requests == [true, false])
        model.setApplicationActive(false)
        model.setApplicationActive(true)
        #expect(output.requests == [true, false])
    }

    @Test func liveAlarmOpensOnceAndPreservesSnoozeUntilAConfirmedNewEvent() {
        let output = RecordingAlarmFeedback()
        let model = AlarmPreviewModel(feedback: output)
        let deviceID = "DAPUR_A1B2C3"
        let alarm = SensorReadingsSnapshot(deviceID: deviceID, condition: .alarm)
        model.setApplicationActive(true)
        model.handleLiveReading(alarm, linkedDeviceID: deviceID)
        #expect(model.isAlarmPresented)
        #expect(output.requests == [true])

        model.snooze(at: start)
        let deadline = model.alarmState.snoozeEndsAt
        model.handleLiveReading(alarm, linkedDeviceID: deviceID)
        #expect(model.alarmState.snoozeEndsAt == deadline)
        #expect(output.requests == [true, false])

        model.isAlarmPresented = false
        model.resumeAlarm()
        model.handleLiveReading(.init(deviceID: deviceID, condition: .normal, isStale: true), linkedDeviceID: deviceID)
        model.handleLiveReading(alarm, linkedDeviceID: deviceID)
        #expect(!model.isAlarmPresented)

        model.handleLiveReading(.init(deviceID: deviceID, condition: .warning2), linkedDeviceID: deviceID)
        model.handleLiveReading(alarm, linkedDeviceID: deviceID)
        #expect(model.isAlarmPresented)
        #expect(output.requests == [true, false, true])
    }

    @Test func liveAlarmRequiresAnActiveAppAndACurrentReadingFromTheLinkedSensor() {
        let output = RecordingAlarmFeedback()
        let model = AlarmPreviewModel(feedback: output)
        let deviceID = "DAPUR_A1B2C3"
        let alarm = SensorReadingsSnapshot(deviceID: deviceID, condition: .alarm)
        model.handleLiveReading(alarm, linkedDeviceID: deviceID)
        #expect(!model.isAlarmPresented)

        model.setApplicationActive(true)
        let rejected = [
            SensorReadingsSnapshot(deviceID: "DAPUR_123456", condition: .alarm),
            SensorReadingsSnapshot(deviceID: deviceID, condition: .alarm, conditionIsValid: false),
            SensorReadingsSnapshot(deviceID: deviceID, condition: .alarm, isStale: true),
            SensorReadingsSnapshot(deviceID: deviceID, condition: .alarm, connection: .offline)
        ]
        for snapshot in rejected {
            model.handleLiveReading(snapshot, linkedDeviceID: deviceID)
            #expect(!model.isAlarmPresented)
        }
        #expect(output.requests.isEmpty)

        model.handleLiveReading(alarm, linkedDeviceID: deviceID)
        #expect(model.isAlarmPresented)
        #expect(output.requests == [true])
    }

    @Test func silenceStopsFeedbackAndResumeRestartsIt() {
        let output = RecordingAlarmFeedback()
        let model = activePreview(output)
        model.snooze(at: start)
        #expect(output.requests == [true, false])
        #expect(model.alarmState.isSnoozed)
        model.resumeAlarm()
        #expect(output.requests == [true, false, true])
        #expect(!model.alarmState.isSnoozed)
    }

    @Test func repeatedUpdatesDoNotStartDuplicatePlayback() {
        let output = RecordingAlarmFeedback()
        let model = activePreview(output)
        model.setApplicationActive(true)
        model.isAlarmPresented = true
        model.isHubDisconnected = true
        model.updateSnoozeDuration(120)
        model.resumeAlarm()
        #expect(output.requests == [true])
    }

    @Test func backgroundStopsBothAndForegroundRestartsActiveAlarm() {
        let output = RecordingAlarmFeedback()
        let model = activePreview(output)
        model.setApplicationActive(false)
        #expect(output.requests == [true, false])
        model.setApplicationActive(true)
        #expect(output.requests == [true, false, true])
    }

    @Test func foregroundDoesNotRestartASnoozedAlarm() {
        let output = RecordingAlarmFeedback()
        let model = activePreview(output)
        model.snooze(at: start)
        model.setApplicationActive(false)
        model.setApplicationActive(true)
        #expect(output.requests == [true, false])
    }

    @Test func expiryRestartsFeedbackOnlyWhileAppIsActive() {
        let output = RecordingAlarmFeedback()
        let model = activePreview(output)
        model.snooze(at: start)
        model.resumeIfExpired(at: start.addingTimeInterval(59))
        #expect(output.requests == [true, false])
        model.setApplicationActive(false)
        model.resumeIfExpired(at: start.addingTimeInterval(60))
        #expect(output.requests == [true, false])
        model.setApplicationActive(true)
        #expect(output.requests == [true, false, true])
    }

    @Test func activeExpiryRestartsFeedback() {
        let output = RecordingAlarmFeedback()
        let model = activePreview(output)
        model.snooze(at: start)
        model.resumeIfExpired(at: start.addingTimeInterval(60))
        #expect(output.requests == [true, false, true])
    }

    @Test func closingPreviewPreventsResumeFromStartingFeedback() {
        let output = RecordingAlarmFeedback()
        let model = activePreview(output)
        model.isAlarmPresented = false
        model.resumeAlarm()
        #expect(output.requests == [true, false])
    }

    @Test(arguments: [AlarmFeedbackFailure.audioUnavailable, .hapticsUnavailable, .audioAndHapticsUnavailable, .interrupted])
    func feedbackFailureIsVisibleAndSilenceStillWorks(_ failure: AlarmFeedbackFailure) {
        let output = RecordingAlarmFeedback()
        let model = activePreview(output)
        output.onFailure?(failure)
        #expect(model.feedbackMessage == failure.message)
        model.snooze(at: start)
        #expect(output.requests == [true, false])
        #expect(model.feedbackMessage == nil)
        model.resumeAlarm()
        #expect(output.requests == [true, false, true])
    }

    @Test func recoveryClearsTheFailureWithoutStartingAnotherLoop() {
        let output = RecordingAlarmFeedback()
        let model = activePreview(output)
        output.onFailure?(.interrupted)
        output.onFailure?(nil)
        #expect(model.feedbackMessage == nil)
        #expect(output.requests == [true])
    }

    @Test func endingPreviewStopsFeedbackBeforeActivityCleanup() async {
        let output = RecordingAlarmFeedback()
        let model = activePreview(output)
        await model.endLiveActivities()
        #expect(!model.isAlarmPresented)
        #expect(output.requests == [true, false])
    }

    @Test func bundledSoundCanBeDecodedAndMatchesHapticLoop() throws {
        let sound = try #require(NSDataAsset(name: AlarmFeedbackConfiguration.soundAssetName))
        let player = try AVAudioPlayer(data: sound.data)
        #expect(abs(player.duration - AlarmFeedbackConfiguration.loopDuration) < 0.001)
        #expect(player.numberOfChannels == 1)
    }

    private func activePreview(_ output: RecordingAlarmFeedback) -> AlarmPreviewModel {
        let model = AlarmPreviewModel(feedback: output)
        model.setApplicationActive(true)
        model.isAlarmPresented = true
        return model
    }
}

@MainActor
private final class RecordingAlarmFeedback: AlarmFeedbackPlaying {
    var onFailure: ((AlarmFeedbackFailure?) -> Void)?
    private(set) var requests: [Bool] = []

    func setPlaying(_ shouldPlay: Bool) {
        requests.append(shouldPlay)
    }
}
