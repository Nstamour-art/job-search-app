import SwiftUI
import SwiftData

@main
struct JobSearchApp: App {
    let sharedModelContainer: ModelContainer

    init() {
        ProfileBasicsTransformer.register()
        let schema = Schema([
            UserProfile.self,
            WorkExperience.self,
            Education.self,
            Project.self,
            ResumeTheme.self,
            JobPosting.self,
            GeneratedDocument.self
        ])
        let config = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .automatic
        )
        do {
            sharedModelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(sharedModelContainer)
    }
}
