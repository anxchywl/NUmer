import Foundation
import ActivityKit

@available(iOS 16.1, *)
public struct SessionActivityAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    public var kind: String
    public var courseName: String
    public var title: String
    public var body: String
    public var phase: String?
    public var paused: Bool
    public var elapsedSeconds: Int
    public var remainingSeconds: Int
    public var showChronometer: Bool
    public var countsDown: Bool
    public var startedAtMs: Int64?
    public var endsAtMs: Int64?
    public var updatedAtMs: Int64

    public init(
      kind: String,
      courseName: String,
      title: String,
      body: String,
      phase: String?,
      paused: Bool,
      elapsedSeconds: Int,
      remainingSeconds: Int,
      showChronometer: Bool,
      countsDown: Bool,
      startedAtMs: Int64?,
      endsAtMs: Int64?,
      updatedAtMs: Int64
    ) {
      self.kind = kind
      self.courseName = courseName
      self.title = title
      self.body = body
      self.phase = phase
      self.paused = paused
      self.elapsedSeconds = elapsedSeconds
      self.remainingSeconds = remainingSeconds
      self.showChronometer = showChronometer
      self.countsDown = countsDown
      self.startedAtMs = startedAtMs
      self.endsAtMs = endsAtMs
      self.updatedAtMs = updatedAtMs
    }
  }

  public var sessionId: String

  public init(sessionId: String) {
    self.sessionId = sessionId
  }
}
