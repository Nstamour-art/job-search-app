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
        if let cloudContainer = try? ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)]
        ) {
            sharedModelContainer = cloudContainer
        } else {
            sharedModelContainer = try! ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, cloudKitDatabase: .none)]
            )
        }
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
