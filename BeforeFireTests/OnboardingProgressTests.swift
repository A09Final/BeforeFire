import Foundation
import Testing
@testable import BeforeFire

@MainActor
struct OnboardingProgressTests {
    @Test func completionPersistsOnlyWhenFinished() throws {
        let suiteName = "OnboardingProgressTests.completion"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let progress = OnboardingProgressStore(defaults: defaults)
        #expect(!progress.hasCompleted)
        #expect(!OnboardingProgressStore(defaults: defaults).hasCompleted)

        progress.complete()
        #expect(progress.hasCompleted)
        #expect(OnboardingProgressStore(defaults: defaults).hasCompleted)
    }
}
