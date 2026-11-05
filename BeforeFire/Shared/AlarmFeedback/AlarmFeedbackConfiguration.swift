import Foundation

enum AlarmFeedbackConfiguration {
    static let soundAssetName = "AlarmPreview"
    static let audioVolume: Float = 0.7
    // The bundled tone uses these same pulse times.
    static let loopDuration: TimeInterval = 2.4
    static let pulseTimes: [TimeInterval] = [0, 0.4, 0.8]
    static let pulseDuration: TimeInterval = 0.22
    static let hapticIntensity: Float = 0.8
    static let hapticSharpness: Float = 0.6
}
