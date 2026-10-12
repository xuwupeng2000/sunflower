import ActivityKit
import AlarmKit
import AppIntents
import Foundation
import SwiftUI
import UserNotifications

private var snoozeCallback: (() -> Void)?

@objc(AlarmKitBridge) public class AlarmKitBridge: NSObject {
    @objc public static func setSnoozeCallback(_ callback: (@convention(block) () -> Void)?) {
        snoozeCallback = callback
    }

    /// Empty means the user has not chosen a language, so the app follows the phone.
    /// "zh" and "en" are explicit choices from Settings.
    @objc public static func settingsLanguage() -> String {
        let key = "sunflower_ui_language"
        UserDefaults.standard.synchronize()
        CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication)
        let stored = (CFPreferencesCopyAppValue(key as CFString, kCFPreferencesCurrentApplication) as? String)
            ?? UserDefaults.standard.string(forKey: key)
        let explicit = (stored == "zh" || stored == "en") ? stored! : ""
        let resolved = explicit.isEmpty ? phoneLanguage() : explicit
        UserDefaults(suiteName: "group.com.sunflower.alarm")?.set(resolved, forKey: "sunflower_language")
        return explicit
    }

    private static func phoneLanguage() -> String {
        let global = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)
        let languages = global?["AppleLanguages"] as? [String]
        let first = (languages?.first ?? Locale.preferredLanguages.first ?? "").lowercased()
        return first.hasPrefix("zh") ? "zh" : "en"
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
              let id = alarmUUID(idText) else {
            return
        }
        let hour = raw["hour"] as? Int ?? 7
        let minute = raw["minute"] as? Int ?? 0
        let label = raw["label"] as? String ?? Copy.text("起床", "Wake up")
        let weekdayNumbers = raw["weekdays"] as? [Int] ?? [1, 2, 3, 4, 5]
        let eventRows = raw["events"] as? [[String: Any]] ?? []
        let (title, events) = titleAndEvents(eventRows, fallback: label)
        let dateRows = raw["dates"] as? [[String: Any]]
        enqueue {
            await cancelLogical(idText)
            guard let dateRows else {
                let time = Alarm.Schedule.Relative.Time(hour: hour, minute: minute)
                let weekly = Alarm.Schedule.Relative(time: time, repeats: .weekly(weekdayNumbers.compactMap(localeWeekday)))
                try? await schedule(id: id, logicalId: idText, when: .relative(weekly), label: title, events: events)
                return
            }
            // A skipped day is left out of the list; every other week rings once on its own date.
            for row in dateRows {
                guard let dateText = row["date"] as? String,
                      let when = fixedDate(dateText, hour: hour, minute: minute),
                      when > Date(),
                      let dayId = alarmUUID("\(idText)@\(dateText)") else {
                    continue
                }
                let (dayTitle, dayEvents) = titleAndEvents(row["events"] as? [[String: Any]] ?? [], fallback: label)
                try? await schedule(id: dayId, logicalId: idText, when: .fixed(when), label: dayTitle, events: dayEvents)
            }
        }
    }

    @objc public static func cancelAlarm(_ alarmId: String) {
        enqueue {
            await cancelLogical(alarmId)
        }
    }

    /// Stops the ring or postpone countdown now; a weekly alarm stays scheduled.
    @objc public static func stopAlarm(_ alarmId: String) {
        let alarms = (try? AlarmManager.shared.alarms) ?? []
        for alarm in alarms where logicalID(alarm) == alarmId && stateName(alarm.state) != "scheduled" {
            try? AlarmManager.shared.stop(id: alarm.id)
        }
    }

    /// Replaces any running timer: a notification at the end plus a Live Activity counting down.
    @objc public static func startTimer(_ timerId: String, title: String, seconds: Int) {
        let start = Date()
        let end = start.addingTimeInterval(TimeInterval(max(1, seconds)))
        Task {
            let center = UNUserNotificationCenter.current()
            let old = await center.pendingNotificationRequests()
                .map(\.identifier)
                .filter { $0.hasPrefix(SunflowerTimer.notificationID("")) }
            center.removePendingNotificationRequests(withIdentifiers: old)
            await SunflowerTimer.end("")
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = Copy.text("时间到啦 ☁️", "Time's up ☁️")
            content.sound = UNNotificationSound(named: UNNotificationSoundName("sunflower.wav"))
            if let sky = skyAttachment(timerId) {
                content.attachments = [sky]
            }
            content.interruptionLevel = .timeSensitive
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: end.timeIntervalSince(start), repeats: false)
            let request = UNNotificationRequest(identifier: SunflowerTimer.notificationID(timerId), content: content, trigger: trigger)
            try? await center.add(request)
            let attributes = SunflowerTimerAttributes(timerId: timerId, title: title, startDate: start, endDate: end)
            let state = SunflowerTimerAttributes.ContentState()
            _ = try? Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: end),
                pushType: nil
            )
        }
    }

    @objc public static func cancelTimer(_ timerId: String) {
        Task {
            await SunflowerTimer.cancel(timerId)
        }
    }

    /// Time is up while the app is open: the page already rang, so just drop the activity.
    @objc public static func finishTimer(_ timerId: String) {
        Task {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [SunflowerTimer.notificationID(timerId)])
            await SunflowerTimer.end(timerId)
        }
    }

    @objc public static func takeCancelledTimer() -> String {
        SunflowerTimer.takeCancelled()
    }

    @objc public static func snoozeLogJSON() -> String {
        SnoozeStore.json()
    }

    @objc public static func activeAlarmsJSON() -> String {
        let alarms = (try? AlarmManager.shared.alarms) ?? []
        var rows: [[String: Any]] = []
        for alarm in alarms {
            guard let logical = logicalID(alarm) else {
                continue
            }
            let state = stateName(alarm.state)
            if state == "countdown" || state == "paused" {
                SnoozeStore.recordCountdown(alarmId: logical)
            }
            if state == "scheduled" {
                continue
            }
            rows.append([
                "id": logical,
                "state": state,
                "hour": hour(alarm),
                "minute": minute(alarm),
                "weekday": weekday(alarm),
            ])
        }
        guard let data = try? JSONSerialization.data(withJSONObject: rows),
              let text = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return text
    }

    @objc public static func startObserving() {
        Task {
            for await alarms in AlarmManager.shared.alarmUpdates {
                for alarm in alarms {
                    guard let logical = logicalID(alarm) else {
                        continue
                    }
                    let state = stateName(alarm.state)
                    if state == "countdown" || state == "paused" {
                        SnoozeStore.recordCountdown(alarmId: logical)
                    } else if state == "alerting" {
                        SnoozeStore.recordMode(alarmId: logical, mode: "alerting")
                    } else {
                        SnoozeStore.recordStop(alarmId: logical)
                    }
                }
                snoozeCallback?()
            }
        }
    }
}

