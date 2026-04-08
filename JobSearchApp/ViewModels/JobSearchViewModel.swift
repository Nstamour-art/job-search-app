import Foundation
import SwiftData

@MainActor
final class JobSearchViewModel: ObservableObject {
    @Published var isSearching = false
    @Published var progress: String?
    @Published var errorMessage: String?

    func search(
        query: String,
        tavilyKey: String,
        llmService: any LLMService,
        profile: UserProfile?,
        context: ModelContext,
        sessionOverride: (any URLSessionProtocol)? = nil
    ) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }
        guard !tavilyKey.isEmpty else {
            errorMessage = "Tavily API key not configured. Add it in Settings."
            return
        }
        guard let profile else {
            errorMessage = "No profile found. Complete onboarding first."
            return
        }

        isSearching = true
        progress = "Searching for jobs…"
        errorMessage = nil
        defer { isSearching = false; progress = nil }

        let session = sessionOverride ?? URLSession.shared
        let tavilyService = TavilyService(apiKey: tavilyKey, session: session)
        let analyzer = JobAnalysisService(llm: llmService)

        do {
            let results = try await tavilyService.search(query: trimmedQuery)
            for (index, result) in results.enumerated() {
                progress = "Analyzing job \(index + 1) of \(results.count)…"
                let parsed = try await analyzer.analyze(jobText: result.content, profile: profile)
                let posting = JobPosting(
                    url: result.url,
                    title: parsed.title,
                    company: parsed.company,
                    location: parsed.location,
                    scrapedDescription: result.content,
                    priorityScore: parsed.priorityScore,
                    priorityReasoning: parsed.priorityReasoning,
                    status: .saved,
                    dateFound: Date()
                )
                context.insert(posting)
                try? context.save()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
