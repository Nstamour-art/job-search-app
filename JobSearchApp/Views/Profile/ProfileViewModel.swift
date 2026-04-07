import Foundation
import SwiftData

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var profile: UserProfile?

    func load(context: ModelContext) {
        profile = try? context.fetch(FetchDescriptor<UserProfile>()).first
    }

    func deleteWorkExperience(_ exp: WorkExperience, context: ModelContext) {
        context.delete(exp)
        try? context.save()
        load(context: context)
    }

    func deleteEducation(_ edu: Education, context: ModelContext) {
        context.delete(edu)
        try? context.save()
        load(context: context)
    }

    func deleteProject(_ proj: Project, context: ModelContext) {
        context.delete(proj)
        try? context.save()
        load(context: context)
    }
}
