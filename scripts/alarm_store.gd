extends Node

const SAVE_PATH := "user://sunflower_alarms.json"
const WEEKDAY_NAMES := ["一", "二", "三", "四", "五", "六", "日"]

var alarms: Array[Dictionary] = []
var snoozes: Array[Dictionary] = []
var care: Array[Dictionary] = []
var fertilizer := 0
var fertilizer_used := 0
var last_watered := ""
var language := "zh"
const LANGUAGES := ["zh", "zh_TW", "en"]
const LANGUAGE_FILES := ["res://locale/ui.en.translation", "res://locale/ui.zh_TW.translation"]
var tutorial_seen := false
var timer_tutorial_seen := false
var sleep_present := true
var sleep_paused := false
## 计时页里自己加的计时：{title, minutes}。
var custom_timers: Array[Dictionary] = []
## 正在走的那一个：{id, title, minutes, ends_at}；空字典就是没在计时。
var active_timer: Dictionary = {}
## 看花页选的花和盆，对应 Sunflower.FLOWER_KINDS / POT_KINDS 的下标。
var flower_kind := 0
var pot_kind := 0

signal changed


func _ready() -> void:
	_install_locale()
	load_data()


var _translations: Array[Translation] = []


func _install_locale() -> void:
	for path in LANGUAGE_FILES:
		var packed := load(path)
		if packed is Translation:
			_translations.append(packed)
	language = _settings_language()
	_apply_locale()


## Godot 会把 "zh" 模糊匹配到 "zh_TW"，所以选简体时要把繁体翻译摘掉，只留跟当前语言一致的那份。
func _apply_locale() -> void:
	for translation in _translations:
		TranslationServer.remove_translation(translation)
		if translation.locale == language:
			TranslationServer.add_translation(translation)
	TranslationServer.set_locale(language)


func load_data() -> void:
	alarms.clear()
	snoozes.clear()
	care.clear()
	if not FileAccess.file_exists(SAVE_PATH):
		_ensure_days()
		_sync_day_alarms()
		last_watered = today_key()
		changed.emit()
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("无法读取闹钟存档")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	for item in data.get("alarms", []):
		if typeof(item) == TYPE_DICTIONARY:
			alarms.append(_normalize_alarm(item))
	for item in data.get("snoozes", []):
		if typeof(item) == TYPE_DICTIONARY:
			snoozes.append({
				"date": str(item.get("date", "")),
				"alarm_id": str(item.get("alarm_id", "")),
				"at": int(item.get("at", 0)),
			})
	for item in data.get("care", []):
		if typeof(item) == TYPE_DICTIONARY:
			var kind := str(item.get("kind", ""))
			if kind != "water" and kind != "feed":
				continue
			care.append({
				"date": str(item.get("date", "")),
				"kind": kind,
				"at": int(item.get("at", 0)),
			})
	_load_tasks(data.get("tasks", []))
	# 睡觉不能删了；以前删掉的接回来，但先暂停，免得突然响。
	sleep_present = true
	sleep_paused = bool(data.get("sleep_paused", false)) or not bool(data.get("sleep_present", true))
	_load_skips(data.get("skips", []))
	_load_days(data.get("days", []))
	tutorial_seen = bool(data.get("tutorial_seen", false)) and int(data.get("tutorial_v", 1)) >= 4
	timer_tutorial_seen = bool(data.get("timer_tutorial_seen", false))
	scheduled_ids.clear()
	for item in data.get("scheduled_ids", []):
		scheduled_ids.append(str(item))
	_load_fertilizer(data)
	_load_timers(data)
	flower_kind = int(data.get("flower_kind", 0))
	pot_kind = int(data.get("pot_kind", 0))
	# 以前 0 蜀葵 / 1 向日葵 / 2 兰花 / 3 玫瑰，现在只留向日葵和兰花。
	if int(data.get("flower_kind_v", 1)) < 2:
		flower_kind = {1: 0, 2: 1}.get(flower_kind, 0)
	flower_kind = clampi(flower_kind, 0, 1)
	pot_kind = clampi(pot_kind, 0, 4)
	changed.emit()


func save_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("无法写入闹钟存档")
		return
	file.store_string(JSON.stringify({
		"alarms": alarms,
		"snoozes": snoozes,
		"care": care,
		"days": days,
		"tasks": tasks,
		"skips": skips,
		"scheduled_ids": scheduled_ids,
		"tutorial_seen": tutorial_seen,
		"tutorial_v": 4,
		"timer_tutorial_seen": timer_tutorial_seen,
		"sleep_present": sleep_present,
		"sleep_paused": sleep_paused,
		"fertilizer": fertilizer,
		"fertilizer_used": fertilizer_used,
		"last_watered": last_watered,
		"custom_timers": custom_timers,
		"active_timer": active_timer,
		"flower_kind": flower_kind,
		"flower_kind_v": 2,
		"pot_kind": pot_kind,
	}, "  "))


