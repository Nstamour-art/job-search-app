import Foundation
import SwiftData

struct ParsedJobPosting: Decodable {
    var title: String
    var company: String
    var location: String
    var priorityScore: Int         // 1–5
    var priorityReasoning: String
}

final class JobAnalysisService {
    private let llm: any LLMService

    init(llm: any LLMService) {
        self.llm = llm
    }

    func analyze(jobText: String, profile: UserProfile) async throws -> ParsedJobPosting {
        let system = buildSystem(profile: profile)
        let raw = try await llm.complete(prompt: jobText, system: system)
        return try decode(from: raw)
    }

    // MARK: - Private

    private func buildSystem(profile: UserProfile) -> String {
        let skills = profile.skills.prefix(20).joined(separator: ", ")
        let recentRole = profile.workHistory
            .sorted { $0.startDate > $1.startDate }
            .first
        let roleContext = recentRole.map {
            "Most recent role: \($0.title) at \($0.company)."
        } ?? ""
        return """
        You are a career coach helping a job seeker prioritize job postings.
        Candidate profile — skills: \(skills.isEmpty ? "not specified" : skills). \(roleContext)
        Analyze the following job posting and return ONLY valid JSON (no markdown, no explanation):
        {"title":"string","company":"string","location":"string","priorityScore":1-5,"priorityReasoning":"string"}
        Priority scale: 1=poor fit, 2=weak, 3=moderate, 4=strong, 5=excellent.
        Consider skill overlap, seniority level, and location/remote fit.
        """
    }

    private func decode(from raw: String) throws -> ParsedJobPosting {
        let json = stripFences(from: raw)
        return try JSONDecoder().decode(ParsedJobPosting.self, from: Data(json.utf8))
    }

    private func stripFences(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```") else { return trimmed }
        var lines = trimmed.components(separatedBy: "\n")
        lines.removeFirst()
        if lines.last?.trimmingCharacters(in: .whitespaces) == "```" { lines.removeLast() }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
