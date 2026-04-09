import SwiftUI

struct EditBasicsView: View {
    let profile: UserProfile
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var email: String
    @State private var phone: String
    @State private var location: String
    @State private var linkedIn: String
    @State private var github: String
    @State private var website: String

    // Validation
    @State private var nameError: String?
    @State private var emailError: String?
    @State private var phoneError: String?
    @State private var locationError: String?
    @State private var didAttemptSave = false

    // Stored originals for change detection
    private let originalName: String
    private let originalEmail: String
    private let originalPhone: String
    private let originalLocation: String
    private let originalLinkedIn: String
    private let originalGithub: String
    private let originalWebsite: String

    init(profile: UserProfile) {
        self.profile = profile
        let n = profile.basics.name
        let e = profile.basics.email
        let p = profile.basics.phone ?? ""
        let l = profile.basics.location
        let li = profile.basics.linkedIn ?? ""
        let g = profile.basics.github ?? ""
        let w = profile.basics.website ?? ""
        _name     = State(initialValue: n)
        _email    = State(initialValue: e)
        _phone    = State(initialValue: p)
        _location = State(initialValue: l)
        _linkedIn = State(initialValue: li)
        _github   = State(initialValue: g)
        _website  = State(initialValue: w)
        originalName = n
        originalEmail = e
        originalPhone = p
        originalLocation = l
        originalLinkedIn = li
        originalGithub = g
        originalWebsite = w
    }

    private var hasChanges: Bool {
        name != originalName || email != originalEmail ||
        phone != originalPhone || location != originalLocation ||
        linkedIn != originalLinkedIn || github != originalGithub ||
        website != originalWebsite
    }

    private var isValid: Bool {
        nameError == nil && emailError == nil &&
        phoneError == nil && locationError == nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Contact") {
                    ValidatedField(
                        label: "Name",
                        error: didAttemptSave ? nameError : nil
                    ) {
                        TextField("Jane Doe", text: $name)
                            .textContentType(.name)
                    }
                    ValidatedField(
                        label: "Email",
                        error: didAttemptSave ? emailError : nil
                    ) {
                        TextField("jane@example.com", text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    ValidatedField(
                        label: "Phone",
                        error: didAttemptSave ? phoneError : nil
                    ) {
                        TextField("(416) 555-0100", text: phoneDisplay)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                    }
                    ValidatedField(
                        label: "Location",
                        error: didAttemptSave ? locationError : nil
                    ) {
                        TextField("Toronto, ON", text: $location)
                    }
                }
                Section("Links") {
                    TextField("LinkedIn URL", text: $linkedIn)
                    TextField("GitHub URL", text: $github)
                    TextField("Website URL", text: $website)
                }
            }
            .navigationTitle("Edit Contact Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { attemptSave() }
                        .disabled(!hasChanges || (didAttemptSave && !isValid))
                }
            }
            .onChange(of: name) { if didAttemptSave { validate() } }
            .onChange(of: email) { if didAttemptSave { validate() } }
            .onChange(of: phone) { if didAttemptSave { validate() } }
            .onChange(of: location) { if didAttemptSave { validate() } }
        }
    }

    // MARK: - Phone display binding

    private var phoneDisplay: Binding<String> {
        Binding(
            get: {
                let digits = InputValidator.phoneDigits(phone)
                return digits.isEmpty ? "" : InputValidator.formattedPhone(digits)
            },
            set: { newValue in
                phone = InputValidator.phoneDigits(newValue)
            }
        )
    }

    // MARK: - Validation

    private func validate() {
        // Name: split at first space (or treat whole string as first name)
        let parts = name.components(separatedBy: " ")
        let first = parts.first ?? ""
        let last = parts.dropFirst().joined(separator: " ")
        let sanitized = InputValidator.sanitizedName(first: first, last: last)
        nameError = sanitized.full.isEmpty ? "Enter your name." : nil

        emailError = InputValidator.isValidEmail(email) ? nil : "Enter a valid email."

        let digits = InputValidator.phoneDigits(phone)
        if digits.isEmpty {
            phoneError = nil
        } else {
            phoneError = InputValidator.isValidPhoneDigits(digits) ? nil : "Enter a valid phone number."
        }

        locationError = InputValidator.isValidLocation(location) ? nil : "Enter your city and region."
    }

    // MARK: - Save

    private func attemptSave() {
        didAttemptSave = true
        validate()
        guard isValid else { return }

        // Normalize
        let parts = name.components(separatedBy: " ")
        let first = parts.first ?? ""
        let last = parts.dropFirst().joined(separator: " ")
        let sanitized = InputValidator.sanitizedName(first: first, last: last)
        let normalizedEmail = InputValidator.normalizeEmail(email)
        let normalizedPhone = InputValidator.phoneDigits(phone)
        let normalizedLocation = InputValidator.normalizeLocation(location)

        profile.basics = ProfileBasics(
            name: sanitized.full,
            email: normalizedEmail,
            phone: normalizedPhone.isEmpty ? nil : normalizedPhone,
            location: normalizedLocation,
            linkedIn: linkedIn.isEmpty ? nil : linkedIn,
            github: github.isEmpty ? nil : github,
            website: website.isEmpty ? nil : website
        )
        try? modelContext.save()
        dismiss()
    }
}
