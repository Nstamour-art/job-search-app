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

    init(profile: UserProfile) {
        self.profile = profile
        _name     = State(initialValue: profile.basics.name)
        _email    = State(initialValue: profile.basics.email)
        _phone    = State(initialValue: profile.basics.phone ?? "")
        _location = State(initialValue: profile.basics.location)
        _linkedIn = State(initialValue: profile.basics.linkedIn ?? "")
        _github   = State(initialValue: profile.basics.github ?? "")
        _website  = State(initialValue: profile.basics.website ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Contact") {
                    TextField("Name", text: $name)
                    TextField("Email", text: $email).keyboardType(.emailAddress)
                    TextField("Phone", text: $phone).keyboardType(.phonePad)
                    TextField("Location", text: $location)
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
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
        }
    }

    private func save() {
        profile.basics = ProfileBasics(
            name: name,
            email: email,
            phone: phone.isEmpty ? nil : phone,
            location: location,
            linkedIn: linkedIn.isEmpty ? nil : linkedIn,
            github: github.isEmpty ? nil : github,
            website: website.isEmpty ? nil : website
        )
        try? modelContext.save()
        dismiss()
    }
}
