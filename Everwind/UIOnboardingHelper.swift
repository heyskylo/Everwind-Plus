import UIKit
import UIOnboarding

/// Builds the UIOnboarding welcome screen configuration.
///
/// Icons are drawn from SF Symbols so the app needs no bundled image assets to
/// compile and run. If a real App Icon is added to an asset catalog, it is used
/// automatically via `Bundle.main.appIcon`.
struct UIOnboardingHelper {
    static func setUpIcon() -> UIImage {
        Bundle.main.appIcon ?? UIImage(systemName: "wind")!
    }

    static func setUpFirstTitleLine() -> NSMutableAttributedString {
        .init(string: "Welcome to", attributes: [.foregroundColor: UIColor.label])
    }

    static func setUpSecondTitleLine() -> NSMutableAttributedString {
        .init(string: Bundle.main.displayName ?? "Everwind",
              attributes: [.foregroundColor: UIColor.systemBlue])
    }

    static func setUpFeatures() -> [UIOnboardingFeature] {
        [
            .init(icon: UIImage(systemName: "wind")!,
                  iconTint: .systemBlue,
                  title: "Fast and focused",
                  description: "Everwind keeps the essentials front and center."),
            .init(icon: UIImage(systemName: "location")!,
                  iconTint: .systemTeal,
                  title: "Always in the loop",
                  description: "See what matters at a glance."),
            .init(icon: UIImage(systemName: "sparkles")!,
                  iconTint: .systemIndigo,
                  title: "Made for iOS",
                  description: "Built with SwiftUI for iPhone and iPad.")
        ]
    }

    static func setUpNotice() -> UIOnboardingTextViewConfiguration {
        .init(icon: UIImage(systemName: "lock.fill"),
              text: "Your data stays on your device.",
              linkTitle: "Learn more",
              link: "https://github.com/heyskylo/Everwind-Plus",
              linkColor: .systemBlue)
    }

    static func setUpButton() -> UIOnboardingButtonConfiguration {
        .init(title: "Continue", titleColor: .white, backgroundColor: .systemBlue)
    }
}

extension UIOnboardingViewConfiguration {
    static func setUp() -> UIOnboardingViewConfiguration {
        .init(appIcon: UIOnboardingHelper.setUpIcon(),
              firstTitleLine: UIOnboardingHelper.setUpFirstTitleLine(),
              secondTitleLine: UIOnboardingHelper.setUpSecondTitleLine(),
              features: UIOnboardingHelper.setUpFeatures(),
              textViewConfiguration: UIOnboardingHelper.setUpNotice(),
              buttonConfiguration: UIOnboardingHelper.setUpButton())
    }
}
