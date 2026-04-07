import SwiftUI

struct ProjectsStepView: View {
    @ObservedObject var vm: OnboardingViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                StepHeader(
                    step: "5 of 5",
                    title: "Projects",
                    prompt: "Tell me about any personal or professional projects. Include the name, what it does, and technologies used."
                )

                TextEditor(text: $vm.projectsInput)
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                if vm.isLoading {
                    ProgressView("Extracting projects…").frame(maxWidth: .infinity)
                } else if let error = vm.errorMessage {
                    Text(error).foregroundStyle(.red).font(.caption)
                }

                Button("Extract with AI") { Task { await vm.parseProjects() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.projectsInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isLoading)

                if !vm.parsedProjects.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Extracted \(vm.parsedProjects.count) project(s)").font(.headline)
                        ForEach(vm.parsedProjects.indices, id: \.self) { i in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(vm.parsedProjects[i].name).font(.subheadline.bold())
                                Text(vm.parsedProjects[i].description)
                                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    Button("Next →") { vm.advance() }
                        .buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
                }

                Button("Skip") { vm.advance() }
                    .foregroundStyle(.secondary).frame(maxWidth: .infinity)
            }
            .padding()
        }
        .navigationTitle("Projects")
    }
}
