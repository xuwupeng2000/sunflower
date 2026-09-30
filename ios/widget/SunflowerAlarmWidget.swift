import ActivityKit
import AlarmKit
import SunflowerShared
import SwiftUI
import WidgetKit

private let flowerURL = URL(string: "sunflower://flower")!
private let alarmBannerWidth: CGFloat = 360
// 和 App 里 theme/ui.tres 同一套颜色：蓝天、白云、软黄按钮。
private let skyTop = Color(red: 150.0 / 255.0, green: 204.0 / 255.0, blue: 244.0 / 255.0)
private let skyBottom = Color(red: 222.0 / 255.0, green: 240.0 / 255.0, blue: 252.0 / 255.0)
private let skyAccent = Color(red: 169.0 / 255.0, green: 212.0 / 255.0, blue: 245.0 / 255.0)
private let ink = Color(red: 34.0 / 255.0, green: 56.0 / 255.0, blue: 74.0 / 255.0)
private let softYellow = Color(red: 243.0 / 255.0, green: 210.0 / 255.0, blue: 122.0 / 255.0)
private let softYellowText = Color(red: 90.0 / 255.0, green: 66.0 / 255.0, blue: 20.0 / 255.0)
private let softRed = Color(red: 181.0 / 255.0, green: 101.0 / 255.0, blue: 90.0 / 255.0)

// Widget 目标链接共享的 SunflowerShared，铃声是主包里的 sunflower.wav。

