import ActivityKit
import AlarmKit
import SunflowerShared
import SwiftUI
import WidgetKit

private let flowerURL = URL(string: "sunflower://flower")!
private let sunflowerYellow = Color(red: 244.0 / 255.0, green: 196.0 / 255.0, blue: 64.0 / 255.0)
private let alarmBannerWidth: CGFloat = 360

// Widget 目标链接共享的 SunflowerShared，铃声是主包里的 sunflower.wav。

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
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: alarmBannerWidth)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .frame(maxWidth: .infinity)
                .widgetURL(flowerURL)
                .activityBackgroundTint(.clear)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 4) {
                        alarmTimeText(context)
                        eventList(context.attributes.metadata?.events ?? "", fallback: Copy.text("向日葵闹钟", "Sunflower Alarm"))
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        GrowingFlower(flowerSize: 28, track: 64)
                        Spacer(minLength: 12)
                        GrowingFlower(flowerSize: 28, track: 64)
                    }
                }
            } compactLeading: {
                GrowingFlower(flowerSize: 20, track: 64)
            } compactTrailing: {
                GrowingFlower(flowerSize: 20, track: 64)
            } minimal: {
                FlowerMark(size: 16)
            }
            .keylineTint(sunflowerYellow)
        }
    }

    @ViewBuilder
    private func countdownBody(_ context: ActivityViewContext<AlarmAttributes<SunflowerMetadata>>) -> some View {
        switch context.state.mode {
        case .countdown:
            HStack(spacing: 12) {
                FlowerMark(size: 28)
                VStack(alignment: .leading, spacing: 2) {
                    alarmTimeText(context)
                    eventList(context.attributes.metadata?.events ?? "", fallback: Copy.text("推迟倒计时", "Postpone"))
                        .font(.caption)
                }
                Spacer(minLength: 8)
                flowerLink()
            }
            .frame(maxWidth: .infinity)
            .onAppear {
                SnoozeStore.recordCountdown(alarmId: context.attributes.metadata?.alarmId ?? "")
            }
        case .paused:
            HStack(spacing: 12) {
                FlowerMark(size: 28)
                VStack(alignment: .leading, spacing: 2) {
                    alarmTimeText(context)
                    Text(Copy.text("已暂停", "Paused"))
                        .font(.caption)
                }
                Spacer(minLength: 8)
                flowerLink()
            }
            .frame(maxWidth: .infinity)
        default:
            VStack(alignment: .leading, spacing: 8) {
                alarmTimeText(context)
                eventList(context.attributes.metadata?.events ?? "", fallback: Copy.text("向日葵闹钟", "Sunflower Alarm"))
                HStack {
                    Spacer(minLength: 0)
                    flowerLink()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

private struct FlowerMark: View {
    var size: CGFloat = 22

    var body: some View {
        let petal = Color(red: 242.0 / 255.0, green: 193.0 / 255.0, blue: 78.0 / 255.0)
        let disk = Color(red: 107.0 / 255.0, green: 58.0 / 255.0, blue: 22.0 / 255.0)
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                Capsule()
                    .fill(petal)
                    .frame(width: size * 0.22, height: size * 0.42)
                    .offset(y: -size * 0.24)
                    .rotationEffect(.degrees(Double(index) * 45))
            }
            Circle()
                .fill(disk)
                .frame(width: size * 0.36, height: size * 0.36)
        }
        .frame(width: size, height: size)
    }
}

private struct GrowingFlower: View {
    var flowerSize: CGFloat = 22
    var track: CGFloat = 64
    private let cycle = 2.8

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
            let progress = timeline.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: cycle) / cycle
            let travel = max(track - flowerSize, 1)
            let fade = progress < 0.82 ? 1.0 : max(0, 1.0 - (progress - 0.82) / 0.18)
            ZStack(alignment: .leading) {
                FlowerMark(size: flowerSize)
                    .scaleEffect(0.62 + 0.38 * progress)
                    .opacity(fade)
                    .offset(x: progress * travel)
            }
            .frame(width: track, height: flowerSize, alignment: .leading)
            .clipped()
        }
        .frame(width: track, height: flowerSize)
    }
}

    private func alarmTimeText(_ context: ActivityViewContext<AlarmAttributes<SunflowerMetadata>>) -> Text {
        Text(scheduledClock(context))
            .font(.headline)
            .monospacedDigit()
    }

    private func scheduledClock(_ context: ActivityViewContext<AlarmAttributes<SunflowerMetadata>>) -> String {
        if case .alert(let alert) = context.state.mode {
            return String(format: "%02d:%02d", alert.time.hour, alert.time.minute)
        }
        let parts = (context.attributes.metadata?.alarmId ?? "").split(separator: "-")
        guard parts.count >= 4,
              let hour = Int(parts[parts.count - 2]),
              let minute = Int(parts[parts.count - 1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return ""
        }
        return String(format: "%02d:%02d", hour, minute)
    }

    private func flowerLink() -> some View {
        Link(destination: flowerURL) {
            Text(Copy.text("看花", "See the flower"))
                .font(.headline)
                .foregroundStyle(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.yellow, in: Capsule())
        }
    }

    private func eventList(_ events: String, fallback: String) -> some View {
        let lines = events.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
        return Text(lines.isEmpty ? fallback : lines.joined(separator: "\n"))
    }
}
