import ActivityKit
import Foundation

@available(iOS 16.2, *)
enum StkRestLiveActivityBridge {
  static func update(sessionId: String, endTime: Date) async -> Bool {
    guard ActivityAuthorizationInfo().areActivitiesEnabled,
          endTime > Date() else { return false }

    let state = StkRestActivityAttributes.ContentState(
      startedAt: Date(), endTime: endTime)
    let content = ActivityContent(state: state, staleDate: endTime)
    for activity in Activity<StkRestActivityAttributes>.activities {
      if activity.attributes.sessionId == sessionId {
        await activity.update(content)
        return true
      }
      await activity.end(dismissalPolicy: .immediate)
    }

    do {
      _ = try Activity<StkRestActivityAttributes>.request(
        attributes: StkRestActivityAttributes(sessionId: sessionId),
        content: content,
        pushType: nil)
      return true
    } catch {
      return false
    }
  }

  static func end() async {
    for activity in Activity<StkRestActivityAttributes>.activities {
      await activity.end(dismissalPolicy: .immediate)
    }
  }
}
