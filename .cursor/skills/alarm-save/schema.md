# sunflower_alarms.json

当前 `save_data` 写出的形状。读的时候缺键用这里的默认值。

## 根

| 键 | 类型 | 缺了的时候 |
|---|---|---|
| `alarms` | 对象数组 | `[]`。加载后会被重算，见 SKILL.md |
| `snoozes` | 对象数组 | `[]` |
| `care` | 对象数组 | `[]` |
| `days` | 长度 7 的对象数组 | 补满 7 天：起床 7:00，睡觉 23:00，`enabled` true |
| `tasks` | 对象数组 | `[]` |
| `skips` | 对象数组 | `[]` |
| `scheduled_ids` | 字符串数组 | `[]` |
| `tutorial_seen` | bool | false |
| `tutorial_v` | int | 1。只有 `tutorial_seen` 且 `>= 4` 才算看过闹钟教程 |
| `timer_tutorial_seen` | bool | false |
| `once_tutorial_seen` | bool | false |
| `once_tutorial_v` | int | 1。只有 `once_tutorial_seen` 且 `>= 3` 才算看过行程教程 |
| `sleep_present` | bool | true。旧文件若为 false，睡觉照样在，但 `sleep_paused` 视为 true |
| `sleep_paused` | bool | false |
| `fertilizer` | int | 用睡觉贪睡次数减去 `fertilizer_used` |
| `fertilizer_used` | int | 没有或小于 0 时，按 `care` 里 `feed` 的条数算 |
| `last_watered` | `YYYY-MM-DD` | 今天 |
| `custom_timers` | 对象数组 | `[]` |
| `active_timer` | 对象 | 没有 `ends_at` 就是没在计时 |
| `once_reminders` | 对象数组 | `[]` |
| `flower_kind` | int | 0 |
| `flower_kind_v` | int | 1。小于 2 时按旧编号迁移（见下） |
| `pot_kind` | int | 0，读入后夹到 0–4 |

`flower_kind_v` 小于 2 时，旧的 `flower_kind`：0 蜀葵和 3 玫瑰变成 0 向日葵，1 向日葵变成 0，2 兰花变成 1。现在 0 是向日葵，1 是兰花。

## days[]

`wake_hour` `wake_minute` `sleep_hour` `sleep_minute` `enabled`。下标 0 是周一。

## tasks[]

`id` `name` `paused` `times`。`times` 长度 7，下标 0 是周一。

每一格：`hour` `minute` `enabled`。可选：`lead_minutes`（大于 0 才写）、`paused`、`end_hour` 和 `end_minute`（有结束铃才写）。`hour`/`minute` 是开始的到达时间。

## once_reminders[]

`id` `name` `date` `hour` `minute` `lead_minutes`。`hour`/`minute` 是到达时间。例子的 `id` 是 `sample-once`。

## skips[]

`date` `key`。`key` 是 `sleep` 或 `task-{任务id}`。

## snoozes[]

`date` `alarm_id` `at`（unix 秒）。

## care[]

`date` `kind`（`water` 或 `feed`）`at`。别的 `kind` 丢掉。

## custom_timers[]

`title` `minutes`（至少 1）。

## active_timer

`id` `title` `minutes` `ends_at`。空对象表示没在计时。

## alarms[]（重算结果，不是源）

`id` `hour` `minute` `weekdays`（一个星期数字）`label` `enabled` `skip_dates`。单次才有 `date`。有提前量才有 `event_hour` `event_minute` `lead_minutes`。

`id` 只有这几种：`wake-N`、`sleep-N`、`task-{id}-N`、`task-{id}-N-end`、`once-{id}`。`N` 是 1–7。
