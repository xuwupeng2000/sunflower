import AlarmKit
import AppIntents
import SunflowerShared

// 这个文件同时编进主 App 和 Widget 两个目标。
// Live Activity 上的按钮用 LiveActivityIntent，系统会在主 App 进程里执行它，
// 所以这里能直接结束 App 建的 Live Activity、停掉 AlarmKit 闹钟。
// 放在 SunflowerShared.xcframework 里不行：预编译的框架不会生成 App Intents 元数据，按钮点了没反应。

/// 结束这一次推迟倒计时或响铃；每周闹钟照常。
struct CancelSnoozeIntent: LiveActivityIntent {
    // App Intents 元数据要求标题是字面量；按钮上显示的文字由 Widget 视图自己翻译。
    static var title: LocalizedStringResource = "Cancel snooze"
    static var openAppWhenRun = false

    @Parameter(title: "Group")
    var logicalID: String

    @Parameter(title: "Kit")
    var kitID: String

    init() {
        logicalID = ""
        kitID = ""
    }

    init(logicalID: String, kitID: String) {
        self.init()
        self.logicalID = logicalID
        self.kitID = kitID
    }

    func perform() async throws -> some IntentResult {
        Haptics.tap(.rigid)
        if let direct = UUID(uuidString: kitID) {
            try? AlarmManager.shared.stop(id: direct)
        } else if let hashed = alarmUUID(logicalID) {
            try? AlarmManager.shared.stop(id: hashed)
        }
        return .result()
    }
}

/// 取消本次计时：去掉到点通知，收掉 Live Activity；App 回到前台时清掉计时页。
struct CancelTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Cancel timer"
    static var openAppWhenRun = false

    @Parameter(title: "Timer")
    var timerID: String

    init() {
        timerID = ""
    }

    init(timerID: String) {
        self.init()
        self.timerID = timerID
    }

    func perform() async throws -> some IntentResult {
        Haptics.tap(.rigid)
        SunflowerTimer.markCancelled(timerID)
        await SunflowerTimer.cancel(timerID)
        return .result()
    }
}
