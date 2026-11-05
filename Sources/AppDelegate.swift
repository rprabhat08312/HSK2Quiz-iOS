import UIKit

// Legacy compatibility stub.
// The real iOS 12 app entry point is AppDelegate.swift at the repo root.
// This file used to reference a missing ViewController and caused the CI build to fail.
@available(iOS 12.0, *)
final class LegacyAppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return true
    }
}
