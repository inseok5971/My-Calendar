import Combine
import SwiftUI

/// Tactile pill-shaped toggle check inspired by switch checklists.
struct PillToggleCheck: View {
    let isOn: Bool
    var tintColor: Color = .accentColor
    let action: () -> Void

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.78)) {
                action()
            }
        }) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? tintColor : Color.primary.opacity(0.08))
                    .overlay(
                        Capsule()
                            .strokeBorder(isOn ? tintColor : Color.primary.opacity(0.22), lineWidth: 1.2)
                    )

                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.16), radius: 1.5, y: 1)
                    .padding(2.5)
            }
            .frame(width: 34, height: 19)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Lightweight ObservableObject box for local view state when SwiftUIMacros is unavailable.
@MainActor
final class StateBox<Value>: ObservableObject {
    @Published var value: Value
    init(_ value: Value) {
        self.value = value
    }
}