@main
struct SunflowerAlarmWidgetBundle: WidgetBundle {
    var body: some Widget {
        SunflowerAlarmLiveActivity()
        SunflowerTimerLiveActivity()
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
                .foregroundStyle(ink)
                .background(SkyBackground())
                .frame(maxWidth: .infinity)
                .widgetURL(flowerURL)
                .activityBackgroundTint(.clear)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 4) {
                        alarmTimeText(context)
                            .foregroundStyle(.white)
                        eventList(context.attributes.metadata?.events ?? "", fallback: Copy.text("向日葵闹钟", "Sunflower Alarm"))
                            .foregroundStyle(skyAccent)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        SkyStrip(height: 34)
                        if isSnoozing(context) {
                            cancelSnoozeButton(context)
                        }
                    }
                }
            } compactLeading: {
                FlowerMark(size: 20)
            } compactTrailing: {
                CloudMark(width: 26, color: skyAccent)
            } minimal: {
                FlowerMark(size: 16)
            }
            .keylineTint(skyAccent)
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
                cancelSnoozeButton(context)
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
                cancelSnoozeButton(context)
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

    private func isSnoozing(_ context: ActivityViewContext<AlarmAttributes<SunflowerMetadata>>) -> Bool {
        switch context.state.mode {
        case .countdown, .paused:
            return true
        default:
            return false
        }
    }

    private func cancelSnoozeButton(_ context: ActivityViewContext<AlarmAttributes<SunflowerMetadata>>) -> some View {
        Button(intent: CancelSnoozeIntent(logicalID: context.attributes.metadata?.alarmId ?? "")) {
            Text(Copy.text("取消推迟", "Cancel snooze"))
                .font(.headline)
                .foregroundStyle(ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.white.opacity(0.9), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func flowerLink() -> some View {
        Link(destination: flowerURL) {
            Text(Copy.text("看花", "See the flower"))
                .font(.headline)
                .foregroundStyle(softYellowText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(softYellow, in: Capsule())
        }
    }

    private func eventList(_ events: String, fallback: String) -> some View {
        let lines = events.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
        return Text(lines.isEmpty ? fallback : lines.joined(separator: "\n"))
    }
}

struct SunflowerTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SunflowerTimerAttributes.self) { context in
            VStack(alignment: .leading, spacing: 10) {
                timerHeadline(context, digits: 34)
                if !context.isStale {
                    timerProgress(context.attributes)
                    Text(timerNote(context.attributes))
                        .font(.caption)
                        .foregroundStyle(ink.opacity(0.6))
                }
                HStack(spacing: 10) {
                    Spacer(minLength: 0)
                    if !context.isStale {
                        cancelTimerButton(context.attributes)
                    }
                    flowerLink()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: alarmBannerWidth)
            .foregroundStyle(ink)
            .background(SkyBackground())
            .frame(maxWidth: .infinity)
            .widgetURL(flowerURL)
            .activityBackgroundTint(.clear)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    timerHeadline(context, digits: 30)
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.isStale {
                        EmptyView()
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            timerProgress(context.attributes)
                            HStack {
                                Text(timerNote(context.attributes))
                                    .font(.caption)
                                    .foregroundStyle(skyAccent)
                                Spacer(minLength: 8)
                                cancelTimerButton(context.attributes)
                            }
                        }
                    }
                }
            } compactLeading: {
                Text(context.attributes.emoji)
            } compactTrailing: {
                if context.isStale {
                    Text(Copy.text("到了", "Done"))
                        .foregroundStyle(skyAccent)
                } else {
                    Text(timerInterval: context.attributes.startDate...context.attributes.endDate, countsDown: true)
                        .monospacedDigit()
                        .foregroundStyle(skyAccent)
                        .frame(maxWidth: 52)
                }
            } minimal: {
                ProgressView(
                    timerInterval: context.attributes.startDate...context.attributes.endDate,
                    countsDown: true,
                    label: { EmptyView() },
                    currentValueLabel: { Text(context.attributes.emoji).font(.caption2) }
                )
                .progressViewStyle(.circular)
                .tint(skyAccent)
            }
            .keylineTint(skyAccent)
        }
    }

    @ViewBuilder
    private func timerHeadline(_ context: ActivityViewContext<SunflowerTimerAttributes>, digits: CGFloat) -> some View {
        let attributes = context.attributes
        VStack(alignment: .leading, spacing: 2) {
            Text("\(attributes.emoji) \(attributes.name)")
                .font(.headline)
                .lineLimit(1)
            if context.isStale {
                Text(Copy.text("时间到了", "Time's up"))
                    .font(.system(size: digits, weight: .bold))
            } else {
                Text(timerInterval: attributes.startDate...attributes.endDate, countsDown: true)
                    .font(.system(size: digits, weight: .bold))
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func timerProgress(_ attributes: SunflowerTimerAttributes) -> some View {
        HStack(spacing: 8) {
            FlowerMark(size: 20)
            ProgressView(timerInterval: attributes.startDate...attributes.endDate, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.linear)
            .tint(softYellow)
        }
    }

    private func timerNote(_ attributes: SunflowerTimerAttributes) -> String {
        let minutes = max(1, Int((attributes.endDate.timeIntervalSince(attributes.startDate) / 60).rounded()))
        let parts = Calendar.current.dateComponents([.hour, .minute], from: attributes.endDate)
        let hour = parts.hour ?? 0
        let minute = parts.minute ?? 0
        let shown = hour % 12 == 0 ? 12 : hour % 12
        let length: String
        if minutes < 60 {
            length = Copy.text("\(minutes) 分钟", "\(minutes) min")
        } else if minutes % 60 == 0 {
            length = Copy.text("\(minutes / 60) 小时", "\(minutes / 60) h")
        } else {
            length = Copy.text("\(minutes / 60) 小时 \(minutes % 60) 分钟", "\(minutes / 60) h \(minutes % 60) min")
        }
        let clock = String(format: "%d:%02d", shown, minute)
        return Copy.text(
            "共 \(length) · \(hour < 12 ? "上午" : "下午") \(clock) 到",
            "\(length) · done at \(clock) \(hour < 12 ? "am" : "pm")"
        )
    }

    private func cancelTimerButton(_ attributes: SunflowerTimerAttributes) -> some View {
        Button(intent: CancelTimerIntent(timerID: attributes.timerId)) {
            Text(Copy.text("取消", "Cancel"))
                .font(.headline)
                .foregroundStyle(softRed)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.white.opacity(0.9), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func flowerLink() -> some View {
        Link(destination: flowerURL) {
            Text(Copy.text("看花", "See the flower"))
                .font(.headline)
                .foregroundStyle(softYellowText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(softYellow, in: Capsule())
        }
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

private struct CloudMark: View {
    var width: CGFloat = 40
    var color: Color = .white

    var body: some View {
        let height = width * 0.56
        ZStack(alignment: .bottom) {
            Capsule()
                .frame(width: width, height: height * 0.56)
            Circle()
                .frame(width: height * 0.72, height: height * 0.72)
                .offset(x: -width * 0.2, y: -height * 0.2)
            Circle()
                .frame(width: height * 0.96, height: height * 0.96)
                .offset(x: width * 0.1, y: -height * 0.04)
        }
        .foregroundStyle(color)
        .frame(width: width, height: height, alignment: .bottom)
    }
}

/// 锁屏横幅的底：上深下浅的天空，角上飘两朵云。
private struct SkyBackground: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        LinearGradient(colors: [skyTop, skyBottom], startPoint: .top, endPoint: .bottom)
            .overlay(alignment: .topLeading) {
                CloudMark(width: 68).opacity(0.85).offset(x: 150, y: -12)
            }
            .overlay(alignment: .bottomLeading) {
                CloudMark(width: 56).opacity(0.7).offset(x: 64, y: 16)
            }
            .overlay(alignment: .bottomTrailing) {
                CloudMark(width: 44).opacity(0.6).offset(x: -118, y: 12)
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(.white.opacity(0.7), lineWidth: 2))
    }
}

/// 灵动岛展开时底下那一条小天空，花在里面慢慢长大往前走。
private struct SkyStrip: View {
    var height: CGFloat = 34

    var body: some View {
        GeometryReader { box in
            ZStack(alignment: .leading) {
                LinearGradient(colors: [skyTop, skyBottom], startPoint: .top, endPoint: .bottom)
                CloudMark(width: height * 1.2).opacity(0.9).offset(x: box.size.width * 0.58, y: -height * 0.12)
                CloudMark(width: height * 0.8).opacity(0.7).offset(x: box.size.width * 0.22, y: height * 0.14)
                GrowingFlower(flowerSize: height * 0.72, track: box.size.width - 8)
                    .padding(.leading, 4)
            }
            .clipShape(Capsule())
        }
        .frame(height: height)
    }
}
