import SwiftUI
import UIKit

@main
struct EverwindApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Exists so `VirtualMachineView` can pin the UI to landscape while the virtual
/// machine is on screen.
///
/// The guest is a desktop Linux, so it is displayed in landscape. Without this
/// the phone would frame a landscape desktop inside a portrait window, which
/// looks broken no matter what resolution the guest uses.
final class AppDelegate: NSObject, UIApplicationDelegate {
    /// Matches `UISupportedInterfaceOrientations` for iPhone: everything but
    /// upside-down.
    static let unlockedOrientations: UIInterfaceOrientationMask = [
        .portrait, .landscapeLeft, .landscapeRight,
    ]

    /// When non-nil, the whole app is restricted to these orientations.
    static var orientationLock: UIInterfaceOrientationMask?

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        Self.orientationLock ?? Self.unlockedOrientations
    }

    /// Asks the system to rotate to the given orientations, and to re-read
    /// `supportedInterfaceOrientationsFor`.
    static func request(_ orientations: UIInterfaceOrientationMask) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return
        }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: orientations)) { _ in }
        scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
    }
}