func set_style(flower: int, pot: int) -> void:
	flower_kind = flower
	pot_kind = pot
	save_data()


func _load_timers(data: Dictionary) -> void:
	custom_timers.clear()
	for item in data.get("custom_timers", []):
		if typeof(item) == TYPE_DICTIONARY:
			custom_timers.append({
				"title": str(item.get("title", "")),
				"minutes": maxi(1, int(item.get("minutes", 1))),
			})
	var active: Variant = data.get("active_timer", {})
	active_timer = {}
	if typeof(active) == TYPE_DICTIONARY and active.has("ends_at"):
		active_timer = {
			"id": str(active.get("id", "")),
			"title": str(active.get("title", "")),
			"minutes": maxi(1, int(active.get("minutes", 1))),
			"ends_at": float(active.get("ends_at", 0.0)),
		}


func start_timer(title: String, minutes: int) -> Dictionary:
	var now := Time.get_unix_time_from_system()
	active_timer = {
		"id": str(int(now * 1000.0)),
		"title": title,
		"minutes": maxi(1, minutes),
		"ends_at": now + maxi(1, minutes) * 60.0,
	}
	save_data()
	return active_timer


func clear_timer() -> void:
	if active_timer.is_empty():
		return
	active_timer = {}
	save_data()


func add_custom_timer(title: String, minutes: int) -> void:
	custom_timers.append({"title": title, "minutes": maxi(1, minutes)})
	save_data()


func remove_custom_timer(index: int) -> void:
	if index < 0 or index >= custom_timers.size():
		return
	custom_timers.remove_at(index)
	save_data()


func set_sleep_paused(paused: bool) -> void:
	sleep_paused = paused
	_sync_day_alarms()
	save_data()
	changed.emit()


func task_paused(index: int) -> bool:
	if index < 0 or index >= tasks.size():
		return false
	return bool(tasks[index].get("paused", false))


func set_task_paused(index: int, paused: bool) -> void:
	if index < 0 or index >= tasks.size():
		return
	tasks[index]["paused"] = paused
	_sync_day_alarms()
	save_data()
	changed.emit()


## 教程只放一次；只有电脑上的调试运行每次都放，方便调。
func replay_tutorials() -> bool:
	return OS.is_debug_build() and OS.has_feature("pc")


func mark_tutorial_seen() -> void:
	if tutorial_seen:
		return
	tutorial_seen = true
	save_data()


func mark_timer_tutorial_seen() -> void:
	if timer_tutorial_seen:
		return
	timer_tutorial_seen = true
	save_data()


func apply_system_setting() -> bool:
	var next := _settings_language()
	if next == language:
		return false
	language = next
	_apply_locale()
	return true


func _settings_language() -> String:
	if Engine.has_singleton("AlarmKit"):
		var native := Engine.get_singleton("AlarmKit")
		if native.has_method("settings_language"):
			var chosen := str(native.settings_language())
			if chosen in LANGUAGES:
				return chosen
	return _system_language()


## 简体是原文 "zh"；台湾、香港、澳门和写明 Hant 的都用繁体 "zh_TW"。
func _system_language() -> String:
	var preferred := OS.get_locale().to_lower().replace("-", "_")
	if not preferred.begins_with("zh"):
		return "en"
	for mark in ["hant", "_tw", "_hk", "_mo"]:
		if preferred.contains(mark):
			return "zh_TW"
	return "zh"


var days: Array[Dictionary] = []
var tasks: Array[Dictionary] = []
var scheduled_ids: Array[String] = []
## 某一天临时取消的提醒：{date, key}，key 是 sleep 或 task-<id>。过了那天就失效。
var skips: Array[Dictionary] = []


func day_count() -> int:
	_ensure_days()
	return days.size()


func day_slot(index: int) -> Dictionary:
	_ensure_days()
	return days[index]


func set_day_time(index: int, kind: String, hour: int, minute: int) -> void:
	_ensure_days()
	var slot := days[index]
	slot[kind + "_hour"] = clampi(hour, 0, 23)
	slot[kind + "_minute"] = clampi(minute, 0, 59)
	slot["enabled"] = true
	_sync_day_alarms()
	save_data()


func set_day_enabled(index: int, enabled: bool) -> void:
	_ensure_days()
	if index < 0 or index >= days.size():
		return
	days[index]["enabled"] = enabled
	_sync_day_alarms()
	save_data()


