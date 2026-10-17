import Foundation

public enum SnoozeStore {
    public static let appGroup = "group.com.xinli.sunflower"
    private static let logKey = "snooze.log"
    private static let modeKeyPrefix = "alarm.mode."
    /// Same postpone countdown is 9 minutes; ignore repeats inside this window.
    private static let sessionSeconds = 8 * 60

    public static func recordCountdown(alarmId: String) {
        append(alarmId: alarmId, kind: "snooze")
        UserDefaults(suiteName: appGroup)?.set("countdown", forKey: modeKeyPrefix + alarmId)
    }

    public static func recordMode(alarmId: String, mode: String) {
        if mode == "countdown" {
            recordCountdown(alarmId: alarmId)
            return
        }
        if mode == "scheduled" {
            recordStop(alarmId: alarmId)
            return
        }
        UserDefaults(suiteName: appGroup)?.set(mode, forKey: modeKeyPrefix + alarmId)
    }

    public static func recordStop(alarmId: String) {
        let defaults = UserDefaults(suiteName: appGroup)
        let previous = defaults?.string(forKey: modeKeyPrefix + alarmId) ?? ""
        if previous == "alerting" {
            append(alarmId: alarmId, kind: "done")
        }
        defaults?.set("scheduled", forKey: modeKeyPrefix + alarmId)
    }

    public static func json() -> String {
        let events = UserDefaults(suiteName: appGroup)?.array(forKey: logKey) as? [[String: Any]] ?? []
        guard let data = try? JSONSerialization.data(withJSONObject: events),
              let text = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return text
    }

    private static func append(alarmId: String, kind: String) {
        let defaults = UserDefaults(suiteName: appGroup)
        var events = defaults?.array(forKey: logKey) as? [[String: Any]] ?? []
        let stamp = Int(Date().timeIntervalSince1970)
        if let last = events.last(where: {
            ($0["alarm_id"] as? String) == alarmId && ($0["kind"] as? String ?? "snooze") == kind
        }), let lastAt = last["at"] as? Int, stamp - lastAt < sessionSeconds {
            return
        }
        let event: [String: Any] = [
            "date": dayKey(Date()),
            "alarm_id": alarmId,
            "at": stamp,
            "kind": kind,
        ]
        events.append(event)
        defaults?.set(events, forKey: logKey)
    }

    private static func dayKey(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
