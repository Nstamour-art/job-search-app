import Foundation

// MARK: - Intermediate parsed types (Decodable, not @Model)

struct ParsedBasics: Decodable {
    var name: String
    var email: String
    var phone: String?
    var location: String
    var linkedIn: String?
    var github: String?
    var website: String?
}

struct ParsedWorkExperience: Decodable {
    var company: String
    var title: String
    var startDate: String    // "YYYY-MM"
    var endDate: String?     // "YYYY-MM" or null
    var isCurrent: Bool
    var bullets: [String]
}

struct ParsedEducation: Decodable {
    var institution: String
    var degree: String
    var field: String
    var graduationDate: String?   // "YYYY-MM" or null
}

struct ParsedProject: Decodable {
    var name: String
    var description: String
    var url: String?
    var bullets: [String]
}

// MARK: - Service

final class ProfileParseService {
    private let llm: any LLMService

    init(llm: any LLMService) {
        self.llm = llm
    }

    func parseBasics(from text: String) async throws -> ParsedBasics {
        let system = """
        You are a career profile extractor. Extract contact information from the user's text.
        Return ONLY valid JSON matching this exact schema (no markdown, no explanation):
        {"name":"string","email":"string","phone":"string or null","location":"string",\
        "linkedIn":"string or null","github":"string or null","website":"string or null"}
        """
        let raw = try await llm.complete(prompt: text, system: system)
        return try decode(ParsedBasics.self, from: raw)
    }

    func parseWorkExperiences(from text: String) async throws -> [ParsedWorkExperience] {
        let system = """
        You are a career profile extractor. Extract all work experiences from the user's text.
        Return ONLY valid JSON array (no markdown, no explanation):
        [{"company":"string","title":"string","startDate":"YYYY-MM",\
        "endDate":"YYYY-MM or null","isCurrent":true or false,"bullets":["string"]}]
        If no work experience found, return [].
        """
        let raw = try await llm.complete(prompt: text, system: system)
        return try decode([ParsedWorkExperience].self, from: raw)
    }

    func parseEducation(from text: String) async throws -> [ParsedEducation] {
        let system = """
        You are a career profile extractor. Extract all education entries from the user's text.
        Return ONLY valid JSON array (no markdown, no explanation):
        [{"institution":"string","degree":"string","field":"string","graduationDate":"YYYY-MM or null"}]
        If no education found, return [].
        """
        let raw = try await llm.complete(prompt: text, system: system)
        return try decode([ParsedEducation].self, from: raw)
    }

    func parseSkills(from text: String) async throws -> [String] {
        let system = """
        You are a career profile extractor. Extract a list of skills from the user's text.
        Return ONLY valid JSON array of strings (no markdown, no explanation): ["skill1","skill2"]
        If no skills found, return [].
        """
        let raw = try await llm.complete(prompt: text, system: system)
        return try decode([String].self, from: raw)
    }

    func parseProjects(from text: String) async throws -> [ParsedProject] {
        let system = """
        You are a career profile extractor. Extract all projects from the user's text.
        Return ONLY valid JSON array (no markdown, no explanation):
        [{"name":"string","description":"string","url":"string or null","bullets":["string"]}]
        If no projects found, return [].
        """
        let raw = try await llm.complete(prompt: text, system: system)
        return try decode([ParsedProject].self, from: raw)
    }

    // MARK: - Helpers

    /// Strips markdown code fences (```json ... ```) if Claude wraps the response.
    private func stripFences(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```") else { return trimmed }
        let lines = trimmed.components(separatedBy: "\n")
        let body = lines.dropFirst().dropLast().joined(separator: "\n")
        return body.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func decode<T: Decodable>(_ type: T.Type, from raw: String) throws -> T {
        let json = stripFences(from: raw)
        return try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }
}
