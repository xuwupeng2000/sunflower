import AlarmKit
import AppIntents
import SwiftUI

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
