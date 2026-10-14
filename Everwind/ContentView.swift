import SwiftUI

struct ContentView: View {
    /// Setting this back to `false` sends the app to the onboarding screen again.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "wind")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(.tint)

                Text("Hello, Everwind!")
                    .font(.largeTitle.weight(.bold))

                Text("You're through onboarding.")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Everwind")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        hasCompletedOnboarding = false
                    } label: {
                        Image(systemName: "repeat")
                    }
                    .accessibilityLabel("Show onboarding again")
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
