import Foundation
import Observation

@Observable
@MainActor
final class OnboardingCoordinator {
    private(set) var isOnboardingComplete: Bool

    private static let key = "com.jobsearch.onboardingComplete"

    init() {
        isOnboardingComplete = UserDefaults.standard.bool(forKey: Self.key)
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: Self.key)
        isOnboardingComplete = true
    }

    func resetOnboarding() {
        UserDefaults.standard.removeObject(forKey: Self.key)
        isOnboardingComplete = false
    }
}
