import Flutter
import UIKit
import ActivityKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let sessionLiveActivityChannel = "numer/live_activity_session"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    registerSessionLiveActivityChannel()
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    applyPersistedTheme()
    return result
  }

  private func registerSessionLiveActivityChannel() {
    guard let registrar = self.registrar(forPlugin: "SessionLiveActivityBridge") else { return }
    let channel = FlutterMethodChannel(
      name: sessionLiveActivityChannel,
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler(handleSessionLiveActivity)
  }

  private func handleSessionLiveActivity(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(iOS 16.1, *) else {
      result(false)
      return
    }

    let args = call.arguments as? [String: Any] ?? [:]

    switch call.method {
    case "start":
      startOrReplaceSessionLiveActivity(args: args, result: result)
    case "update":
      updateSessionLiveActivity(args: args, result: result)
    case "end":
      endSessionLiveActivity(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @available(iOS 16.1, *)
  private func makeState(args: [String: Any]) -> SessionActivityAttributes.ContentState {
    let startedAtMs = int64Value(args["startedAtMs"])
    let endsAtMs = int64Value(args["endsAtMs"])

    return SessionActivityAttributes.ContentState(
      kind: args["kind"] as? String ?? "session",
      courseName: args["courseName"] as? String ?? "Session",
      title: args["title"] as? String ?? "Session",
      body: args["body"] as? String ?? "Running",
      phase: args["phase"] as? String,
      paused: args["paused"] as? Bool ?? false,
      elapsedSeconds: args["elapsedSeconds"] as? Int ?? 0,
      remainingSeconds: args["remainingSeconds"] as? Int ?? 0,
      showChronometer: args["showChronometer"] as? Bool ?? false,
      countsDown: args["countsDown"] as? Bool ?? false,
      startedAtMs: startedAtMs,
      endsAtMs: endsAtMs,
      updatedAtMs: int64Value(args["updatedAtMs"]) ?? Int64(Date().timeIntervalSince1970 * 1000)
    )
  }

  private func int64Value(_ value: Any?) -> Int64? {
    if let int64 = value as? Int64 {
      return int64
    }
    if let int = value as? Int {
      return Int64(int)
    }
    if let double = value as? Double {
      return Int64(double)
    }
    if let numString = value as? String, let parsed = Int64(numString) {
      return parsed
    }
    return nil
  }

  @available(iOS 16.1, *)
  private func firstSessionActivity() -> Activity<SessionActivityAttributes>? {
    Activity<SessionActivityAttributes>.activities.first
  }

  @available(iOS 16.1, *)
  private func startOrReplaceSessionLiveActivity(args: [String: Any], result: @escaping FlutterResult) {
    Task {
      guard ActivityAuthorizationInfo().areActivitiesEnabled else {
        result(false)
        return
      }
      let state = makeState(args: args)
      let sessionId = args["sessionId"] as? String ?? "active-session"

      if let existing = firstSessionActivity() {
        if #available(iOS 16.2, *) {
          await existing.update(ActivityContent(state: state, staleDate: nil))
        } else {
          await existing.update(using: state)
        }
        result(true)
        return
      }

      do {
        let attributes = SessionActivityAttributes(sessionId: sessionId)
        if #available(iOS 16.2, *) {
          _ = try Activity<SessionActivityAttributes>.request(
            attributes: attributes,
            content: ActivityContent(state: state, staleDate: nil),
            pushType: nil
          )
        } else {
          _ = try Activity<SessionActivityAttributes>.request(
            attributes: attributes,
            contentState: state,
            pushType: nil
          )
        }
        result(true)
      } catch {
        print("LiveActivity start failed: \(error.localizedDescription)")
        result(false)
      }
    }
  }

  @available(iOS 16.1, *)
  private func updateSessionLiveActivity(args: [String: Any], result: @escaping FlutterResult) {
    Task {
      guard ActivityAuthorizationInfo().areActivitiesEnabled else {
        result(false)
        return
      }
      guard let activity = firstSessionActivity() else {
        result(false)
        return
      }
      let state = makeState(args: args)
      if #available(iOS 16.2, *) {
        await activity.update(ActivityContent(state: state, staleDate: nil))
      } else {
        await activity.update(using: state)
      }
      result(true)
    }
  }

  @available(iOS 16.1, *)
  private func endSessionLiveActivity(result: @escaping FlutterResult) {
    Task {
      let activities = Activity<SessionActivityAttributes>.activities
      if activities.isEmpty {
        result(true)
        return
      }

      for activity in activities {
        if #available(iOS 16.2, *) {
          await activity.end(nil, dismissalPolicy: .immediate)
        } else {
          await activity.end(dismissalPolicy: .immediate)
        }
      }
      result(true)
    }
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