func _ensure_days() -> void:
	while days.size() < 7:
		days.append({
			"wake_hour": 7,
			"wake_minute": 0,
			"sleep_hour": 23,
			"sleep_minute": 0,
			"enabled": true,
		})
	if days.size() > 7:
		days.resize(7)


func _load_days(raw: Variant) -> void:
	days.clear()
	if typeof(raw) == TYPE_ARRAY:
		for item in raw:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			days.append({
				"wake_hour": clampi(int(item.get("wake_hour", 7)), 0, 23),
				"wake_minute": clampi(int(item.get("wake_minute", 0)), 0, 59),
				"sleep_hour": clampi(int(item.get("sleep_hour", 23)), 0, 23),
				"sleep_minute": clampi(int(item.get("sleep_minute", 0)), 0, 59),
				"enabled": bool(item.get("enabled", true)),
			})
	_ensure_days()
	_sync_day_alarms()


func _load_tasks(raw: Variant) -> void:
	tasks.clear()
	if typeof(raw) != TYPE_ARRAY:
		return
	for item in raw:
		if typeof(item) == TYPE_DICTIONARY:
			tasks.append(_normalize_task(item))


func _normalize_task(raw: Dictionary) -> Dictionary:
	var times: Array = []
	var stored: Variant = raw.get("times", [])
	if typeof(stored) == TYPE_ARRAY:
		for item in stored:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var moment := {
				"hour": clampi(int(item.get("hour", 9)), 0, 23),
				"minute": clampi(int(item.get("minute", 0)), 0, 59),
				"enabled": bool(item.get("enabled", true)),
			}
			if bool(item.get("paused", false)):
				moment["paused"] = true
			if item.has("end_hour"):
				moment["end_hour"] = clampi(int(item.get("end_hour", 0)), 0, 23)
				moment["end_minute"] = clampi(int(item.get("end_minute", 0)), 0, 59)
			times.append(moment)
	while times.size() < 7:
		times.append({"hour": 9, "minute": 0, "enabled": false})
	if times.size() > 7:
		times.resize(7)
	var task_id := str(raw.get("id", ""))
	if task_id.is_empty():
		task_id = _new_task_id()
	return {
		"id": task_id,
		"name": str(raw.get("name", "")),
		"times": times,
		"paused": bool(raw.get("paused", false)),
	}


func _new_task_id() -> String:
	return "%d-%d" % [Time.get_unix_time_from_system(), randi()]


func task_count() -> int:
	return tasks.size()


func task_at(index: int) -> Dictionary:
	if index < 0 or index >= tasks.size():
		return {}
	return tasks[index]


func task_label(task: Dictionary) -> String:
	var name := str(task.get("name", "")).strip_edges()
	return name if not name.is_empty() else "新的提醒"


func task_alarm_id(task_id: String, weekday: int) -> String:
	return "task-%s-%d" % [task_id, weekday]


func task_end_alarm_id(task_id: String, weekday: int) -> String:
	return "task-%s-%d-end" % [task_id, weekday]


func add_task(task_name: String = "新的提醒") -> Dictionary:
	var task := _normalize_task({"id": _new_task_id(), "name": task_name})
	tasks.append(task)
	_sync_day_alarms()
	save_data()
	changed.emit()
	return task


func task_has_end(index: int, day_index: int) -> bool:
	if index < 0 or index >= tasks.size() or day_index < 0 or day_index > 6:
		return false
	return tasks[index]["times"][day_index].has("end_hour")


func set_task_end(index: int, day_index: int, hour: int, minute: int) -> void:
	if index < 0 or index >= tasks.size() or day_index < 0 or day_index > 6:
		return
	var moment: Dictionary = tasks[index]["times"][day_index]
	moment["end_hour"] = clampi(hour, 0, 23)
	moment["end_minute"] = clampi(minute, 0, 59)
	_sync_day_alarms()
	save_data()


func clear_task_end(index: int, day_index: int) -> void:
	if not task_has_end(index, day_index):
		return
	var moment: Dictionary = tasks[index]["times"][day_index]
	moment.erase("end_hour")
	moment.erase("end_minute")
	_sync_day_alarms()
	save_data()


# 结束早于开始就是跨过半夜，算到下一天响。
func _end_weekday(moment: Dictionary, day_index: int) -> int:
	var start := int(moment["hour"]) * 60 + int(moment["minute"])
	var end := int(moment["end_hour"]) * 60 + int(moment["end_minute"])
	return (day_index + (1 if end <= start else 0)) % 7 + 1


