import ActivityKit
import AlarmKit
import AppIntents
import SwiftUI
import UIKit
import UserNotifications

public enum Haptics {
    public static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    public static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
}

public enum Copy {
    /// "zh" Simplified, "zh_TW" Traditional, "en" English — the same codes the Godot side uses.
    public static let languages = ["zh", "zh_TW", "en"]

    /// The in-app choice lives in the shared app group. Otherwise follow the language
    /// iOS is actually using for this app, including a per-app language.
    public static var language: String {
        if let chosen = UserDefaults(suiteName: "group.com.xinli.sunflower")?.string(forKey: "sunflower_language"),
           languages.contains(chosen) {
            return chosen
        }
        return phoneLanguage()
    }

    /// Locale.preferredLanguages follows Settings → this app → Language.
    /// UserDefaults' AppleLanguages falls through to the whole phone, so it hides that choice.
    public static func phoneLanguage() -> String {
        let first = (Locale.preferredLanguages.first ?? "")
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
        guard first.hasPrefix("zh") else { return "en" }
        let traditional = ["hant", "-tw", "-hk", "-mo"].contains { first.contains($0) }
        return traditional ? "zh_TW" : "zh"
    }

    public static func text(_ zh: String, _ en: String, hant: String) -> String {
        switch language {
        case "zh": return zh
        case "zh_TW": return hant
        default: return en
        }
    }
}

public struct SunflowerMetadata: AlarmMetadata {
    public let alarmId: String
    public let events: String
    /// AlarmKit 排程用的 UUID，取消时直接按这个停，避免只靠逻辑 id 对不上。
    public let kitId: String

    public init(alarmId: String, events: String, kitId: String = "") {
        self.alarmId = alarmId
        self.events = events
        self.kitId = kitId
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
        UserDefaults(suiteName: "group.com.xinli.sunflower")?.set(timerId, forKey: cancelledKey)
    }

    public static func takeCancelled() -> String {
        let defaults = UserDefaults(suiteName: "group.com.xinli.sunflower")
        let id = defaults?.string(forKey: cancelledKey) ?? ""
        defaults?.removeObject(forKey: cancelledKey)
        return id
    }
}
