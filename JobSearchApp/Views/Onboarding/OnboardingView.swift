import SwiftUI
import SwiftData

// MARK: - ViewModel

@MainActor
final class OnboardingViewModel: ObservableObject {
    enum Step: Int, CaseIterable {
        case welcome, name, email, claudeKey, profileDetails, tavilyKey
    }

    @Published var currentStep: Step = .welcome

    // Step 1 — Name
    @Published var firstName = ""
    @Published var lastName = ""

    // Step 2 — Contact
    @Published var email = ""
    @Published var phone = ""
    @Published var location = ""

    // Step 3 — Claude API key
    @Published var claudeKey = ""

    // Step 4 — Profile details
    @Published var currentJobTitle = ""
    @Published var currentCompany = ""
    @Published var skillsText = ""          // comma-separated, split on save
    @Published var educationInstitution = ""
    @Published var educationDegree = ""
    @Published var educationField = ""

    // Step 5 — Tavily key
    @Published var tavilyKey = ""

    var fullName: String {
        "\(firstName.trimmingCharacters(in: .whitespaces)) \(lastName.trimmingCharacters(in: .whitespaces))"
            .trimmingCharacters(in: .whitespaces)
    }

    var canAdvanceFromName: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var canAdvanceFromEmail: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        !location.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func advance() {
        guard let next = Step(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = next
    }

    func saveProfile(context: ModelContext, coordinator: OnboardingCoordinator, container: AppContainer) {
        if !claudeKey.trimmingCharacters(in: .whitespaces).isEmpty {
            try? KeychainManager.shared.save(claudeKey, forKey: KeychainKeys.anthropicAPIKey)
        }
        if !tavilyKey.trimmingCharacters(in: .whitespaces).isEmpty {
            try? KeychainManager.shared.save(tavilyKey, forKey: KeychainKeys.tavilyAPIKey)
        }
        container.refreshLLMService()

        let basics = ProfileBasics(
            name: fullName.isEmpty ? firstName : fullName,
            email: email.trimmingCharacters(in: .whitespaces),
            phone: phone.trimmingCharacters(in: .whitespaces).isEmpty ? nil
                   : phone.trimmingCharacters(in: .whitespaces),
            location: location.trimmingCharacters(in: .whitespaces),
            linkedIn: nil, github: nil, website: nil
        )
        let profile = UserProfile(basics: basics)

        let parsedSkills = skillsText
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        profile.skills = parsedSkills

        context.insert(profile)

        if !currentJobTitle.trimmingCharacters(in: .whitespaces).isEmpty ||
           !currentCompany.trimmingCharacters(in: .whitespaces).isEmpty {
            let exp = WorkExperience(
                company: currentCompany.trimmingCharacters(in: .whitespaces).isEmpty
                    ? "Unknown" : currentCompany.trimmingCharacters(in: .whitespaces),
                title: currentJobTitle.trimmingCharacters(in: .whitespaces).isEmpty
                    ? "Unknown" : currentJobTitle.trimmingCharacters(in: .whitespaces),
                startDate: Date(),
                isCurrent: true
            )
            exp.profile = profile
            profile.workHistory.append(exp)
            context.insert(exp)
        }

        if !educationInstitution.trimmingCharacters(in: .whitespaces).isEmpty {
            let edu = Education(
                institution: educationInstitution.trimmingCharacters(in: .whitespaces),
                degree: educationDegree.trimmingCharacters(in: .whitespaces).isEmpty
                    ? "Degree" : educationDegree.trimmingCharacters(in: .whitespaces),
                field: educationField.trimmingCharacters(in: .whitespaces).isEmpty
                    ? "Unknown" : educationField.trimmingCharacters(in: .whitespaces)
            )
            edu.profile = profile
            profile.education.append(edu)
            context.insert(edu)
        }

        try? context.save()
        coordinator.completeOnboarding()
    }
}

// MARK: - View

struct OnboardingView: View {
    @StateObject private var vm = OnboardingViewModel()
    @EnvironmentObject private var coordinator: OnboardingCoordinator
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            stepContent
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch vm.currentStep {
        case .welcome:
            WelcomeView(onStart: { vm.advance() })
        case .name:
            NameStepView(vm: vm)
        case .email:
            EmailStepView(vm: vm)
        case .claudeKey:
            ClaudeKeyStepView(vm: vm)
        case .profileDetails:
            ProfileDetailsStepView(vm: vm)
        case .tavilyKey:
            TavilyKeyStepView(vm: vm) {
                vm.saveProfile(context: modelContext, coordinator: coordinator, container: container)
            }
        }
    }
}
