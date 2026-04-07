import SwiftUI

struct ThemePickerView: View {
    @ObservedObject var vm: OnboardingViewModel
    @EnvironmentObject private var coordinator: OnboardingCoordinator
    @Environment(\.modelContext) private var modelContext

    private let themes: [(ThemeName, String, Color)] = [
        (.classic,  "Classic",  .gray),
        (.modern,   "Modern",   .blue),
        (.creative, "Creative", .purple),
        (.minimal,  "Minimal",  .black)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 8) {
                    Text("Choose a Theme")
                        .font(.title2.bold())
                    Text("You can change this anytime in Settings.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.top)

                LazyVGrid(columns: [.init(), .init()], spacing: 16) {
                    ForEach(themes, id: \.0) { name, label, color in
                        ThemeCard(label: label, color: color, isSelected: vm.selectedTheme == name) {
                            vm.selectedTheme = name
                        }
                    }
                }
                .padding(.horizontal)

                Button("Finish & Start Job Searching") {
                    vm.saveProfile(context: modelContext, coordinator: coordinator)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
            }
        }
        .navigationTitle("Pick a Theme")
    }
}

private struct ThemeCard: View {
    let label: String
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.15))
                    .frame(height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isSelected ? color : .clear, lineWidth: 2)
                    )
                Text(label)
                    .font(.caption.bold())
                    .foregroundStyle(isSelected ? color : .primary)
            }
        }
        .buttonStyle(.plain)
    }
}
