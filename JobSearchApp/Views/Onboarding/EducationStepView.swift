import SwiftUI

struct EducationStepView: View {
    @ObservedObject var vm: OnboardingViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                StepHeader(
                    step: "3 of 5",
                    title: "Education",
                    prompt: "Tell me about your education — institutions, degrees, fields of study, and graduation dates."
                )

                TextEditor(text: $vm.educationInput)
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                if vm.isLoading {
                    ProgressView("Extracting education…").frame(maxWidth: .infinity)
                } else if let error = vm.errorMessage {
                    Text(error).foregroundStyle(.red).font(.caption)
                }

                Button("Extract with AI") { Task { await vm.parseEducation() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.educationInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isLoading)

                if !vm.parsedEducation.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Extracted \(vm.parsedEducation.count) entry(s)").font(.headline)
                        ForEach(vm.parsedEducation.indices, id: \.self) { i in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(vm.parsedEducation[i].institution).font(.subheadline.bold())
                                Text("\(vm.parsedEducation[i].degree) in \(vm.parsedEducation[i].field)")
                                    .font(.caption).foregroundStyle(.secondary)
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
        .navigationTitle("Education")
    }
}
