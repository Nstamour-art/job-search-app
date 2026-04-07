import SwiftUI
import SwiftData

struct GenerateDocumentsView: View {
    let job: JobPosting
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var container: AppContainer
    @Query private var profiles: [UserProfile]

    enum GenerationTarget: String, CaseIterable, Identifiable {
        case resume = "Resume"
        case coverLetter = "Cover Letter"
        case both = "Both"
        var id: String { rawValue }
    }

    @State private var target: GenerationTarget = .both
    @State private var isGenerating = false
    @State private var errorMessage: String?

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            Form {
                Section("Document Type") {
                    Picker("Document", selection: $target) {
                        ForEach(GenerationTarget.allCases) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if isGenerating {
                    Section {
                        ProgressView("Generating with AI…").frame(maxWidth: .infinity)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red).font(.caption)
                    }
                }

                Section {
                    Button("Generate") { Task { await generate() } }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                        .disabled(isGenerating || profile == nil)
                }
            }
            .navigationTitle("Generate Documents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Actions

    private func generate() async {
        guard let profile else {
            errorMessage = "No profile found. Complete onboarding first."
            return
        }
        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }
        let service = DocumentGenerationService(llm: container.llmService)
        do {
            switch target {
            case .resume:
                try await generateAndSave(type: .resume, using: service, profile: profile)
            case .coverLetter:
                try await generateAndSave(type: .coverLetter, using: service, profile: profile)
            case .both:
                try await generateAndSave(type: .resume, using: service, profile: profile)
                try await generateAndSave(type: .coverLetter, using: service, profile: profile)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func generateAndSave(
        type: DocumentType,
        using service: DocumentGenerationService,
        profile: UserProfile
    ) async throws {
        let text: String
        switch type {
        case .resume:        text = try await service.generateResume(profile: profile, job: job)
        case .coverLetter:   text = try await service.generateCoverLetter(profile: profile, job: job)
        }
        let doc = GeneratedDocument(type: type, richContent: Data(text.utf8), linkedJob: job)
        modelContext.insert(doc)
        try modelContext.save()
    }
}
