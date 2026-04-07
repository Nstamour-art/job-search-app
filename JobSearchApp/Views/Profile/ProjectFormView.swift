import SwiftUI

struct ProjectFormView: View {
    let profile: UserProfile
    let existing: Project?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var projectDescription: String
    @State private var url: String
    @State private var bulletsText: String

    init(profile: UserProfile, existing: Project?) {
        self.profile = profile
        self.existing = existing
        _name               = State(initialValue: existing?.name ?? "")
        _projectDescription = State(initialValue: existing?.projectDescription ?? "")
        _url                = State(initialValue: existing?.url ?? "")
        _bulletsText        = State(initialValue: existing?.bullets.joined(separator: "\n") ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Project") {
                    TextField("Name", text: $name)
                    TextField("URL (optional)", text: $url)
                }
                Section("Description") {
                    TextEditor(text: $projectDescription).frame(minHeight: 80)
                }
                Section {
                    TextEditor(text: $bulletsText).frame(minHeight: 80)
                } header: { Text("Highlights") } footer: { Text("One bullet per line.") }
            }
            .navigationTitle(existing == nil ? "Add Project" : "Edit Project")
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

        if let proj = existing {
            proj.name               = name
            proj.projectDescription = projectDescription
            proj.url                = url.isEmpty ? nil : url
            proj.bullets            = bullets
        } else {
            let proj = Project(
                name: name, projectDescription: projectDescription,
                url: url.isEmpty ? nil : url, bullets: bullets
            )
            proj.profile = profile
            profile.projects.append(proj)
            modelContext.insert(proj)
        }
        try? modelContext.save()
        dismiss()
    }
}
