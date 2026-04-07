import SwiftUI

struct WorkHistoryStepView: View {
    @ObservedObject var vm: OnboardingViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                StepHeader(
                    step: "2 of 5",
                    title: "Work History",
                    prompt: "Describe your work experience. Include company names, titles, dates, and what you accomplished in each role."
                )

                TextEditor(text: $vm.workInput)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                if vm.isLoading {
                    ProgressView("Extracting work history…").frame(maxWidth: .infinity)
                } else if let error = vm.errorMessage {
                    Text(error).foregroundStyle(.red).font(.caption)
                }

                Button("Extract with AI") { Task { await vm.parseWork() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.workInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isLoading)

                if !vm.parsedWork.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Extracted \(vm.parsedWork.count) role(s)").font(.headline)
                        ForEach(vm.parsedWork.indices, id: \.self) { i in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(vm.parsedWork[i].title) at \(vm.parsedWork[i].company)")
                                    .font(.subheadline.bold())
                                Text(vm.parsedWork[i].startDate + " – " + (vm.parsedWork[i].endDate ?? "Present"))
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
        .navigationTitle("Work History")
    }
}
