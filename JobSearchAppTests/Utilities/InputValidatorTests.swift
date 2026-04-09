import Testing
@testable import JobSearchApp

struct InputValidatorTests {

    // MARK: - Name

    @Test("sanitizedName trims and collapses whitespace")
    func nameSanitization() {
        let result = InputValidator.sanitizedName(first: "  Jane   ", last: "  Doe  ")
        #expect(result.first == "Jane")
        #expect(result.last == "Doe")
        #expect(result.full == "Jane Doe")
    }

    @Test("sanitizedName collapses internal spaces")
    func nameInternalSpaces() {
        let result = InputValidator.sanitizedName(first: "Mary  Jane", last: "Van   Der Berg")
        #expect(result.first == "Mary Jane")
        #expect(result.last == "Van Der Berg")
        #expect(result.full == "Mary Jane Van Der Berg")
    }

    @Test("sanitizedName handles empty last name")
    func nameLastEmpty() {
        let result = InputValidator.sanitizedName(first: "Jane", last: "  ")
        #expect(result.last == "")
        #expect(result.full == "Jane")
    }

    // MARK: - Email

    @Test("valid emails accepted", arguments: [
        "test@example.com",
        "user.name+tag@domain.co",
        "a@b.cd"
    ])
    func validEmail(email: String) {
        #expect(InputValidator.isValidEmail(email))
    }

    @Test("invalid emails rejected", arguments: [
        "",
        "not-an-email",
        "@missing-local.com",
        "missing@.com",
        "missing@domain"
    ])
    func invalidEmail(email: String) {
        #expect(!InputValidator.isValidEmail(email))
    }

    @Test("normalizeEmail lowercases and trims")
    func emailNormalize() {
        #expect(InputValidator.normalizeEmail("  Test@Example.COM  ") == "test@example.com")
    }

    // MARK: - Phone

    @Test("phoneDigits strips non-digits")
    func phoneStrip() {
        #expect(InputValidator.phoneDigits("(416) 555-0100") == "4165550100")
    }

    @Test("valid phone digits accepted", arguments: ["1234567", "4165550100", "123456789012345"])
    func validPhone(digits: String) {
        #expect(InputValidator.isValidPhoneDigits(digits))
    }

    @Test("invalid phone digits rejected", arguments: ["123456", "1234567890123456"])
    func invalidPhone(digits: String) {
        #expect(!InputValidator.isValidPhoneDigits(digits))
    }

    @Test("formattedPhone formats 10 digits as (XXX) XXX-XXXX")
    func phone10() {
        #expect(InputValidator.formattedPhone("4165550100") == "(416) 555-0100")
    }

    @Test("formattedPhone formats 11 digits starting with 1")
    func phone11() {
        #expect(InputValidator.formattedPhone("14165550100") == "+1 (416) 555-0100")
    }

    // MARK: - Location

    @Test("normalizeLocation trims and collapses")
    func locationNormalize() {
        #expect(InputValidator.normalizeLocation("  Toronto ,   ON  ") == "Toronto , ON")
    }

    @Test("valid locations accepted", arguments: ["Toronto, ON", "New York", "San Francisco CA"])
    func validLocation(loc: String) {
        #expect(InputValidator.isValidLocation(loc))
    }

    @Test("invalid locations rejected", arguments: ["", "   ", "Toronto"])
    func invalidLocation(loc: String) {
        #expect(!InputValidator.isValidLocation(loc))
    }
}