func task_has_reminder(index: int) -> bool:
	if index < 0 or index >= tasks.size():
		return false
	for moment in tasks[index].get("times", []):
		if typeof(moment) == TYPE_DICTIONARY and bool(moment.get("enabled", true)):
			return true
	return false


func set_task_times_on_days(index: int, days: Array, hour: int, minute: int, end: Dictionary = {}) -> void:
	if index < 0 or index >= tasks.size():
		return
	var times: Array = tasks[index]["times"]
	for day_index in days:
		var day := int(day_index)
		if day < 0 or day > 6:
			continue
		var moment := {
			"hour": clampi(hour, 0, 23),
			"minute": clampi(minute, 0, 59),
			"enabled": true,
		}
		if end.has("hour"):
			moment["end_hour"] = clampi(int(end["hour"]), 0, 23)
			moment["end_minute"] = clampi(int(end["minute"]), 0, 59)
		times[day] = moment
	_sync_day_alarms()
	save_data()
	changed.emit()


func rename_task(task_id: String, name: String) -> void:
	for task in tasks:
		if str(task.get("id", "")) != task_id:
			continue
		task["name"] = name
		_sync_day_alarms()
		save_data()
		changed.emit()
		return


func set_task_time(index: int, day_index: int, hour: int, minute: int) -> void:
	if index < 0 or index >= tasks.size():
		return
	if day_index < 0 or day_index > 6:
		return
	var moment: Dictionary = tasks[index]["times"][day_index]
	moment["hour"] = clampi(hour, 0, 23)
	moment["minute"] = clampi(minute, 0, 59)
	moment["enabled"] = true
	_sync_day_alarms()
	save_data()


func task_day_enabled(index: int, day_index: int) -> bool:
	if index < 0 or index >= tasks.size():
		return true
	if day_index < 0 or day_index > 6:
		return true
	var times: Array = tasks[index]["times"]
	return bool(times[day_index].get("enabled", true))


func set_task_day_enabled(index: int, day_index: int, enabled: bool) -> void:
	if index < 0 or index >= tasks.size():
		return
	if day_index < 0 or day_index > 6:
		return
	var times: Array = tasks[index]["times"]
	var moment: Dictionary = times[day_index]
	moment["enabled"] = enabled
	times[day_index] = moment
	_sync_day_alarms()
	save_data()


func task_day_paused(index: int, day_index: int) -> bool:
	if index < 0 or index >= tasks.size() or day_index < 0 or day_index > 6:
		return false
	var moment: Dictionary = tasks[index]["times"][day_index]
	return bool(moment.get("enabled", false)) and bool(moment.get("paused", false))


func set_task_day_paused(index: int, day_index: int, paused: bool) -> void:
	if index < 0 or index >= tasks.size() or day_index < 0 or day_index > 6:
		return
	var moment: Dictionary = tasks[index]["times"][day_index]
	if paused:
		moment["paused"] = true
	else:
		moment.erase("paused")
	_sync_day_alarms()
	save_data()
	changed.emit()


func reorder_tasks(ids: Array) -> void:
	var by_id := {}
	for task in tasks:
		by_id[str(task.get("id", ""))] = task
	var next: Array[Dictionary] = []
	for task_id in ids:
		var key := str(task_id)
		if not by_id.has(key):
			return
		next.append(by_id[key])
	if next.size() != tasks.size():
		return
	tasks = next
	_sync_day_alarms()
	save_data()


func remove_task(task_id: String) -> void:
	var kept: Array[Dictionary] = []
	for task in tasks:
		if str(task.get("id", "")) != task_id:
			kept.append(task)
	tasks = kept
	_sync_day_alarms()
	save_data()
	changed.emit()


func _sync_day_alarms() -> void:
	var kept: Array[Dictionary] = []
	for index in days.size():
		var slot := days[index]
		var weekday := index + 1
		if sleep_present and not sleep_paused and bool(slot.get("enabled", true)):
			var sleep_skips := skipped_dates(index, skip_key())
			kept.append(_day_alarm("wake-%d" % weekday, int(slot["wake_hour"]), int(slot["wake_minute"]), weekday, "起床", sleep_skips))
			kept.append(_day_alarm("sleep-%d" % weekday, int(slot["sleep_hour"]), int(slot["sleep_minute"]), weekday, "睡觉", sleep_skips))
	for task in tasks:
		if bool(task.get("paused", false)):
			continue
		var task_id := str(task.get("id", ""))
		var label := task_label(task)
		var times: Array = task.get("times", [])
		for day_index in times.size():
			var moment: Dictionary = times[day_index]
			if not bool(moment.get("enabled", true)) or bool(moment.get("paused", false)):
				continue
			var task_weekday := day_index + 1
			var task_skips := skipped_dates(day_index, skip_key(task_id))
			kept.append(_day_alarm(task_alarm_id(task_id, task_weekday), int(moment["hour"]), int(moment["minute"]), task_weekday, label, task_skips))
			if moment.has("end_hour"):
				var end_weekday := _end_weekday(moment, day_index)
				var end_skips: Array = []
				for date_key in task_skips:
					end_skips.append(shift_date(date_key, posmod(end_weekday - task_weekday, 7)))
				kept.append(_day_alarm(task_end_alarm_id(task_id, task_weekday), int(moment["end_hour"]), int(moment["end_minute"]), end_weekday, label, end_skips))
	alarms = kept


