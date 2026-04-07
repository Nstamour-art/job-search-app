import SwiftUI
import SwiftData

// MARK: - ViewModel

@MainActor
final class OnboardingViewModel: ObservableObject {
    enum Step: Int, CaseIterable {
        case welcome, basics, workHistory, education, skills, projects, theme
    }

    @Published var currentStep: Step = .welcome
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Text inputs — one per section
    @Published var basicsInput = ""
    @Published var workInput = ""
    @Published var educationInput = ""
    @Published var skillsInput = ""
    @Published var projectsInput = ""

    // Parsed results
    @Published var parsedBasics: ParsedBasics?
    @Published var parsedWork: [ParsedWorkExperience] = []
    @Published var parsedEducation: [ParsedEducation] = []
    @Published var parsedSkills: [String] = []
    @Published var parsedProjects: [ParsedProject] = []
    @Published var selectedTheme: ThemeName = .modern

    private let parseService: ProfileParseService

    init(parseService: ProfileParseService) {
        self.parseService = parseService
    }

    func advance() {
        guard let next = Step(rawValue: currentStep.rawValue + 1) else { return }
        errorMessage = nil
        currentStep = next
    }

    func parseBasics() async {
        await run { [self] in parsedBasics = try await parseService.parseBasics(from: basicsInput) }
    }

    func parseWork() async {
        await run { [self] in parsedWork = try await parseService.parseWorkExperiences(from: workInput) }
    }

    func parseEducation() async {
        await run { [self] in parsedEducation = try await parseService.parseEducation(from: educationInput) }
    }

    func parseSkills() async {
        await run { [self] in parsedSkills = try await parseService.parseSkills(from: skillsInput) }
    }

    func parseProjects() async {
        await run { [self] in parsedProjects = try await parseService.parseProjects(from: projectsInput) }
    }

    func saveProfile(context: ModelContext, coordinator: OnboardingCoordinator) {
        guard let basics = parsedBasics else { return }

        let profileBasics = ProfileBasics(
            name: basics.name,
            email: basics.email,
            phone: basics.phone,
            location: basics.location,
            linkedIn: basics.linkedIn,
            github: basics.github,
            website: basics.website
        )
        let theme = ResumeTheme(name: selectedTheme, accentColor: "#1E3A5F", bodyFontSize: 11.0)
        let profile = UserProfile(basics: profileBasics, resumeTheme: theme)
        profile.skills = parsedSkills
        context.insert(profile)

        for p in parsedWork {
            let exp = WorkExperience(
                company: p.company,
                title: p.title,
                startDate: yearMonth(p.startDate) ?? Date(),
                endDate: p.endDate.flatMap { yearMonth($0) },
                isCurrent: p.isCurrent,
                bullets: p.bullets
            )
            exp.profile = profile
            profile.workHistory.append(exp)
            context.insert(exp)
        }

        for p in parsedEducation {
            let edu = Education(
                institution: p.institution,
                degree: p.degree,
                field: p.field,
                graduationDate: p.graduationDate.flatMap { yearMonth($0) }
            )
            edu.profile = profile
            profile.education.append(edu)
            context.insert(edu)
        }

        for p in parsedProjects {
            let proj = Project(
                name: p.name,
                projectDescription: p.description,
                url: p.url,
                bullets: p.bullets
            )
            proj.profile = profile
            profile.projects.append(proj)
            context.insert(proj)
        }

        try? context.save()
        coordinator.completeOnboarding()
    }

    // MARK: - Private helpers

    private func run(_ block: @escaping () async throws -> Void) async {
        isLoading = true
        errorMessage = nil
        do { try await block() } catch { errorMessage = error.localizedDescription }
        isLoading = false
    }

    /// Converts "YYYY-MM" to a Date at the first of that month.
    private func yearMonth(_ string: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.date(from: string)
    }
}

// MARK: - View

struct OnboardingView: View {
    @StateObject private var vm: OnboardingViewModel
    @EnvironmentObject private var coordinator: OnboardingCoordinator
    @Environment(\.modelContext) private var modelContext

    init(llmService: any LLMService) {
        _vm = StateObject(wrappedValue: OnboardingViewModel(
            parseService: ProfileParseService(llm: llmService)
        ))
    }

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
        case .basics:
            BasicsStepView(vm: vm)
        case .workHistory:
            WorkHistoryStepView(vm: vm)
        case .education:
            EducationStepView(vm: vm)
        case .skills:
            SkillsStepView(vm: vm)
        case .projects:
            ProjectsStepView(vm: vm)
        case .theme:
            Text("Theme — coming in Task 5")   // replaced in Task 5
        }
    }
}