/// 通知右边那张蓝天白云小图。系统会把附件挪走，所以先拷一份到临时目录。
private func skyAttachment(_ timerId: String) -> UNNotificationAttachment? {
    guard let source = Bundle.main.url(forResource: "notify_sky", withExtension: "png") else {
        return nil
    }
    let copy = FileManager.default.temporaryDirectory.appendingPathComponent("notify_sky-\(timerId).png")
    try? FileManager.default.removeItem(at: copy)
    guard (try? FileManager.default.copyItem(at: source, to: copy)) != nil else {
        return nil
    }
    return try? UNNotificationAttachment(identifier: "sky", url: copy)
}

private let queueLock = NSLock()
nonisolated(unsafe) private var queueTail: Task<Void, Never>?

/// Cancel-then-schedule must not interleave, or a late cancel wipes the alarms just scheduled.
private func enqueue(_ work: @escaping @Sendable () async -> Void) {
    queueLock.lock()
    defer { queueLock.unlock() }
    let previous = queueTail
    queueTail = Task {
        await previous?.value
        await work()
    }
}

/// One logical slot may be a weekly alarm or several dated ones; drop them all.
private func cancelLogical(_ logicalId: String) async {
    let alarms = (try? AlarmManager.shared.alarms) ?? []
    for alarm in alarms where logicalID(alarm) == logicalId {
        try? await AlarmManager.shared.cancel(id: alarm.id)
    }
    if let id = alarmUUID(logicalId) {
        try? await AlarmManager.shared.cancel(id: id)
    }
}

private func titleAndEvents(_ rows: [[String: Any]], fallback: String) -> (String, String) {
    let labels = rows.compactMap { $0["label"] as? String }.filter { !$0.isEmpty }
    if labels.isEmpty {
        return (fallback, fallback)
    }
    return (labels.joined(separator: Copy.text("、", ", ")), labels.joined(separator: "\n"))
}

