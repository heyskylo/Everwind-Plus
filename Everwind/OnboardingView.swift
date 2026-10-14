import SwiftUI
import UIOnboarding

/// Bridges UIOnboarding's UIKit `UIOnboardingViewController` into SwiftUI so it
/// can be presented with `.fullScreenCover`.
struct OnboardingView: UIViewControllerRepresentable {
    /// Called after the user finishes the onboarding flow.
    var onFinish: () -> Void = {}

    func makeUIViewController(context: Context) -> UIOnboardingViewController {
        let controller = UIOnboardingViewController(withConfiguration: .setUp())
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIOnboardingViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    final class Coordinator: NSObject, UIOnboardingViewControllerDelegate {
        private let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        func didFinishOnboarding(onboardingViewController: UIOnboardingViewController) {
            onboardingViewController.modalTransitionStyle = .crossDissolve
            onboardingViewController.dismiss(animated: true, completion: onFinish)
        }
    }
}

#Preview {
    OnboardingView()
}
