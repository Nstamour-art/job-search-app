import SwiftUI

struct EducationFormView: View {
    let profile: UserProfile
    let existing: Education?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var institution: String
    @State private var degree: String
    @State private var field: String
    @State private var graduationDate: Date
    @State private var hasGradDate: Bool

    init(profile: UserProfile, existing: Education?) {
        self.profile = profile
        self.existing = existing
        _institution    = State(initialValue: existing?.institution ?? "")
        _degree         = State(initialValue: existing?.degree ?? "")
        _field          = State(initialValue: existing?.field ?? "")
        _graduationDate = State(initialValue: existing?.graduationDate ?? Date())
        _hasGradDate    = State(initialValue: existing?.graduationDate != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("School") {
                    TextField("Institution", text: $institution)
                    TextField("Degree (e.g. Bachelor of Science)", text: $degree)
                    TextField("Field of Study", text: $field)
                }
                Section("Graduation") {
                    Toggle("Has graduation date", isOn: $hasGradDate)
                    if hasGradDate {
                        DatePicker("Date", selection: $graduationDate, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle(existing == nil ? "Add Education" : "Edit Education")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
        }
    }

    private func save() {
        if let edu = existing {
            edu.institution    = institution
            edu.degree         = degree
            edu.field          = field
            edu.graduationDate = hasGradDate ? graduationDate : nil
        } else {
            let edu = Education(
                institution: institution, degree: degree, field: field,
                graduationDate: hasGradDate ? graduationDate : nil
            )
            edu.profile = profile
            profile.education.append(edu)
            modelContext.insert(edu)
        }
        try? modelContext.save()
        dismiss()
    }
}
