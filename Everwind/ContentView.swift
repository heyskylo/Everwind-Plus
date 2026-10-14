import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showingOnboarding = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "wind")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(.tint)

                Text("Hello, Everwind!")
                    .font(.largeTitle.weight(.bold))

                Text(hasCompletedOnboarding
                     ? "Onboarding completed."
                     : "Onboarding not yet completed.")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Everwind")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingOnboarding = true
                    } label: {
                        Image(systemName: "repeat")
                    }
                    .accessibilityLabel("Show onboarding again")
                }
            }
            .fullScreenCover(isPresented: $showingOnboarding) {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
                .ignoresSafeArea()
            }
        }
        .onAppear {
            if !hasCompletedOnboarding {
                showingOnboarding = true
            }
        }
    }
}

#Preview {
    ContentView()
}
