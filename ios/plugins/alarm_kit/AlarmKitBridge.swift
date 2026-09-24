import AlarmKit
import AppIntents
import Foundation
import SwiftUI

private var snoozeCallback: (() -> Void)?

@objc public class AlarmKitBridge: NSObject {
    @objc public static func setSnoozeCallback(_ callback: (@convention(block) () -> Void)?) {
        snoozeCallback = callback
    }

    @objc public static func requestAuthorization() {
        Task {
            _ = try? await AlarmManager.shared.requestAuthorization()
        }
    }

    @objc public static func scheduleWeeklyJSON(_ json: String) {
        guard let data = json.data(using: .utf8),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let idText = raw["id"] as? String,
              let id = UUID(uuidString: idText) ?? UUID(uuidString: stableUUID(idText)) else {
            return
        }
        let hour = raw["hour"] as? Int ?? 7
        let minute = raw["minute"] as? Int ?? 0
        let label = raw["label"] as? String ?? "起床"
        let weekdayNumbers = raw["weekdays"] as? [Int] ?? [1, 2, 3, 4, 5]
        Task {
            try? await schedule(id: id, hour: hour, minute: minute, label: label, weekdayNumbers: weekdayNumbers)
        }
    }

    @objc public static func cancelAlarm(_ alarmId: String) {
        guard let id = UUID(uuidString: alarmId) ?? UUID(uuidString: stableUUID(alarmId)) else {
            return
        }
        Task {
            try? await AlarmManager.shared.cancel(id: id)
        }
    }

    @objc public static func snoozeLogJSON() -> String {
        SnoozeStore.json()
    }

    @objc public static func startObserving() {
        Task {
            for await alarms in AlarmManager.shared.alarmUpdates {
                for alarm in alarms {
                    let mode = String(describing: alarm.state)
                    SnoozeStore.recordMode(alarmId: alarm.id.uuidString, mode: mode.contains("countdown") ? "countdown" : mode)
                }
                snoozeCallback?()
            }
        }
    }
}

private func schedule(id: UUID, hour: Int, minute: Int, label: String, weekdayNumbers: [Int]) async throws {
    typealias Config = AlarmManager.AlarmConfiguration<SunflowerMetadata>
    let weekdays = weekdayNumbers.compactMap(localeWeekday)
    let time = Alarm.Schedule.Relative.Time(hour: hour, minute: minute)
    let recurrence = Alarm.Schedule.Relative.Recurrence.weekly(weekdays)
    let relative = Alarm.Schedule.Relative(time: time, repeats: recurrence)

    let stop = AlarmButton(text: "停止", textColor: .white, systemImageName: "stop.circle")
    let snooze = AlarmButton(text: "贪睡", textColor: .white, systemImageName: "zzz")
    let alert = AlarmPresentation.Alert(
        title: LocalizedStringResource(stringLiteral: label),
        stopButton: stop,
        secondaryButton: snooze,
        secondaryButtonBehavior: .countdown
    )
    let pause = AlarmButton(text: "暂停", textColor: .white, systemImageName: "pause.fill")
    let countdown = AlarmPresentation.Countdown(title: "再睡一会儿", pauseButton: pause)
    let resume = AlarmButton(text: "继续", textColor: .white, systemImageName: "play.fill")
    let paused = AlarmPresentation.Paused(title: "已暂停", resumeButton: resume)
    let attributes = AlarmAttributes<SunflowerMetadata>(
        presentation: AlarmPresentation(alert: alert, countdown: countdown, paused: paused),
        metadata: SunflowerMetadata(alarmId: id.uuidString),
        tintColor: Color(red: 0.95, green: 0.72, blue: 0.12)
    )
    let sound = AlertConfiguration.AlertSound.named("sunflower.caf")
    let configuration = Config(
        countdownDuration: Alarm.CountdownDuration(preAlert: nil, postAlert: 9 * 60),
        schedule: .relative(relative),
        attributes: attributes,
        sound: sound
    )
    try await AlarmManager.shared.schedule(id: id, configuration: configuration)
}

private func localeWeekday(_ day: Int) -> Locale.Weekday? {
    switch day {
    case 1: return .monday
    case 2: return .tuesday
    case 3: return .wednesday
    case 4: return .thursday
    case 5: return .friday
    case 6: return .saturday
    case 7: return .sunday
    default: return nil
    }
}

private func stableUUID(_ text: String) -> String {
    var bytes = Array(repeating: UInt8(0), count: 16)
    let raw = Array(text.utf8)
    for index in 0..<min(16, raw.count) {
        bytes[index] = raw[index]
    }
    bytes[6] = (bytes[6] & 0x0F) | 0x40
    bytes[8] = (bytes[8] & 0x3F) | 0x80
    return String(
        format: "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
        bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
        bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
    )
}
