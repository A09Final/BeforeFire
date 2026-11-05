import Foundation

enum AlarmFeedbackFailure {
    case audioUnavailable
    case hapticsUnavailable
    case audioAndHapticsUnavailable
    case interrupted

    var message: String {
        switch self {
        case .audioUnavailable:
            "The alarm sound could not play. Check your kitchen. Close and reopen the preview to try again."
        case .hapticsUnavailable:
            "Alarm vibration stopped. Check your kitchen. Close and reopen the preview to try again."
        case .audioAndHapticsUnavailable:
            "Alarm sound and vibration could not start. Check your kitchen. Close and reopen the preview to try again."
        case .interrupted:
            "Alarm feedback was interrupted. Check your kitchen. Close and reopen the preview to try again."
        }
    }
}

@MainActor
protocol AlarmFeedbackPlaying: AnyObject {
    var onFailure: ((AlarmFeedbackFailure?) -> Void)? { get set }
    func setPlaying(_ shouldPlay: Bool)
}
