import SwiftUI
import SwiftData

@main
struct JobSearchApp: App {
    @StateObject private var container = AppContainer()
    @StateObject private var onboardingCoordinator = OnboardingCoordinator()
    let sharedModelContainer: ModelContainer

    init() {
        let schema = Schema([
            UserProfile.self, WorkExperience.self, Education.self,
            Project.self, ResumeTheme.self, JobPosting.self, GeneratedDocument.self
        ])
        let config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        sharedModelContainer = try! ModelContainer(for: schema, configurations: [config])
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if onboardingCoordinator.isOnboardingComplete {
                    MainTabView()
                        .environmentObject(container)
                } else {
                    OnboardingView()
                        .environmentObject(container)
                        .environmentObject(onboardingCoordinator)
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
