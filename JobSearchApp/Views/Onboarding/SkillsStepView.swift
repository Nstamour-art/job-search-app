import SwiftUI

struct SkillsStepView: View {
    @ObservedObject var vm: OnboardingViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                StepHeader(
                    step: "4 of 5",
                    title: "Skills",
                    prompt: "List your technical skills, tools, languages, and frameworks."
                )

                TextEditor(text: $vm.skillsInput)
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                if vm.isLoading {
                    ProgressView("Extracting skills…").frame(maxWidth: .infinity)
                } else if let error = vm.errorMessage {
                    Text(error).foregroundStyle(.red).font(.caption)
                }

                Button("Extract with AI") { Task { await vm.parseSkills() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.skillsInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isLoading)

                if !vm.parsedSkills.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Extracted \(vm.parsedSkills.count) skill(s)").font(.headline)
                        SkillsChipsView(skills: $vm.parsedSkills)
                    }
                    Button("Next →") { vm.advance() }
                        .buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
                }

                Button("Skip") { vm.advance() }
                    .foregroundStyle(.secondary).frame(maxWidth: .infinity)
            }
            .padding()
        }
        .navigationTitle("Skills")
    }
}
