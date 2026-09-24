import ActivityKit
import AlarmKit
import SwiftUI
import WidgetKit

// Widget 目标还要编译 ../plugins/alarm_kit/SnoozeStore.swift 和 SunflowerShared.swift，
// 并把 ios/sounds/sunflower.caf 打进主 App 和这个扩展。

@main
struct SunflowerAlarmWidgetBundle: WidgetBundle {
    var body: some Widget {
        SunflowerAlarmLiveActivity()
    }
}

struct SunflowerAlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<SunflowerMetadata>.self) { context in
            countdownBody(context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text("再睡一会儿")
                }
            } compactLeading: {
                Image(systemName: "sun.max.fill")
            } compactTrailing: {
                Text("向日葵")
            } minimal: {
                Image(systemName: "sun.max.fill")
            }
        }
    }

    @ViewBuilder
    private func countdownBody(_ context: ActivityViewContext<AlarmAttributes<SunflowerMetadata>>) -> some View {
        switch context.state.mode {
        case .countdown:
            HStack {
                Image(systemName: "sun.max.fill")
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading) {
                    Text("再睡一会儿")
                    Text("贪睡倒计时")
                        .font(.caption)
                }
                Spacer()
                Button(intent: OpenFlowerIntent()) {
                    Text("看花")
                }
                .buttonStyle(.borderedProminent)
                .tint(.yellow)
            }
            .padding()
            .onAppear {
                SnoozeStore.recordCountdown(alarmId: context.attributes.metadata.alarmId)
            }
        case .paused:
            HStack {
                Image(systemName: "sun.max.fill")
                Text("已暂停")
                Spacer()
                Button(intent: OpenFlowerIntent()) {
                    Text("看花")
                }
            }
            .padding()
        default:
            HStack {
                Image(systemName: "sun.max.fill")
                Text(context.attributes.metadata.alarmId.isEmpty ? "向日葵闹钟" : "向日葵闹钟")
            }
            .padding()
        }
    }
}
