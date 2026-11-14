import ActivityKit
import Foundation

// This file is included in Runner and StkVerseWidget targets. ActivityKit
// requires identical attribute names and payloads in the two processes.
@available(iOS 16.2, *)
struct StkRestActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var startedAt: Date
    var endTime: Date
  }
  var sessionId: String
}