func due_groups() -> Array[Dictionary]:
	var buckets := {}
	for alarm in alarms:
		if not bool(alarm.get("enabled", false)):
			continue
		for day in alarm.get("weekdays", []):
			var weekday := int(day)
			var hour := int(alarm.get("hour", 0))
			var minute := int(alarm.get("minute", 0))
			var key := "%d-%d-%d" % [weekday, hour, minute]
			if not buckets.has(key):
				buckets[key] = {
					"id": "due-%s" % key,
					"hour": hour,
					"minute": minute,
					"weekdays": [weekday],
					"enabled": true,
					"events": [],
				}
			var events: Array = buckets[key]["events"]
			var alarm_id := str(alarm.get("id", ""))
			var event_label := tr(str(alarm.get("label", "")))
			if alarm_id.ends_with("-end"):
				event_label = tr("%s结束") % event_label
			events.append({
				"id": alarm_id,
				"label": event_label,
				"skip_dates": alarm.get("skip_dates", []),
			})
	var groups: Array[Dictionary] = []
	for key in buckets:
		var group: Dictionary = buckets[key]
		var names := PackedStringArray()
		var has_skip := false
		for event in group["events"]:
			var event_label := str(event.get("label", ""))
			if not event_label.is_empty():
				names.append(event_label)
			if not (event["skip_dates"] as Array).is_empty():
				has_skip = true
		group["label"] = "、".join(names)
		if has_skip:
			group["dates"] = _dated_occurrences(group)
		groups.append(group)
	return groups


## 有跳过的那组不交给系统每周重复，改成往后 WEEKS_AHEAD 周逐日排好，跳过的那天不排；
## 这样不打开 app 也照常响到那几周排完。
func _dated_occurrences(group: Dictionary) -> Array:
	var hour := int(group.get("hour", 0))
	var minute := int(group.get("minute", 0))
	var first := next_date(int(group["weekdays"][0]) - 1, hour, minute)
	var occurrences: Array = []
	for week in WEEKS_AHEAD:
		var date_key := shift_date(first, week * 7)
		var events: Array = []
		for event in group["events"]:
			if not (event["skip_dates"] as Array).has(date_key):
				events.append({"id": event["id"], "label": event["label"]})
		if not events.is_empty():
			occurrences.append({"date": date_key, "events": events})
	return occurrences


func current_due_labels() -> PackedStringArray:
	var now := Time.get_datetime_dict_from_system()
	var godot_day := int(now.get("weekday", 0))
	var weekday := 7 if godot_day == 0 else godot_day
	var now_minutes := int(now.get("hour", 0)) * 60 + int(now.get("minute", 0))
	var best_gap := 10
	var labels := PackedStringArray()
	for group in due_groups():
		var days: Array = group.get("weekdays", [])
		if days.is_empty() or int(days[0]) != weekday:
			continue
		var gap := now_minutes - (int(group.get("hour", 0)) * 60 + int(group.get("minute", 0)))
		if gap < 0 or gap > 9 or gap >= best_gap:
			continue
		best_gap = gap
		labels = PackedStringArray()
		for event in group.get("events", []):
			var event_label := str(event.get("label", ""))
			if not event_label.is_empty():
				labels.append(event_label)
	return labels


func replace_scheduled_ids(next_ids: Array) -> void:
	scheduled_ids.clear()
	for item in next_ids:
		scheduled_ids.append(str(item))
	save_data()


func _day_alarm(alarm_id: String, hour: int, minute: int, weekday: int, label: String, skip_dates: Array = []) -> Dictionary:
	return {
		"id": alarm_id,
		"hour": hour,
		"minute": minute,
		"weekdays": [weekday],
		"label": label,
		"enabled": true,
		"skip_dates": skip_dates,
	}


