import SwiftUI
import SwiftData

struct ProfileView: View {
    @StateObject private var vm = ProfileViewModel()
    @Environment(\.modelContext) private var modelContext

    @State private var showEditBasics = false
    @State private var showAddWork = false
    @State private var showAddEducation = false
    @State private var showAddProject = false
    @State private var showSkillsEditor = false
    @State private var selectedWork: WorkExperience?
    @State private var selectedEducation: Education?
    @State private var selectedProject: Project?

    var body: some View {
        NavigationStack {
            Group {
                if let profile = vm.profile {
                    profileList(profile)
                } else {
                    ContentUnavailableView(
                        "No Profile",
                        systemImage: "person.crop.circle.badge.exclamationmark",
                        description: Text("Complete onboarding to build your profile.")
                    )
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gear")
                    }
                }
            }
        }
        .onAppear { vm.load(context: modelContext) }
        .sheet(isPresented: $showEditBasics, onDismiss: reload) {
            if let p = vm.profile { EditBasicsView(profile: p) }
        }
        .sheet(isPresented: $showAddWork, onDismiss: reload) {
            if let p = vm.profile { WorkExperienceFormView(profile: p, existing: nil) }
        }
        .sheet(item: $selectedWork, onDismiss: reload) { exp in
            WorkExperienceFormView(profile: vm.profile!, existing: exp)
        }
        .sheet(isPresented: $showAddEducation, onDismiss: reload) {
            if let p = vm.profile { EducationFormView(profile: p, existing: nil) }
        }
        .sheet(item: $selectedEducation, onDismiss: reload) { edu in
            EducationFormView(profile: vm.profile!, existing: edu)
        }
        .sheet(isPresented: $showAddProject, onDismiss: reload) {
            if let p = vm.profile { ProjectFormView(profile: p, existing: nil) }
        }
        .sheet(item: $selectedProject, onDismiss: reload) { proj in
            ProjectFormView(profile: vm.profile!, existing: proj)
        }
        .sheet(isPresented: $showSkillsEditor, onDismiss: reload) {
            if let p = vm.profile { SkillsEditorView(profile: p) }
        }
    }

    private func reload() { vm.load(context: modelContext) }

    @ViewBuilder
    private func profileList(_ profile: UserProfile) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.basics.name).font(.title2.bold())
                    Text(profile.basics.email).foregroundStyle(.secondary)
                    if let phone = profile.basics.phone {
                        Text(phone).foregroundStyle(.secondary)
                    }
                    Text(profile.basics.location).foregroundStyle(.secondary)
                    if let li = profile.basics.linkedIn { Text(li).foregroundStyle(.blue) }
                    if let gh = profile.basics.github  { Text(gh).foregroundStyle(.blue) }
                }
            } header: { sectionHeader("Contact", action: { showEditBasics = true }, label: "Edit") }

            Section {
                ForEach(profile.workHistory.sorted(by: { $0.startDate > $1.startDate })) { exp in
                    WorkRow(exp: exp).contentShape(Rectangle())
                        .onTapGesture { selectedWork = exp }
                }
                .onDelete { offsets in
                    let sorted = profile.workHistory.sorted(by: { $0.startDate > $1.startDate })
                    offsets.forEach { vm.deleteWorkExperience(sorted[$0], context: modelContext) }
                }
            } header: { sectionHeader("Work History", action: { showAddWork = true }, label: "Add") }

            Section {
                ForEach(profile.education) { edu in
                    EduRow(edu: edu).contentShape(Rectangle())
                        .onTapGesture { selectedEducation = edu }
                }
                .onDelete { offsets in
                    offsets.forEach { vm.deleteEducation(profile.education[$0], context: modelContext) }
                }
            } header: { sectionHeader("Education", action: { showAddEducation = true }, label: "Add") }

            Section {
                if profile.skills.isEmpty {
                    Text("No skills added").foregroundStyle(.secondary)
                } else {
                    Text(profile.skills.joined(separator: " · ")).font(.subheadline)
                }
            } header: { sectionHeader("Skills", action: { showSkillsEditor = true }, label: "Edit") }

            Section {
                ForEach(profile.projects) { proj in
                    ProjRow(proj: proj).contentShape(Rectangle())
                        .onTapGesture { selectedProject = proj }
                }
                .onDelete { offsets in
                    offsets.forEach { vm.deleteProject(profile.projects[$0], context: modelContext) }
                }
            } header: { sectionHeader("Projects", action: { showAddProject = true }, label: "Add") }
        }
    }

    private func sectionHeader(_ title: String, action: @escaping () -> Void, label: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Button(label, action: action).font(.caption)
        }
    }
}

// MARK: - Row views

private struct WorkRow: View {
    let exp: WorkExperience
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(exp.title) at \(exp.company)").font(.subheadline.bold())
            Text(exp.isCurrent ? "Current" : dateLabel(exp.endDate))
                .font(.caption).foregroundStyle(.secondary)
            if !exp.bullets.isEmpty {
                Text(exp.bullets.prefix(2).map { "• \($0)" }.joined(separator: "\n"))
                    .font(.caption).foregroundStyle(.secondary).lineLimit(3)
            }
        }
        .padding(.vertical, 2)
    }

    private func dateLabel(_ date: Date?) -> String {
        guard let date else { return "" }
        let f = DateFormatter(); f.dateFormat = "MMM yyyy"
        return f.string(from: date)
    }
}

private struct EduRow: View {
    let edu: Education
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(edu.institution).font(.subheadline.bold())
            Text("\(edu.degree) in \(edu.field)").font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

private struct ProjRow: View {
    let proj: Project
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(proj.name).font(.subheadline.bold())
            Text(proj.projectDescription).font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }
        .padding(.vertical, 2)
    }
}
