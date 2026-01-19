import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    applyPersistedTheme()
    return result
  }

  private func applyPersistedTheme() {
    let prefs = UserDefaults.standard
    let stored = prefs.string(forKey: "flutter.themeMode") ?? prefs.string(forKey: "themeMode")
    let window = self.window ?? UIApplication.shared.connectedScenes
      .compactMap { ($0 as? UIWindowScene)?.windows.first(where: { $0.isKeyWindow }) }
      .first

    guard let targetWindow = window else { return }

    switch stored {
    case "light":
      targetWindow.overrideUserInterfaceStyle = .light
    case "dark":
      targetWindow.overrideUserInterfaceStyle = .dark
    default:
      targetWindow.overrideUserInterfaceStyle = .unspecified
    }
  }
}