func add_alarm(hour: int, minute: int, weekdays: Array, label: String) -> Dictionary:
	var alarm := {
		"id": "%d-%d" % [Time.get_unix_time_from_system(), randi()],
		"hour": clampi(hour, 0, 23),
		"minute": clampi(minute, 0, 59),
		"weekdays": _normalize_weekdays(weekdays),
		"label": label if not label.is_empty() else "起床",
		"enabled": true,
	}
	alarms.append(alarm)
	save_data()
	changed.emit()
	return alarm


func update_alarm(alarm_id: String, hour: int, minute: int, weekdays: Array, label: String) -> Dictionary:
	var alarm := find_alarm(alarm_id)
	if alarm.is_empty():
		return {}
	alarm["hour"] = clampi(hour, 0, 23)
	alarm["minute"] = clampi(minute, 0, 59)
	alarm["weekdays"] = _normalize_weekdays(weekdays)
	alarm["label"] = label if not label.is_empty() else "起床"
	save_data()
	changed.emit()
	return alarm


func set_enabled(alarm_id: String, enabled: bool) -> void:
	var alarm := find_alarm(alarm_id)
	if alarm.is_empty():
		return
	alarm["enabled"] = enabled
	save_data()
	changed.emit()


func remove_alarm(alarm_id: String) -> void:
	alarms = alarms.filter(func(item: Dictionary) -> bool: return str(item.get("id", "")) != alarm_id)
	save_data()
	changed.emit()


func find_alarm(alarm_id: String) -> Dictionary:
	for alarm in alarms:
		if str(alarm.get("id", "")) == alarm_id:
			return alarm
	return {}


func record_snooze_once(alarm_id: String) -> bool:
	var today := today_key()
	for event in snoozes:
		if str(event.get("date", "")) == today and str(event.get("alarm_id", "")) == alarm_id:
			return false
	record_snooze(alarm_id)
	return true


func due_group(group_id: String) -> Dictionary:
	for group in due_groups():
		if str(group.get("id", "")) == group_id:
			return group
	return {}


func task_index_for_alarm(alarm_id: String, weekday: int) -> int:
	for index in tasks.size():
		var task_id := str(tasks[index].get("id", ""))
		if alarm_id == task_alarm_id(task_id, weekday):
			return index
		if alarm_id.begins_with("task-%s-" % task_id) and alarm_id.ends_with("-end"):
			return index
	return -1


func record_snooze(alarm_id: String, when: int = -1, dedupe: bool = true) -> Dictionary:
	var stamp := int(Time.get_unix_time_from_system()) if when < 0 else when
	var event := {
		"date": date_key_from_unix(stamp),
		"alarm_id": alarm_id,
		"at": stamp,
		"kind": "snooze",
	}
	if dedupe and _has_recent_reward(event):
		return event
	snoozes.append(event)
	_grant_for(event)
	save_data()
	changed.emit()
	return event


func merge_snoozes(events: Array) -> int:
	var added := 0
	for item in events:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var event := {
			"date": str(item.get("date", "")),
			"alarm_id": str(item.get("alarm_id", "")),
			"at": int(item.get("at", 0)),
			"kind": str(item.get("kind", "snooze")),
		}
		if event["date"].is_empty() or event["at"] <= 0:
			continue
		if _has_snooze(event) or _has_recent_reward(event):
			continue
		snoozes.append(event)
		_grant_for(event)
		added += 1
	if added > 0:
		save_data()
		changed.emit()
	return added


func count_on(date_key: String) -> int:
	return sleep_snooze_on(date_key)


func sleep_snooze_on(date_key: String) -> int:
	var total := 0
	for event in snoozes:
		if str(event.get("date", "")) != date_key:
			continue
		if _is_sleep_snooze(str(event.get("alarm_id", ""))):
			total += 1
	return total


func care_on(date_key: String) -> int:
	var total := 0
	for item in care:
		if str(item.get("date", "")) == date_key:
			total += 1
	return total


func growth_on(_date_key: String) -> int:
	return fertilizer_used


func use_fertilizer() -> bool:
	if fertilizer <= 0:
		return false
	fertilizer -= 1
	fertilizer_used += 1
	save_data()
	changed.emit()
	return true


func watered_today() -> bool:
	return watered_on(today_key())


func watered_on(date_key: String) -> bool:
	for item in care:
		if str(item.get("date", "")) != date_key:
			continue
		if str(item.get("kind", "")) == "water":
			return true
	return false


func record_water() -> bool:
	var today := today_key()
	if watered_on(today):
		return false
	care.append({
		"date": today,
		"kind": "water",
		"at": int(Time.get_unix_time_from_system()),
	})
	last_watered = today
	save_data()
	changed.emit()
	return true


