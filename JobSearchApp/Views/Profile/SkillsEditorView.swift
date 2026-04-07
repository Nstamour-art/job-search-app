import SwiftUI

struct SkillsEditorView: View {
    let profile: UserProfile
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var newSkill = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("Add skill…", text: $newSkill).onSubmit { addSkill() }
                        Button(action: addSkill) {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(newSkill.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                Section("Skills") {
                    ForEach(profile.skills.indices, id: \.self) { i in
                        Text(profile.skills[i])
                    }
                    .onDelete { offsets in
                        profile.skills.remove(atOffsets: offsets)
                        try? modelContext.save()
                    }
                    .onMove { from, to in
                        profile.skills.move(fromOffsets: from, toOffset: to)
                        try? modelContext.save()
                    }
                }
            }
            .navigationTitle("Edit Skills")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .navigationBarLeading) { EditButton() }
            }
        }
    }

    private func addSkill() {
        let trimmed = newSkill.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        profile.skills.append(trimmed)
        try? modelContext.save()
        newSkill = ""
    }
}
