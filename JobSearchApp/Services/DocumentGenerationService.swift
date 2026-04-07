import Foundation
import SwiftData

@MainActor
final class DocumentGenerationService {
    private let llm: any LLMService

    init(llm: any LLMService) {
        self.llm = llm
    }

    func generateResume(profile: UserProfile, job: JobPosting) async throws -> String {
        let system = """
        You are a professional resume writer. Generate a clean, ATS-friendly resume in plain text.
        Tailor it to the job posting. Format sections clearly:
        CONTACT, SUMMARY, EXPERIENCE, EDUCATION, SKILLS, PROJECTS.
        Return only the resume text — no explanation, no markdown.
        """
        return try await llm.complete(prompt: buildPrompt(profile: profile, job: job), system: system)
    }

    func generateCoverLetter(profile: UserProfile, job: JobPosting) async throws -> String {
        let system = """
        You are a professional cover letter writer. Generate a concise, compelling cover letter in plain text.
        Tailor it to the specific job and company. Include: opening paragraph, 2–3 body paragraphs,
        closing paragraph, sign-off. Return only the cover letter text — no explanation, no markdown.
        """
        return try await llm.complete(prompt: buildPrompt(profile: profile, job: job), system: system)
    }

    // MARK: - Private

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter
    }()

    private func buildPrompt(profile: UserProfile, job: JobPosting) -> String {
        var lines: [String] = []

        lines.append("=== CANDIDATE PROFILE ===")
        lines.append("Name: \(profile.basics.name)")
        lines.append("Email: \(profile.basics.email)")
        if let phone = profile.basics.phone { lines.append("Phone: \(phone)") }
        lines.append("Location: \(profile.basics.location)")
        if let linkedIn = profile.basics.linkedIn { lines.append("LinkedIn: \(linkedIn)") }
        if let github = profile.basics.github { lines.append("GitHub: \(github)") }

        let sorted = profile.workHistory.sorted { $0.startDate > $1.startDate }
        if !sorted.isEmpty {
            lines.append("\nWORK EXPERIENCE:")
            for exp in sorted {
                let start = dateFormatter.string(from: exp.startDate)
                let end = exp.isCurrent ? "Present" : exp.endDate.map { dateFormatter.string(from: $0) } ?? ""
                lines.append("• \(exp.title) at \(exp.company) (\(start)–\(end))")
                for bullet in exp.bullets { lines.append("  - \(bullet)") }
            }
        }

        if !profile.education.isEmpty {
            lines.append("\nEDUCATION:")
            for edu in profile.education {
                let grad = edu.graduationDate.map { dateFormatter.string(from: $0) } ?? ""
                lines.append("• \(edu.degree) in \(edu.field) — \(edu.institution) (\(grad))")
            }
        }

        if !profile.skills.isEmpty {
            lines.append("\nSKILLS: \(profile.skills.joined(separator: ", "))")
        }

        if !profile.projects.isEmpty {
            lines.append("\nPROJECTS:")
            for proj in profile.projects {
                lines.append("• \(proj.name): \(proj.projectDescription)")
                for bullet in proj.bullets { lines.append("  - \(bullet)") }
            }
        }

        lines.append("\n=== JOB POSTING ===")
        lines.append("Title: \(job.title)")
        lines.append("Company: \(job.company)")
        lines.append("Location: \(job.location)")
        lines.append("\n\(job.scrapedDescription)")

        return lines.joined(separator: "\n")
    }
}