func days_without_water() -> int:
	if last_watered.is_empty():
		return 0
	var then_unix := _noon_unix(last_watered)
	var now_unix := _noon_unix(today_key())
	if then_unix <= 0 or now_unix <= 0:
		return 0
	return maxi(0, int((now_unix - then_unix) / 86400.0))


func is_wilted() -> bool:
	return wilt_level() > 0


## 3 天没浇水蔫了，5 天更蔫，7 天干枯。
func wilt_level() -> int:
	var days := days_without_water()
	if days >= 7:
		return 3
	if days >= 5:
		return 2
	if days >= 3:
		return 1
	return 0


func _noon_unix(date_key: String) -> int:
	var parts := date_key.split("-")
	if parts.size() != 3:
		return 0
	return int(Time.get_unix_time_from_datetime_dict({
		"year": int(parts[0]),
		"month": int(parts[1]),
		"day": int(parts[2]),
		"hour": 12,
		"minute": 0,
		"second": 0,
	}))


func _load_fertilizer(data: Dictionary) -> void:
	fertilizer_used = int(data.get("fertilizer_used", -1))
	if fertilizer_used < 0:
		fertilizer_used = 0
		for item in care:
			if str(item.get("kind", "")) == "feed":
				fertilizer_used += 1
	var sleep_total := 0
	for event in snoozes:
		if _is_sleep_snooze(str(event.get("alarm_id", ""))):
			sleep_total += 1
	if data.has("fertilizer"):
		fertilizer = maxi(0, int(data.get("fertilizer", 0)))
	else:
		fertilizer = maxi(0, sleep_total - fertilizer_used)
	last_watered = str(data.get("last_watered", ""))
	if last_watered.is_empty():
		last_watered = today_key()


func _is_sleep_snooze(alarm_id: String) -> bool:
	if alarm_id.begins_with("sleep-"):
		return true
	if not alarm_id.begins_with("due-"):
		return false
	var group := due_group(alarm_id)
	for event in group.get("events", []):
		if str(event.get("id", "")).begins_with("sleep-"):
			return true
	return false


func _group_has_task(alarm_id: String) -> bool:
	if alarm_id.begins_with("task-"):
		return true
	if not alarm_id.begins_with("due-"):
		return false
	for event in due_group(alarm_id).get("events", []):
		if str(event.get("id", "")).begins_with("task-"):
			return true
	return false


func _grant_for(event: Dictionary) -> void:
	var kind := str(event.get("kind", "snooze"))
	if kind == "done" and not _group_has_task(str(event.get("alarm_id", ""))):
		return
	fertilizer += 1


## 同一次推迟倒计时里系统会连着报好几次，8 分钟内同一闹钟同一类只记一包肥料。
const REWARD_SESSION := 8 * 60
const WEEKS_AHEAD := 8


func _has_recent_reward(event: Dictionary) -> bool:
	var alarm_id := str(event.get("alarm_id", ""))
	var kind := str(event.get("kind", "snooze"))
	var stamp := int(event.get("at", 0))
	for existing in snoozes:
		if str(existing.get("alarm_id", "")) != alarm_id:
			continue
		if str(existing.get("kind", "snooze")) != kind:
			continue
		if absi(int(existing.get("at", 0)) - stamp) < REWARD_SESSION:
			return true
	return false


func today_weekday_index() -> int:
	var godot_day := int(Time.get_datetime_dict_from_system().get("weekday", 0))
	return 6 if godot_day == 0 else godot_day - 1


## 这个星期几下一次到点是哪天；今天已经过了那个钟点就算下周。
func next_date(day_index: int, hour: int, minute: int) -> String:
	var ahead := posmod(day_index - today_weekday_index(), 7)
	if ahead == 0:
		var now := Time.get_time_dict_from_system()
		if int(now["hour"]) * 60 + int(now["minute"]) >= hour * 60 + minute:
			ahead = 7
	return shift_date(local_today_key(), ahead)


## 闹钟按手机本地日期响，跳过的日期也用本地日期。
func local_today_key() -> String:
	var parts := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(parts.year), int(parts.month), int(parts.day)]


func date_weekday_index(date_key: String) -> int:
	var parts := date_key.split("-")
	if parts.size() != 3:
		return -1
	var stamp := int(Time.get_unix_time_from_datetime_dict({
		"year": int(parts[0]),
		"month": int(parts[1]),
		"day": int(parts[2]),
		"hour": 12,
	}))
	var godot_day := int(Time.get_datetime_dict_from_unix_time(stamp).get("weekday", 0))
	return 6 if godot_day == 0 else godot_day - 1