private func fixedDate(_ text: String, hour: Int, minute: Int) -> Date? {
    let parts = text.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else {
        return nil
    }
    return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: hour, minute: minute))
}

private func schedule(id: UUID, logicalId: String, when: Alarm.Schedule, label: String, events: String) async throws {
    typealias Config = AlarmManager.AlarmConfiguration<SunflowerMetadata>

    let stop = AlarmButton(text: LocalizedStringResource(stringLiteral: Copy.text("停止", "Stop")), textColor: .white, systemImageName: "stop.circle")
    let snooze = AlarmButton(text: LocalizedStringResource(stringLiteral: Copy.text("推迟", "Snooze")), textColor: .white, systemImageName: "zzz")
    let alert = AlarmPresentation.Alert(
        title: LocalizedStringResource(stringLiteral: label),
        stopButton: stop,
        secondaryButton: snooze,
        secondaryButtonBehavior: .countdown
    )
    let pause = AlarmButton(text: LocalizedStringResource(stringLiteral: Copy.text("暂停", "Pause")), textColor: .white, systemImageName: "pause.fill")
    let countdownTitle = label.isEmpty ? Copy.text("即将再响", "Snoozing") : label
    let countdown = AlarmPresentation.Countdown(title: LocalizedStringResource(stringLiteral: countdownTitle), pauseButton: pause)
    let resume = AlarmButton(text: LocalizedStringResource(stringLiteral: Copy.text("继续", "Resume")), textColor: .white, systemImageName: "play.fill")
    let paused = AlarmPresentation.Paused(title: LocalizedStringResource(stringLiteral: Copy.text("已暂停", "Paused")), resumeButton: resume)
    let attributes = AlarmAttributes<SunflowerMetadata>(
        presentation: AlarmPresentation(alert: alert, countdown: countdown, paused: paused),
        metadata: SunflowerMetadata(alarmId: logicalId, events: events, kitId: id.uuidString),
        tintColor: Color(red: 127.0 / 255.0, green: 167.0 / 255.0, blue: 198.0 / 255.0)
    )
    let sound = AlertConfiguration.AlertSound.named("sunflower.wav")
    let configuration = Config(
        countdownDuration: Alarm.CountdownDuration(preAlert: nil, postAlert: 9 * 60),
        schedule: when,
        attributes: attributes,
        stopIntent: nil,
        secondaryIntent: nil,
        sound: sound
    )
    try await AlarmManager.shared.schedule(id: id, configuration: configuration)
}

/// Weekday (1 = Monday), hour and minute, whether the alarm repeats weekly or rings on one date.
private func slot(_ alarm: Alarm) -> (weekday: Int, hour: Int, minute: Int)? {
    if case .relative(let relative) = alarm.schedule,
       case .weekly(let days) = relative.repeats,
       let day = days.first {
        return (weekdayNumber(day), relative.time.hour, relative.time.minute)
    }
    if case .fixed(let date) = alarm.schedule {
        let parts = Calendar.current.dateComponents([.weekday, .hour, .minute], from: date)
        return (((parts.weekday ?? 2) + 5) % 7 + 1, parts.hour ?? 0, parts.minute ?? 0)
    }
    return nil
}

private func logicalID(_ alarm: Alarm) -> String? {
    guard let slot = slot(alarm) else {
        return nil
    }
    return "due-\(slot.weekday)-\(slot.hour)-\(slot.minute)"
}

private func hour(_ alarm: Alarm) -> Int {
    slot(alarm)?.hour ?? 0
}

private func minute(_ alarm: Alarm) -> Int {
    slot(alarm)?.minute ?? 0
}

private func weekday(_ alarm: Alarm) -> Int {
    slot(alarm)?.weekday ?? 1
}

private func stateName(_ state: Alarm.State) -> String {
    switch state {
    case .countdown:
        return "countdown"
    case .paused:
        return "paused"
    case .alerting:
        return "alerting"
    case .scheduled:
        return "scheduled"
    @unknown default:
        return "scheduled"
    }
}

private func weekdayNumber(_ day: Locale.Weekday) -> Int {
    switch day {
    case .monday: return 1
    case .tuesday: return 2
    case .wednesday: return 3
    case .thursday: return 4
    case .friday: return 5
    case .saturday: return 6
    case .sunday: return 7
    @unknown default: return 1
    }
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
