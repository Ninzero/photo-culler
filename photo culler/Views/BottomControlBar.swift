import SwiftUI

struct BottomControlBar: View {
    let currentIndex: Int
    let totalCount: Int
    let currentRating: Rating?
    let canGoPrevious: Bool
    let canGoNext: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onRate: (Rating) -> Void

    var body: some View {
        HStack {
            // Navigation: previous
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .font(.title2)
            }
            .disabled(!canGoPrevious)
            .keyboardShortcut(.leftArrow, modifiers: [])

            Spacer()

            // Rating buttons
            HStack(spacing: 20) {
                Button(action: { onRate(.bad) }) {
                    Label("Bad", systemImage: "hand.thumbsdown.fill")
                        .font(.title3)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(currentRating == .bad ? Color.red.opacity(0.2) : Color.clear)
                        .foregroundStyle(currentRating == .bad ? .red : .secondary)
                        .cornerRadius(8)
                }
                .keyboardShortcut(.downArrow, modifiers: [])

                // Index display
                Text("\(currentIndex + 1) / \(totalCount)")
                    .font(.headline)
                    .monospacedDigit()

                Button(action: { onRate(.good) }) {
                    Label("Good", systemImage: "hand.thumbsup.fill")
                        .font(.title3)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(currentRating == .good ? Color.green.opacity(0.2) : Color.clear)
                        .foregroundStyle(currentRating == .good ? .green : .secondary)
                        .cornerRadius(8)
                }
                .keyboardShortcut(.upArrow, modifiers: [])
            }

            Spacer()

            // Navigation: next
            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.title2)
            }
            .disabled(!canGoNext)
            .keyboardShortcut(.rightArrow, modifiers: [])
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }
}
