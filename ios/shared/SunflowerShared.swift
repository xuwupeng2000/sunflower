import ActivityKit
import AlarmKit
import AppIntents
import SwiftUI
import UserNotifications

public enum Copy {
    public static var chinese: Bool {
        systemLanguage().hasPrefix("zh")
    }

    /// The in-app choice lives in the shared app group. Otherwise use the phone language,
    /// because Locale.current follows this bundle, which only ships English.
    private static func systemLanguage() -> String {
        if let chosen = UserDefaults(suiteName: "group.com.sunflower.alarm")?.string(forKey: "sunflower_language"),
           chosen == "zh" || chosen == "en" {
            return chosen
        }
        let global = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)
        let languages = global?["AppleLanguages"] as? [String]
        let first = languages?.first ?? Locale.preferredLanguages.first ?? ""
        return first.lowercased()
    }

    public static func text(_ zh: String, _ en: String) -> String {
        chinese ? zh : en
    }
}

public struct SunflowerMetadata: AlarmMetadata {
    public let alarmId: String
    public let events: String

    public init(alarmId: String, events: String) {
        self.alarmId = alarmId
        self.events = events
    }
}

/// Alarm ids are logical strings like "due-1-7-0"; AlarmKit needs the same UUID every time.
public func alarmUUID(_ alarmId: String) -> UUID? {
    if let direct = UUID(uuidString: alarmId) {
        return direct
    }
    let raw = Array(alarmId.utf8)
    func mix(_ seed: UInt64) -> UInt64 {
        var hash = seed
        for byte in raw {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return hash
    }
    let left = mix(14695981039346656037)
    let right = mix(1099511628211)
    var bytes = Array(repeating: UInt8(0), count: 16)
    for index in 0..<8 {
        bytes[index] = UInt8((left >> (UInt64(index) * 8)) & 0xff)
        bytes[index + 8] = UInt8((right >> (UInt64(index) * 8)) & 0xff)
    }
    bytes[6] = (bytes[6] & 0x0F) | 0x40
    bytes[8] = (bytes[8] & 0x3F) | 0x80
    let text = String(
        format: "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
        bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
        bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
    )
    return UUID(uuidString: text)
}

/// Ends the current postpone countdown; the weekly alarm still rings next time.
public struct CancelSnoozeIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource {
        LocalizedStringResource(stringLiteral: Copy.text("取消推迟", "Cancel snooze"))
    }
    public static var openAppWhenRun = false

    @Parameter(title: "Group")
    public var logicalID: String

    public init() {
        logicalID = ""
    }

    public init(logicalID: String) {
        self.logicalID = logicalID
    }

    public func perform() async throws -> some IntentResult {
        if let uuid = alarmUUID(logicalID) {
            try? AlarmManager.shared.stop(id: uuid)
        }
        return .result()
    }
}

/// One-shot countdown from the timer tab; only one runs at a time.
public struct SunflowerTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public init() {}
    }

    public let timerId: String
    public let title: String
    public let startDate: Date
    public let endDate: Date

    public init(timerId: String, title: String, startDate: Date, endDate: Date) {
        self.timerId = timerId
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
    }

    private var startsWithEmoji: Bool {
        title.first?.unicodeScalars.first?.properties.isEmojiPresentation ?? false
    }

    /// Leading emoji of the title, or a sunflower when the name has none.
    public var emoji: String {
        startsWithEmoji ? String(title.first!) : "🌻"
    }

    /// Title without the leading emoji.
    public var name: String {
        startsWithEmoji ? String(title.dropFirst()).trimmingCharacters(in: .whitespaces) : title
    }
}

public enum SunflowerTimer {
    private static let cancelledKey = "sunflower_timer_cancelled"

    public static func notificationID(_ timerId: String) -> String {
        "sunflower-timer-\(timerId)"
    }

    /// Removes the pending notification and the Live Activity.
    public static func cancel(_ timerId: String) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationID(timerId)])
        center.removeDeliveredNotifications(withIdentifiers: [notificationID(timerId)])
        await end(timerId)
    }

    /// Ends the Live Activity only; empty id ends every timer activity.
    public static func end(_ timerId: String) async {
        for activity in Activity<SunflowerTimerAttributes>.activities
        where timerId.isEmpty || activity.attributes.timerId == timerId {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// The app reads this on focus so a cancel from the Lock Screen also clears the timer tab.
    public static func markCancelled(_ timerId: String) {
        UserDefaults(suiteName: "group.com.sunflower.alarm")?.set(timerId, forKey: cancelledKey)
    }

    public static func takeCancelled() -> String {
        let defaults = UserDefaults(suiteName: "group.com.sunflower.alarm")
        let id = defaults?.string(forKey: cancelledKey) ?? ""
        defaults?.removeObject(forKey: cancelledKey)
        return id
    }
}

public struct CancelTimerIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource {
        LocalizedStringResource(stringLiteral: Copy.text("取消计时", "Cancel timer"))
    }
    public static var openAppWhenRun = false

    @Parameter(title: "Timer")
    public var timerID: String

    public init() {
        timerID = ""
    }

    public init(timerID: String) {
        self.timerID = timerID
    }

    public func perform() async throws -> some IntentResult {
        SunflowerTimer.markCancelled(timerID)
        await SunflowerTimer.cancel(timerID)
        return .result()
    }
}

public struct SnoozeFlowerIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource {
        LocalizedStringResource(stringLiteral: Copy.text("推迟", "Postpone"))
    }
    public static var openAppWhenRun = true

    @Parameter(title: "Alarm")
    public var alarmID: String

    @Parameter(title: "Group")
    public var logicalID: String

    public init() {
        alarmID = ""
        logicalID = ""
    }

    public init(alarmID: String, logicalID: String) {
        self.alarmID = alarmID
        self.logicalID = logicalID
    }

    public func perform() async throws -> some IntentResult {
        if !logicalID.isEmpty {
            SnoozeStore.recordCountdown(alarmId: logicalID)
        }
        if let uuid = UUID(uuidString: alarmID) {
            try? AlarmManager.shared.countdown(id: uuid)
        }
        return .result()
    }
}
