import Foundation

@MainActor
final class OnboardingCoordinator: ObservableObject {
    @Published private(set) var isOnboardingComplete: Bool

    private static let key = "com.jobsearch.onboardingComplete"

    init() {
        isOnboardingComplete = UserDefaults.standard.bool(forKey: Self.key)
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: Self.key)
        isOnboardingComplete = true
    }

    /// Call from Settings or debug menu to re-trigger onboarding.
    func resetOnboarding() {
        UserDefaults.standard.removeObject(forKey: Self.key)
        isOnboardingComplete = false
    }
}
