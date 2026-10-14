import SwiftUI

struct ContentView: View {
    /// Setting this back to `false` sends the app to the onboarding screen again.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @State private var showVirtualMachine = false

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

                Button {
                    showVirtualMachine = true
                } label: {
                    Label("Boot Tiny Core Linux", systemImage: "desktopcomputer")
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 12)
            }
            .padding()
            .navigationTitle("Everwind")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showVirtualMachine = true
                    } label: {
                        Image(systemName: "desktopcomputer")
                    }
                    .accessibilityLabel("Tiny Core Linux")
                }
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
        .fullScreenCover(isPresented: $showVirtualMachine) {
            VirtualMachineView()
        }
    }
}

#Preview {
    ContentView()
}
