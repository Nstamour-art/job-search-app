import SwiftUI
import SwiftData

// MARK: - ViewModel

@Observable @MainActor final class OnboardingViewModel {
    enum Step: Int, CaseIterable {
        case welcome, name, email, claudeKey, profileDetails, tavilyKey
    }

    var currentStep: Step = .welcome

    // Step 1 — Name
    var firstName = ""
    var lastName = ""

    // Step 2 — Contact
    var email = ""
    var phone = ""
    var location = ""

    // Step 3 — Claude API key
    var claudeKey = ""

    // Step 4 — Profile details
    var currentJobTitle = ""
    var currentCompany = ""
    var skillsText = ""          // comma-separated, split on save
    var educationInstitution = ""
    var educationDegree = ""
    var educationField = ""

    // Step 5 — Tavily key
    var tavilyKey = ""

    // MARK: - Inline validation errors (nil == valid)

    var nameError: String?
    var lastNameError: String?
    var emailError: String?
    var phoneError: String?
    var locationError: String?

    /// Whether we've attempted to submit the current step at least once.
    /// Controls when inline errors start showing.
    var didAttemptSubmit = false

    // MARK: - Derived

    var fullName: String {
        InputValidator.sanitizedName(first: firstName, last: lastName).full
    }

    var canAdvanceFromName: Bool {
        let sanitized = InputValidator.sanitizedName(first: firstName, last: lastName)
        return !sanitized.first.isEmpty && !sanitized.last.isEmpty
    }

    var canAdvanceFromEmail: Bool {
        InputValidator.isValidEmail(email) &&
        InputValidator.isValidLocation(location) &&
        phonePassesValidation
    }

    /// Phone is optional; valid when empty or when digits are in range.
    private var phonePassesValidation: Bool {
        let digits = InputValidator.phoneDigits(phone)
        return digits.isEmpty || InputValidator.isValidPhoneDigits(digits)
    }

    // MARK: - Validation triggers

    /// Revalidate name step fields; sets/clears error strings.
    func validateName() {
        let sanitized = InputValidator.sanitizedName(first: firstName, last: lastName)
        nameError = sanitized.first.isEmpty ? "Enter your first name." : nil
        lastNameError = sanitized.last.isEmpty ? "Enter your last name." : nil
    }

    /// Revalidate contact step fields.
    func validateContact() {
        emailError = InputValidator.isValidEmail(email) ? nil : "Enter a valid email."

        let digits = InputValidator.phoneDigits(phone)
        if digits.isEmpty {
            phoneError = nil
        } else {
            phoneError = InputValidator.isValidPhoneDigits(digits) ? nil : "Enter a valid phone number."
        }

        locationError = InputValidator.isValidLocation(location) ? nil : "Enter your city and region."
    }

    // MARK: - Navigation

    /// Attempt to advance; returns false if blocked by validation.
    @discardableResult
    func tryAdvance() -> Bool {
        didAttemptSubmit = true

        switch currentStep {
        case .name:
            validateName()
            guard canAdvanceFromName else { return false }
        case .email:
            validateContact()
            guard canAdvanceFromEmail else { return false }
        default:
            break
        }
        advance()
        didAttemptSubmit = false
        return true
    }

    func advance() {
        guard let next = Step(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = next
    }

    // MARK: - Sanitize before save

    /// Normalize all user-entered values before persisting.
    private func sanitizeAll() {
        let name = InputValidator.sanitizedName(first: firstName, last: lastName)
        firstName = name.first
        lastName = name.last
        email = InputValidator.normalizeEmail(email)
        let digits = InputValidator.phoneDigits(phone)
        phone = digits
        location = InputValidator.normalizeLocation(location)
    }

    func saveProfile(context: ModelContext, coordinator: OnboardingCoordinator, container: AppContainer) {
        sanitizeAll()

        if !claudeKey.trimmingCharacters(in: .whitespaces).isEmpty {
            try? KeychainManager.shared.save(claudeKey.trimmingCharacters(in: .whitespaces),
                                             forKey: KeychainKeys.anthropicAPIKey)
        }
        if !tavilyKey.trimmingCharacters(in: .whitespaces).isEmpty {
            try? KeychainManager.shared.save(tavilyKey.trimmingCharacters(in: .whitespaces),
                                             forKey: KeychainKeys.tavilyAPIKey)
        }
        container.refreshLLMService()

        let basics = ProfileBasics(
            name: fullName.isEmpty ? firstName : fullName,
            email: email,
            phone: phone.isEmpty ? nil : phone,
            location: location,
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
    @State private var vm = OnboardingViewModel()
    @Environment(OnboardingCoordinator.self) private var coordinator
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
