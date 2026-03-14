import ActivityKit
import WidgetKit
import SwiftUI

@available(iOSApplicationExtension 16.1, *)
struct SessionLiveActivityWidget: Widget {
  @ViewBuilder
  private var appIconView: some View {
    Image(systemName: "clock")
      .resizable()
      .scaledToFit()
      .symbolRenderingMode(.monochrome)
      .foregroundStyle(Color.primary)
  }

  private func displayTitle(_ context: ActivityViewContext<SessionActivityAttributes>) -> String {
    let primary = context.state.courseName.trimmingCharacters(in: .whitespacesAndNewlines)
    if !primary.isEmpty {
      return primary
    }

    let fallback = context.state.title.trimmingCharacters(in: .whitespacesAndNewlines)
    return fallback.isEmpty ? "Session" : fallback
  }

  private func displaySubtitle(
    _ context: ActivityViewContext<SessionActivityAttributes>
  ) -> String? {
    if let phase = context.state.phase?.trimmingCharacters(in: .whitespacesAndNewlines),
       !phase.isEmpty {
      return phase
    }

    let body = context.state.body.trimmingCharacters(in: .whitespacesAndNewlines)
    return body.isEmpty ? nil : body
  }

  private func compactTime(_ context: ActivityViewContext<SessionActivityAttributes>) -> String {
    let rawSeconds: Int
    if context.state.kind == "pomodoro" {
      rawSeconds = context.state.remainingSeconds
    } else {
      rawSeconds = context.state.elapsedSeconds
    }
    return formatDuration(max(rawSeconds, 0))
  }

  private func formatDuration(_ totalSeconds: Int) -> String {
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let seconds = totalSeconds % 60
    if hours > 0 {
      return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    return String(format: "%02d:%02d", minutes, seconds)
  }

  private func dateFromMs(_ value: Int64?) -> Date? {
    guard let value else { return nil }
    return Date(timeIntervalSince1970: TimeInterval(value) / 1000.0)
  }

  private func timerRange(
    _ context: ActivityViewContext<SessionActivityAttributes>
  ) -> (ClosedRange<Date>, Bool)? {
    guard context.state.showChronometer, !context.state.paused else {
      return nil
    }
    let countsDown = context.state.countsDown
    let start = dateFromMs(context.state.startedAtMs)
    let end = dateFromMs(context.state.endsAtMs)

    if countsDown {
      guard let end else { return nil }
      let now = Date()
      let clampedStart = start ?? now
      let from = clampedStart > now ? clampedStart : now
      let to = end > from ? end : from
      return (from...to, true)
    }

    guard let start else { return nil }
    let fallbackEnd = start.addingTimeInterval(TimeInterval(3 * 60 * 60))
    let to = end ?? fallbackEnd
    let boundedTo = to > start ? to : start
    return (start...boundedTo, false)
  }

  @ViewBuilder
  private func timeText(
    _ context: ActivityViewContext<SessionActivityAttributes>,
    font: Font
  ) -> some View {
    if let (range, countsDown) = timerRange(context) {
      Text(timerInterval: range, countsDown: countsDown)
        .font(font.monospacedDigit())
        .lineLimit(1)
    } else {
      Text(compactTime(context))
        .font(font.monospacedDigit())
        .lineLimit(1)
    }
  }

  var body: some WidgetConfiguration {
    ActivityConfiguration(for: SessionActivityAttributes.self) { context in
      HStack {
        Spacer(minLength: 0)
        HStack(alignment: .center, spacing: 8) {
          appIconView
            .frame(width: 16, height: 16)

          VStack(alignment: .leading, spacing: 2) {
            Text(displayTitle(context))
              .font(.subheadline.weight(.semibold))
              .lineLimit(1)
              .minimumScaleFactor(0.85)

            HStack(spacing: 6) {
              if let subtitle = displaySubtitle(context) {
                Text(subtitle)
                  .font(.caption)
                  .lineLimit(1)
                  .minimumScaleFactor(0.8)
                  .foregroundStyle(.secondary)
              }
              timeText(context, font: .caption)
                .lineLimit(1)
                .foregroundStyle(.secondary)
            }
          }
        }
        Spacer(minLength: 0)
      }
      .padding(.vertical, 8)
      .padding(.horizontal, 14)
      .activityBackgroundTint(Color(.systemBackground))
      .activitySystemActionForegroundColor(.accentColor)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          // Minimal or empty to allow centering
        }

        DynamicIslandExpandedRegion(.trailing) {
          // Minimal or empty to allow centering
        }

        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .center, spacing: 10) {
            HStack(spacing: 8) {
              appIconView
                .frame(width: 20, height: 20)
              Text("NUmer")
                .font(.headline)
                .foregroundColor(.accentColor)
              
              Text("•")
                .foregroundColor(.secondary)
              
              timeText(context, font: .headline.monospacedDigit())
                .foregroundColor(.accentColor)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            VStack(alignment: .center, spacing: 2) {
              Text(displayTitle(context))
                .font(.headline)
                .lineLimit(1)

              HStack {
                Text(context.state.kind.capitalized)
                  .font(.subheadline)
                  .foregroundColor(.secondary)

                if let subtitle = displaySubtitle(context) {
                  Text("•")
                    .foregroundColor(.secondary)
                  Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
              }
            }
            .frame(maxWidth: .infinity, alignment: .center)
          }
          .padding(.vertical, 8)
        }
      } compactLeading: {
        appIconView
          .frame(width: 13, height: 13)
      } compactTrailing: {
        timeText(context, font: .caption2.weight(.semibold))
          .lineLimit(1)
          .minimumScaleFactor(0.5)
          .frame(maxWidth: 40, alignment: .trailing)
      } minimal: {
        appIconView
          .frame(width: 13, height: 13)
      }
      .keylineTint(.accentColor)
    }
  }
}
