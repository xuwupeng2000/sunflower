import AlarmKit
import AppIntents
import SwiftUI

struct SunflowerMetadata: AlarmMetadata {
    let alarmId: String
}

struct OpenFlowerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "看花"
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}
