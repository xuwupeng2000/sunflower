---
name: alarm-save
description: >-
  Keeps Sunflower Alarm's user://sunflower_alarms.json compatible across
  shipped builds. Use when editing alarm_store.gd load_data or save_data,
  the alarm JSON shape, migrations, tutorial_v, once_tutorial_v,
  flower_kind_v, or before an App Store release that touches saved alarms,
  tasks, once reminders, skips, or flower state.
---

# 闹钟存档兼容

文件是 `user://sunflower_alarms.json`，一个 JSON 对象。已发布的新版本必须能打开旧版本写下的这份文件，闹钟、任务、单次提醒、跳过、肥料、花和盆、正在走的计时都不能丢。

字段形状见 [schema.md](schema.md)。

## 怎么兼容

新版本读旧文件（必须）。旧版本碰到新文件时，不认识的键要能忽略，所以已有键的类型不能变。

- 缺键就是旧文件。用 `data.get(key, 默认值)`，默认值要和「这个字段还没发明时」的行为一样。
- 多出来的键丢掉，不要因为不认识就整份不读。只有根不是对象时才放弃整份文件。坏掉的一条跳过，不要清掉整份。
- 加可选字段：只在写出时带上，读的时候有默认值。不要一读到缺这个键就把用户的文件判成损坏。
- 旧字段要改意思：留着旧键，另加一个整数 `*_v`，在 `load_data` 里按旧版本迁移。已经在用的是 `flower_kind_v`、`tutorial_v`、`once_tutorial_v`。不要新造一个总版本号来代替它们，除非这次改动同时改了很多键、一个 `*_v` 盖不住。
- 不要改已经发出去的键的名字、不要删键、不要把数字改成字符串（或反过来），除非 `load_data` 还读得懂旧样子。
- `tutorial_v` 和 `once_tutorial_v` 只决定教程要不要重播。改存档结构时不要顺手把它们加大。

## 谁是源数据

`days`、`tasks`、`once_reminders`、`skips` 才是用户设的闹钟。每次 `load_data` 都会用它们重算 `alarms`。`_normalize_alarm` 会丢掉 `date`、`skip_dates`、`lead_minutes`、`event_hour`、`event_minute`。

用户的选择只写进上面四个源字段。不要只写进 `alarms`，下次打开会被盖掉。

## 不能改的 id

贪睡记录和系统闹钟都靠这些字符串。改了，旧的贪睡和已经排进去的闹钟会对不上。

- `wake-1` … `wake-7`，`sleep-1` … `sleep-7`（1 是周一，7 是周日）
- `task-{任务id}-{星期}`，结束铃是 `task-{任务id}-{星期}-end`
- `once-{单次id}`
- 跳过的 key：睡觉是 `sleep`，任务是 `task-{任务id}`
- 单次例子的 id 固定是 `sample-once`

`days` 和 `tasks.times` 永远是 7 格，下标 0 是周一。日期是本地的 `YYYY-MM-DD`。钟点是 0–23 时、0–59 分。任务和单次提醒里的 `hour`/`minute` 是到达时间，`lead_minutes` 是提前多少分钟响。

## 改存档之前

1. 对照 [schema.md](schema.md)，列出这次要加、要改意思、要停用的键。
2. 旧文件缺新键时，行为必须和改之前一样。
3. 迁移只放在 `load_data`（或它叫到的 `_load_*`）里，读完再保存。
4. 用一份上一版发出去的存档打开一遍：闹钟还在、单次提醒还在、花和盆没变、计时没被清掉。
