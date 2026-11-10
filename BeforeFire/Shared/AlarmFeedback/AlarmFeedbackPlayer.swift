import AVFAudio
import CoreHaptics
import Foundation
import OSLog
import UIKit

@MainActor
final class AlarmFeedbackPlayer: NSObject, AlarmFeedbackPlaying, AVAudioPlayerDelegate {
    var onFailure: ((AlarmFeedbackFailure?) -> Void)?

    private var isRequested = false
    private var isInterrupted = false
    private var hasActiveAudioSession = false
    private var audioPlayer: AVAudioPlayer?
    private var hapticEngine: CHHapticEngine?
    private var hapticPlayer: (any CHHapticAdvancedPatternPlayer)?
    private var hapticGeneration = UUID()
    private var playbackGeneration = UUID()
    private lazy var session = AVAudioSession.sharedInstance()
    private var isObservingSession = false
    private let logger = Logger(subsystem: "com.ibnu.BeforeFire", category: "AlarmFeedback")

    private func observeSession() {
        guard !isObservingSession else { return }
        isObservingSession = true
        NotificationCenter.default.addObserver(self, selector: #selector(audioInterrupted(_:)),
                                               name: AVAudioSession.didBecomeInactiveNotification, object: session)
        NotificationCenter.default.addObserver(self, selector: #selector(audioMayResume(_:)),
                                               name: AVAudioSession.resumptionRecommendationNotification, object: session)
        NotificationCenter.default.addObserver(self, selector: #selector(mediaServicesReset(_:)),
                                               name: AVAudioSession.mediaServicesWereResetNotification, object: session)
    }

    func setPlaying(_ shouldPlay: Bool) {
        guard isRequested != shouldPlay else { return }
        isRequested = shouldPlay
        if shouldPlay {
            // A new foreground request can retry even if no resumption notification arrived.
            isInterrupted = false
            startPlayback()
        } else {
            stopPlayback()
        }
    }

    private func startPlayback() {
        observeSession()
        playbackGeneration = UUID()
        let hasAudio = startAudio()
        let hasHaptics = startHaptics()
        switch (hasAudio, hasHaptics) {
        case (true, true): onFailure?(nil)
        case (false, true): onFailure?(.audioUnavailable)
        case (true, false): onFailure?(.hapticsUnavailable)
        case (false, false): onFailure?(.audioAndHapticsUnavailable)
        }
    }

    private func startAudio() -> Bool {
        do {
            guard let sound = NSDataAsset(name: AlarmFeedbackConfiguration.soundAssetName) else {
                throw PlaybackError.missingSound
            }
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
            hasActiveAudioSession = true
            let player = try AVAudioPlayer(data: sound.data)
            player.delegate = self
            player.numberOfLoops = -1
            player.volume = AlarmFeedbackConfiguration.audioVolume
            audioPlayer = player
            guard player.prepareToPlay(), player.play() else { throw PlaybackError.couldNotPlay }
            logger.info("Alarm audio started.")
            return true
        } catch {
            audioPlayer?.stop()
            audioPlayer = nil
            logger.error("Alarm audio failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func startHaptics() -> Bool {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            logger.info("This device does not support alarm haptics.")
            return true
        }
        let generation = UUID()
        hapticGeneration = generation
        do {
            let engine = try CHHapticEngine(audioSession: session)
            engine.playsHapticsOnly = true
            engine.stoppedHandler = { [weak self] reason in
                Task { @MainActor [weak self] in
                    guard let self, self.isRequested, self.hapticGeneration == generation else { return }
                    self.logger.error("Alarm haptics stopped: \(reason.rawValue)")
                    self.onFailure?(.hapticsUnavailable)
                }
            }
            engine.resetHandler = { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self, self.isRequested, !self.isInterrupted,
                          self.hapticGeneration == generation else { return }
                    self.stopHaptics()
                    if !self.startHaptics() { self.onFailure?(.hapticsUnavailable) }
                }
            }
            hapticEngine = engine
            try engine.start()
            let events = AlarmFeedbackConfiguration.pulseTimes.map { time in
                CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: AlarmFeedbackConfiguration.hapticIntensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: AlarmFeedbackConfiguration.hapticSharpness)
                ], relativeTime: time, duration: AlarmFeedbackConfiguration.pulseDuration)
            }
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makeAdvancedPlayer(with: pattern)
            player.loopEnabled = true
            player.loopEnd = AlarmFeedbackConfiguration.loopDuration
            hapticPlayer = player
            try player.start(atTime: CHHapticTimeImmediate)
            logger.info("Alarm haptics started.")
            return true
        } catch {
            stopHaptics()
            logger.error("Alarm haptics failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func stopHaptics(completion: @escaping @MainActor () -> Void = {}) {
        // Ignore callbacks from an engine that has already been stopped or replaced.
        hapticGeneration = UUID()
        hapticEngine?.stoppedHandler = { _ in }
        hapticEngine?.resetHandler = {}
        do {
            try hapticPlayer?.stop(atTime: CHHapticTimeImmediate)
        } catch {
            logger.error("Could not stop the haptic player: \(error.localizedDescription, privacy: .public)")
        }
        let engine = hapticEngine
        hapticPlayer = nil
        hapticEngine = nil
        guard let engine else {
            completion()
            return
        }
        engine.stop { [weak self] error in
            Task { @MainActor [weak self] in
                if let error {
                    self?.logger.error("Could not stop the haptic engine: \(error.localizedDescription, privacy: .public)")
                }
                completion()
            }
        }
    }

    private func stopPlayback() {
        let generation = UUID()
        playbackGeneration = generation
        audioPlayer?.stop()
        audioPlayer = nil
        // Release the audio session after the haptic engine has stopped using it.
        stopHaptics { [weak self] in
            guard let self, self.playbackGeneration == generation else { return }
            self.releaseAudioSession()
        }
        logger.info("Alarm audio and haptics stopped.")
    }

    private func releaseAudioSession() {
        if hasActiveAudioSession {
            do {
                try session.setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                logger.error("Could not release the audio session: \(error.localizedDescription, privacy: .public)")
            }
            hasActiveAudioSession = false
        }
    }

    @objc nonisolated private func audioInterrupted(_ notification: Notification) {
        guard let context = notification.userInfo?[AVAudioSession.deactivationContextKey] as? AVAudioSession.DeactivationContext,
              context.source == .system else { return }
        Task { @MainActor [weak self] in
            guard let self, self.isRequested else { return }
            self.isInterrupted = true
            self.stopPlayback()
            self.onFailure?(.interrupted)
        }
    }

    @objc nonisolated private func audioMayResume(_ notification: Notification) {
        guard let context = notification.userInfo?[AVAudioSession.resumptionContextKey] as? AVAudioSession.ResumptionContext else { return }
        let shouldResume = context.recommendation == .shouldResume
        Task { @MainActor [weak self] in
            guard let self, self.isInterrupted else { return }
            self.isInterrupted = false
            if self.isRequested && shouldResume {
                self.startPlayback()
            }
        }
    }

    @objc nonisolated private func mediaServicesReset(_ notification: Notification) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.stopPlayback()
            // Wait for a new user action after a media service reset.
            if self.isRequested { self.onFailure?(.interrupted) }
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
        Task { @MainActor [weak self, weak player] in
            guard let self, let player, self.audioPlayer === player, self.isRequested else { return }
            self.logger.error("Alarm audio decoding failed.")
            self.onFailure?(.audioUnavailable)
        }
    }

    private enum PlaybackError: Error {
        case missingSound
        case couldNotPlay
    }
}
