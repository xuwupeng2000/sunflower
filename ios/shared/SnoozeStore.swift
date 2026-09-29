import Foundation

public enum SnoozeStore {
    public static let appGroup = "group.com.sunflower.alarm"
    private static let logKey = "snooze.log"
    private static let modeKeyPrefix = "alarm.mode."

    public static func recordCountdown(alarmId: String) {
        let defaults = UserDefaults(suiteName: appGroup)
        let day = dayKey(Date())
        let key = modeKeyPrefix + alarmId
        let mark = "countdown:" + day
        if defaults?.string(forKey: key) == mark {
            return
        }
        defaults?.set(mark, forKey: key)
        append(alarmId: alarmId)
    }

    public static func recordMode(alarmId: String, mode: String) {
        if mode == "countdown" {
            recordCountdown(alarmId: alarmId)
            return
        }
        UserDefaults(suiteName: appGroup)?.set(mode, forKey: modeKeyPrefix + alarmId)
    }

    public static func json() -> String {
        let events = UserDefaults(suiteName: appGroup)?.array(forKey: logKey) as? [[String: Any]] ?? []
        guard let data = try? JSONSerialization.data(withJSONObject: events),
              let text = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return text
    }

    private static func append(alarmId: String) {
        let defaults = UserDefaults(suiteName: appGroup)
        var events = defaults?.array(forKey: logKey) as? [[String: Any]] ?? []
        let now = Date()
        let stamp = Int(now.timeIntervalSince1970)
        let day = dayKey(now)
        let event: [String: Any] = ["date": day, "alarm_id": alarmId, "at": stamp]
        events.append(event)
        defaults?.set(events, forKey: logKey)
    }

    private static func dayKey(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
