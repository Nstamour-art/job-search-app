import Foundation

enum InputValidator {

    // MARK: - Name

    /// Trims and collapses internal whitespace for first/last names.
    /// Returns sanitized components and the merged full name ("first last").
    static func sanitizedName(first: String, last: String) -> (first: String, last: String, full: String) {
        let f = collapseWhitespace(first)
        let l = collapseWhitespace(last)
        let full = [f, l].filter { !$0.isEmpty }.joined(separator: " ")
        return (f, l, full)
    }

    // MARK: - Email

    /// RFC-5322-lite check: `<local>@<domain>.<tld>`, case-insensitive.
    static func isValidEmail(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let pattern = #"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }

    /// Lowercase and trim for storage.
    static func normalizeEmail(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // MARK: - Phone

    /// Strips non-digit characters, returns raw digit string.
    static func phoneDigits(_ value: String) -> String {
        value.filter(\.isWholeNumber)
    }

    /// Validates that digit string is 7–15 characters (ITU-T E.164 range).
    static func isValidPhoneDigits(_ digits: String) -> Bool {
        (7...15).contains(digits.count)
    }

    /// Formats a digit string for display:
    /// 10 digits -> (XXX) XXX-XXXX; 11 starting with 1 -> +1 (XXX) XXX-XXXX; otherwise groups of 3.
    static func formattedPhone(_ digits: String) -> String {
        if digits.count == 10 {
            let a = digits.prefix(3)
            let b = digits.dropFirst(3).prefix(3)
            let c = digits.dropFirst(6)
            return "(\(a)) \(b)-\(c)"
        }
        if digits.count == 11, digits.hasPrefix("1") {
            let rest = String(digits.dropFirst())
            return "+1 " + formattedPhone(rest)
        }
        // Generic grouping for other lengths
        return stride(from: 0, to: digits.count, by: 3)
            .map { i -> String in
                let start = digits.index(digits.startIndex, offsetBy: i)
                let end = digits.index(start, offsetBy: min(3, digits.count - i))
                return String(digits[start..<end])
            }
            .joined(separator: " ")
    }

    // MARK: - Location

    /// Trims and collapses internal whitespace.
    static func normalizeLocation(_ value: String) -> String {
        collapseWhitespace(value)
    }

    /// Non-empty with at least two tokens (separated by space or comma).
    static func isValidLocation(_ value: String) -> Bool {
        let normalized = normalizeLocation(value)
        guard !normalized.isEmpty else { return false }
        let tokens = normalized
            .components(separatedBy: CharacterSet(charactersIn: ", "))
            .filter { !$0.isEmpty }
        return tokens.count >= 2
    }

    // MARK: - Internal

    private static func collapseWhitespace(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
