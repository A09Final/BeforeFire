import Foundation
import Observation

@MainActor
@Observable
final class OnboardingProgressStore {
    static let completionKey = "onboarding.completed"
    private(set) var hasCompleted: Bool
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hasCompleted = defaults.bool(forKey: Self.completionKey)
    }

    func complete() {
        defaults.set(true, forKey: Self.completionKey)
        hasCompleted = true
    }
}
