import SwiftUI

extension View {
    /// Shows an alert while `message` is non-nil and clears it on dismissal.
    func errorAlert(_ message: Binding<String?>) -> some View {
        alert(
            "That didn't work",
            isPresented: Binding(
                get: { message.wrappedValue != nil },
                set: { if !$0 { message.wrappedValue = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}
