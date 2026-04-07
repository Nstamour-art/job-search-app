import SwiftUI
import SwiftData

@main
struct JobSearchApp: App {
    @StateObject private var container = AppContainer()

    init() {
        ProfileBasicsTransformer.register()
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UserProfile.self, WorkExperience.self, Education.self,
            Project.self, ResumeTheme.self, JobPosting.self, GeneratedDocument.self
        ])
        let config = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
        return try! ModelContainer(for: schema, configurations: [config])
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(container)
        }
        .modelContainer(sharedModelContainer)
    }
}