func skipped_dates(day_index: int, key: String) -> Array:
	var dates: Array = []
	for item in skips:
		var date_key := str(item.get("date", ""))
		if str(item.get("key", "")) == key and date_weekday_index(date_key) == day_index:
			dates.append(date_key)
	return dates


func skip_key(task_id: String = "") -> String:
	return "sleep" if task_id.is_empty() else "task-%s" % task_id


func is_skipped(date_key: String, key: String) -> bool:
	for item in skips:
		if str(item.get("date", "")) == date_key and str(item.get("key", "")) == key:
			return true
	return false


func set_skipped(date_key: String, key: String, skipped: bool) -> void:
	_prune_skips()
	var found := -1
	for index in skips.size():
		if str(skips[index].get("date", "")) == date_key and str(skips[index].get("key", "")) == key:
			found = index
			break
	if skipped and found < 0:
		skips.append({"date": date_key, "key": key})
	elif not skipped and found >= 0:
		skips.remove_at(found)
	_sync_day_alarms()
	save_data()
	changed.emit()


func prune_skips() -> bool:
	if not _prune_skips():
		return false
	_sync_day_alarms()
	save_data()
	return true


func _load_skips(raw: Variant) -> void:
	skips.clear()
	if typeof(raw) != TYPE_ARRAY:
		return
	for item in raw:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var date_key := str(item.get("date", ""))
		var key := str(item.get("key", ""))
		if date_key.is_empty() or key.is_empty():
			continue
		skips.append({"date": date_key, "key": key})
	_prune_skips()


func _prune_skips() -> bool:
	var today := local_today_key()
	var kept: Array[Dictionary] = []
	for item in skips:
		if str(item.get("date", "")) >= today:
			kept.append(item)
	if kept.size() == skips.size():
		return false
	skips = kept
	return true


func today_key() -> String:
	return date_key_from_unix(int(Time.get_unix_time_from_system()))


func date_key_from_unix(stamp: int) -> String:
	var parts := Time.get_date_dict_from_unix_time(stamp)
	return "%04d-%02d-%02d" % [int(parts.year), int(parts.month), int(parts.day)]


func shift_date(date_key: String, days: int) -> String:
	var parts := date_key.split("-")
	if parts.size() != 3:
		return today_key()
	var stamp := int(Time.get_unix_time_from_datetime_dict({
		"year": int(parts[0]),
		"month": int(parts[1]),
		"day": int(parts[2]),
		"hour": 12,
	}))
	return date_key_from_unix(stamp + days * 86400)


func format_date(date_key: String) -> String:
	if date_key == today_key():
		return tr("今天")
	var parts := date_key.split("-")
	if parts.size() != 3:
		return date_key
	return tr("%d月%d日") % [int(parts[1]), int(parts[2])]


func format_time(hour: int, minute: int) -> String:
	return "%02d:%02d" % [hour, minute]


func format_weekdays(weekdays: Array) -> String:
	var days: Array[int] = []
	for day in weekdays:
		days.append(int(day))
	days.sort()
	if days == [1, 2, 3, 4, 5]:
		return tr("周一至周五")
	if days == [1, 2, 3, 4, 5, 6, 7]:
		return tr("每天")
	if days.is_empty():
		return tr("不重复")
	var names: PackedStringArray = []
	for day in days:
		if day >= 1 and day <= 7:
			names.append(tr("周" + WEEKDAY_NAMES[day - 1]))
	return " ".join(names)


func _normalize_alarm(raw: Dictionary) -> Dictionary:
	return {
		"id": str(raw.get("id", "")),
		"hour": clampi(int(raw.get("hour", 7)), 0, 23),
		"minute": clampi(int(raw.get("minute", 0)), 0, 59),
		"weekdays": _normalize_weekdays(raw.get("weekdays", [1, 2, 3, 4, 5])),
		"label": str(raw.get("label", "起床")),
		"enabled": bool(raw.get("enabled", true)),
	}


func _normalize_weekdays(raw: Variant) -> Array:
	var days: Array[int] = []
	if typeof(raw) != TYPE_ARRAY:
		return [1, 2, 3, 4, 5]
	for day in raw:
		var value := int(day)
		if value >= 1 and value <= 7 and value not in days:
			days.append(value)
	days.sort()
	return days


func _has_snooze(event: Dictionary) -> bool:
	for existing in snoozes:
		if int(existing.get("at", 0)) == int(event.get("at", -1)) and str(existing.get("alarm_id", "")) == str(event.get("alarm_id", "")):
			return true
	return false
