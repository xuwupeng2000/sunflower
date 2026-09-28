extends Node

const SAVE_PATH := "user://sunflower_alarms.json"
const WEEKDAY_NAMES := ["一", "二", "三", "四", "五", "六", "日"]

var alarms: Array[Dictionary] = []
var snoozes: Array[Dictionary] = []

signal changed


func _ready() -> void:
	load_data()


func load_data() -> void:
	alarms.clear()
	snoozes.clear()
	if not FileAccess.file_exists(SAVE_PATH):
		_ensure_days()
		_sync_day_alarms()
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
	_load_tasks(data.get("tasks", []))
	_load_days(data.get("days", []))
	changed.emit()


func save_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("无法写入闹钟存档")
		return
	file.store_string(JSON.stringify({
		"alarms": alarms,
		"snoozes": snoozes,
		"days": days,
		"tasks": tasks,
	}, "  "))


var days: Array[Dictionary] = []
var tasks: Array[Dictionary] = []


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
			times.append({
				"hour": clampi(int(item.get("hour", 9)), 0, 23),
				"minute": clampi(int(item.get("minute", 0)), 0, 59),
				"enabled": bool(item.get("enabled", true)),
			})
	while times.size() < 7:
		times.append({"hour": 9, "minute": 0, "enabled": true})
	if times.size() > 7:
		times.resize(7)
	var task_id := str(raw.get("id", ""))
	if task_id.is_empty():
		task_id = _new_task_id()
	return {
		"id": task_id,
		"name": str(raw.get("name", "")),
		"times": times,
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


func add_task(task_name: String = "新的提醒") -> Dictionary:
	var task := _normalize_task({"id": _new_task_id(), "name": task_name})
	tasks.append(task)
	_sync_day_alarms()
	save_data()
	changed.emit()
	return task


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
	var times: Array = tasks[index]["times"]
	times[day_index] = {
		"hour": clampi(hour, 0, 23),
		"minute": clampi(minute, 0, 59),
		"enabled": true,
	}
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
		if bool(slot.get("enabled", true)):
			kept.append(_day_alarm("wake-%d" % weekday, int(slot["wake_hour"]), int(slot["wake_minute"]), weekday, "起床"))
			kept.append(_day_alarm("sleep-%d" % weekday, int(slot["sleep_hour"]), int(slot["sleep_minute"]), weekday, "睡觉"))
	for task in tasks:
		var task_id := str(task.get("id", ""))
		var label := task_label(task)
		var times: Array = task.get("times", [])
		for day_index in times.size():
			var moment: Dictionary = times[day_index]
			if not bool(moment.get("enabled", true)):
				continue
			var task_weekday := day_index + 1
			kept.append(_day_alarm(task_alarm_id(task_id, task_weekday), int(moment["hour"]), int(moment["minute"]), task_weekday, label))
	alarms = kept


func _day_alarm(alarm_id: String, hour: int, minute: int, weekday: int, label: String) -> Dictionary:
	return {
		"id": alarm_id,
		"hour": hour,
		"minute": minute,
		"weekdays": [weekday],
		"label": label,
		"enabled": true,
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


func record_snooze(alarm_id: String, when: int = -1) -> Dictionary:
	var stamp := int(Time.get_unix_time_from_system()) if when < 0 else when
	var event := {
		"date": date_key_from_unix(stamp),
		"alarm_id": alarm_id,
		"at": stamp,
	}
	if _has_snooze(event):
		return event
	snoozes.append(event)
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
		}
		if event["date"].is_empty() or event["at"] <= 0 or _has_snooze(event):
			continue
		snoozes.append(event)
		added += 1
	if added > 0:
		save_data()
		changed.emit()
	return added


func count_on(date_key: String) -> int:
	var total := 0
	for event in snoozes:
		if str(event.get("date", "")) == date_key:
			total += 1
	return total


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
		return "今天"
	var parts := date_key.split("-")
	if parts.size() != 3:
		return date_key
	return "%d月%d日" % [int(parts[1]), int(parts[2])]


func format_time(hour: int, minute: int) -> String:
	return "%02d:%02d" % [hour, minute]


func format_weekdays(weekdays: Array) -> String:
	var days: Array[int] = []
	for day in weekdays:
		days.append(int(day))
	days.sort()
	if days == [1, 2, 3, 4, 5]:
		return "周一至周五"
	if days == [1, 2, 3, 4, 5, 6, 7]:
		return "每天"
	if days.is_empty():
		return "不重复"
	var names: PackedStringArray = []
	for day in days:
		if day >= 1 and day <= 7:
			names.append("周" + WEEKDAY_NAMES[day - 1])
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
