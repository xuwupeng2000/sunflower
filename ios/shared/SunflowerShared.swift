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
    /// "zh" Simplified, "zh_TW" Traditional, "en" English, then the rest by ISO code — the same codes the Godot side uses.
    public static let languages = ["zh", "zh_TW", "en", "ja", "ko", "de", "fr", "it", "es", "ru"]

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
        guard first.hasPrefix("zh") else {
            let base = String(first.prefix { $0 != "-" })
            return languages.contains(base) ? base : "en"
        }
        let traditional = ["hant", "-tw", "-hk", "-mo"].contains { first.contains($0) }
        return traditional ? "zh_TW" : "zh"
    }

    public static func text(_ zh: String, _ en: String, hant: String) -> String {
        switch language {
        case "zh": return zh
        case "zh_TW": return hant
        case "en": return en
        default: return more[en]?[language] ?? en
        }
    }

    /// Clock text for lock-screen copy: 12-hour where people say it that way, 24-hour in Europe.
    public static func clock(hour: Int, minute: Int) -> String {
        let shown = hour % 12 == 0 ? 12 : hour % 12
        let twelve = String(format: "%d:%02d", shown, minute)
        switch language {
        case "zh", "zh_TW": return "\(hour < 12 ? "上午" : "下午") \(twelve)"
        case "ja": return "\(hour < 12 ? "午前" : "午後")\(twelve)"
        case "ko": return "\(hour < 12 ? "오전" : "오후") \(twelve)"
        case "en": return "\(twelve) \(hour < 12 ? "am" : "pm")"
        default: return String(format: "%d:%02d", hour, minute)
        }
    }

    /// Keyed by the English text passed to `text`. Missing entries fall back to English.
    static let more: [String: [String: String]] = [
        "Wake up": ["ja": "起床", "ko": "기상", "de": "Aufstehen", "fr": "Réveil", "it": "Sveglia", "es": "Despertar", "ru": "Подъём"],
        "Time's up ☁️": ["ja": "時間だよ ☁️", "ko": "시간 다 됐어요 ☁️", "de": "Zeit ist um ☁️", "fr": "C'est l'heure ☁️", "it": "Tempo scaduto ☁️", "es": "¡Se acabó el tiempo! ☁️", "ru": "Время вышло ☁️"],
        "Time's up": ["ja": "時間だよ", "ko": "시간 다 됐어요", "de": "Zeit ist um", "fr": "C'est l'heure", "it": "Tempo scaduto", "es": "Se acabó el tiempo", "ru": "Время вышло"],
        "Stop": ["ja": "停止", "ko": "중단", "de": "Stopp", "fr": "Arrêter", "it": "Stop", "es": "Detener", "ru": "Стоп"],
        "Snooze 9 min": ["ja": "9分スヌーズ", "ko": "9분 뒤 다시 알림", "de": "9 Min. schlummern", "fr": "Reporter 9 min", "it": "Posticipa 9 min", "es": "Posponer 9 min", "ru": "Отложить на 9 мин"],
        "Again in 9 min": ["ja": "9分後にまた鳴るよ", "ko": "9분 뒤 다시 울려요", "de": "In 9 Min. wieder", "fr": "Ça re-sonne dans 9 min", "it": "Risuona tra 9 min", "es": "Vuelve a sonar en 9 min", "ru": "Снова через 9 мин"],
        "Pause": ["ja": "一時停止", "ko": "일시정지", "de": "Pause", "fr": "Pause", "it": "Pausa", "es": "Pausar", "ru": "Пауза"],
        "Resume": ["ja": "再開", "ko": "계속", "de": "Weiter", "fr": "Reprendre", "it": "Riprendi", "es": "Reanudar", "ru": "Продолжить"],
        "Paused": ["ja": "一時停止中", "ko": "일시정지됨", "de": "Pausiert", "fr": "En pause", "it": "In pausa", "es": "En pausa", "ru": "На паузе"],
        "Little Flower": ["ja": "ちいさな花", "ko": "작은 꽃 알람", "de": "Kleine Blume", "fr": "Petite Fleur", "it": "Fiorellino", "es": "Florecita", "ru": "Цветочек"],
        "Snoozing": ["ja": "スヌーズ中", "ko": "다시 알림 대기 중", "de": "Schlummert", "fr": "En report", "it": "Posticipata", "es": "Pospuesta", "ru": "Отложено"],
        "Cancel snooze": ["ja": "スヌーズを取り消す", "ko": "다시 알림 취소", "de": "Schlummern beenden", "fr": "Annuler le report", "it": "Annulla posticipo", "es": "Cancelar aplazamiento", "ru": "Отменить отсрочку"],
        "See your flower": ["ja": "花を見る", "ko": "꽃 보러 가기", "de": "Zur Blume", "fr": "Voir ta fleur", "it": "Guarda il fiore", "es": "Ver tu flor", "ru": "К цветку"],
        "Done": ["ja": "完了", "ko": "완료", "de": "Fertig", "fr": "Terminé", "it": "Fatto", "es": "Listo", "ru": "Готово"],
        "Cancel timer": ["ja": "タイマーを取り消す", "ko": "타이머 취소", "de": "Timer abbrechen", "fr": "Annuler le minuteur", "it": "Annulla timer", "es": "Cancelar temporizador", "ru": "Отменить таймер"],
        ", ": ["ja": "、"],
        "%d min": ["ja": "%d分", "ko": "%d분", "de": "%d Min.", "ru": "%d мин"],
        "%d hr": ["ja": "%d時間", "ko": "%d시간", "de": "%d Std.", "fr": "%d h", "it": "%d h", "es": "%d h", "ru": "%d ч"],
        "%d hr %d min": ["ja": "%d時間%d分", "ko": "%d시간 %d분", "de": "%d Std. %d Min.", "fr": "%d h %d min", "it": "%d h %d min", "es": "%d h %d min", "ru": "%d ч %d мин"],
        "%@ · done at %@": ["ja": "%@ · %@に終わるよ", "ko": "%@ · %@ 종료", "de": "%@ · fertig um %@", "fr": "%@ · fini à %@", "it": "%@ · finisce alle %@", "es": "%@ · termina a las %@", "ru": "%@ · готово в %@"],
    ]
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
