import SwiftUI

struct WorkExperienceFormView: View {
    let profile: UserProfile
    let existing: WorkExperience?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var company: String
    @State private var title: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isCurrent: Bool
    @State private var bulletsText: String  // one bullet per line

    init(profile: UserProfile, existing: WorkExperience?) {
        self.profile = profile
        self.existing = existing
        _company     = State(initialValue: existing?.company ?? "")
        _title       = State(initialValue: existing?.title ?? "")
        _startDate   = State(initialValue: existing?.startDate ?? Date())
        _endDate     = State(initialValue: existing?.endDate ?? Date())
        _isCurrent   = State(initialValue: existing?.isCurrent ?? false)
        _bulletsText = State(initialValue: existing?.bullets.joined(separator: "\n") ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Role") {
                    TextField("Company", text: $company)
                    TextField("Job Title", text: $title)
                }
                Section("Dates") {
                    DatePicker("Start", selection: $startDate, displayedComponents: .date)
                    Toggle("Current Role", isOn: $isCurrent)
                    if !isCurrent {
                        DatePicker("End", selection: $endDate, displayedComponents: .date)
                    }
                }
                Section {
                    TextEditor(text: $bulletsText).frame(minHeight: 100)
                } header: { Text("Bullet Points") } footer: { Text("One bullet per line.") }
            }
            .navigationTitle(existing == nil ? "Add Experience" : "Edit Experience")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
        }
    }

    private func save() {
        let bullets = bulletsText
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if let exp = existing {
            exp.company   = company
            exp.title     = title
            exp.startDate = startDate
            exp.endDate   = isCurrent ? nil : endDate
            exp.isCurrent = isCurrent
            exp.bullets   = bullets
        } else {
            let exp = WorkExperience(
                company: company, title: title, startDate: startDate,
                endDate: isCurrent ? nil : endDate, isCurrent: isCurrent, bullets: bullets
            )
            exp.profile = profile
            profile.workHistory.append(exp)
            modelContext.insert(exp)
        }
        try? modelContext.save()
        dismiss()
    }
}
