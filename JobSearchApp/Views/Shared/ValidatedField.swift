import SwiftUI

/// A labeled text field wrapper that shows a prominent red highlight and
/// error message when validation fails. Pass `nil` for `error` to show
/// the normal (valid) state.
struct ValidatedField<Input: View>: View {
    let label: String
    let error: String?
    @ViewBuilder let input: () -> Input

    private var hasError: Bool { error != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(hasError ? .red : .secondary)

            input()
                .padding(8)
                .background(
                    hasError
                        ? Color.red.opacity(0.07)
                        : Color(.secondarySystemBackground)
                )
                .clipShape(.rect(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(hasError ? Color.red : .clear, lineWidth: 1.5)
                )

            if let error {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: hasError)
    }
}
