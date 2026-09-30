extends Node

const PLUGIN_NAME := "AlarmKit"
const SNOOZE_SECONDS := 9 * 60
const RING_MAX := 10 * 60

var store: Node
var native: Object = null
var using_native := false
var _alerting_since := {}

signal authorization_changed(status: String)
signal snoozes_updated


func _ready() -> void:
	store = get_node("/root/AlarmStore")
	if Engine.has_singleton(PLUGIN_NAME):
		native = Engine.get_singleton(PLUGIN_NAME)
		using_native = true
		native.connect("snoozes_changed", Callable(self, "_on_native_snoozes"))
		_pull_native_snoozes()
		native.request_authorization()


func schedule(alarm: Dictionary) -> void:
	if not bool(alarm.get("enabled", false)):
		cancel(str(alarm.get("id", "")))
		return
	if using_native:
		native.schedule_weekly(_translated(alarm))
		return
	var names := PackedStringArray()
	for event in alarm.get("events", []):
		if typeof(event) == TYPE_DICTIONARY:
			names.append(str(event.get("label", "")))
	var shown := "、".join(names) if names.size() > 0 else str(alarm.get("label", ""))
	print("桌面预览：已记下闹钟 %s %02d:%02d" % [shown, int(alarm.get("hour", 0)), int(alarm.get("minute", 0))])


## 系统闹钟界面显示的名字跟着当前语言；自带的「起床」「睡觉」才有译文，自己起的名字原样保留。
func _translated(alarm: Dictionary) -> Dictionary:
	var shown := alarm.duplicate(true)
	shown["label"] = tr(str(alarm.get("label", "")))
	for event in shown.get("events", []):
		if typeof(event) == TYPE_DICTIONARY:
			event["label"] = tr(str(event.get("label", "")))
	return shown


func sync_alarms() -> void:
	var live := {}
	for item in ringing_alarms():
		if typeof(item) == TYPE_DICTIONARY:
			live[str(item.get("id", ""))] = true
	var previous: Array[String] = []
	previous.assign(store.scheduled_ids)
	for alarm_id in previous:
		if live.has(alarm_id):
			continue
		cancel(alarm_id)
	for alarm in store.alarms:
		var alarm_id := str(alarm.get("id", ""))
		if live.has(alarm_id):
			continue
		cancel(alarm_id)
	var next_ids: Array[String] = []
	for group in store.due_groups():
		var group_id := str(group.get("id", ""))
		next_ids.append(group_id)
		if live.has(group_id):
			continue
		schedule(group)
	store.replace_scheduled_ids(next_ids)


func ringing_alarms() -> Array:
	if native == null:
		return []
	var parsed: Variant = JSON.parse_string(str(native.active_alarms_json()))
	if typeof(parsed) != TYPE_ARRAY:
		return []
	return parsed


func note_ringing() -> Array:
	var ringing: Array = []
	var seen: Array = ringing_alarms()
	_pull_native_snoozes()
	var now := Time.get_unix_time_from_system()
	var still_alerting := {}
	for item in seen:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var state := str(item.get("state", ""))
		var alarm_id := str(item.get("id", ""))
		if state == "countdown" or state == "paused":
			store.record_snooze_once(alarm_id)
		if state == "alerting":
			# 从 app 第一次看到它在响开始算；没人理响满 RING_MAX 就停，不算贪睡。
			var since: float = _alerting_since.get(alarm_id, now)
			still_alerting[alarm_id] = since
			var left := RING_MAX - (now - since)
			if left <= 0.0:
				stop(alarm_id)
				still_alerting.erase(alarm_id)
				continue
			item["ring_left"] = left
		if state == "alerting" or state == "countdown" or state == "paused":
			ringing.append(item)
	_alerting_since = still_alerting
	return ringing


func cancel(alarm_id: String) -> void:
	if using_native:
		native.cancel(alarm_id)


# 只结束这一次响铃或推迟倒计时，每周闹钟照常。
func stop(alarm_id: String) -> void:
	if not using_native:
		return
	if native.has_method("stop"):
		native.stop(alarm_id)
		return
	var group: Dictionary = store.due_group(alarm_id)
	native.cancel(alarm_id)
	if not group.is_empty():
		schedule(group)


func start_timer(timer: Dictionary) -> void:
	var seconds := int(round(float(timer.get("ends_at", 0.0)) - Time.get_unix_time_from_system()))
	if using_native and native.has_method("start_timer"):
		native.start_timer(str(timer.get("id", "")), str(timer.get("title", "")), maxi(1, seconds))
		return
	print("桌面预览：%s 计时 %d 秒" % [str(timer.get("title", "")), seconds])


func cancel_timer(timer: Dictionary) -> void:
	if using_native and native.has_method("cancel_timer"):
		native.cancel_timer(str(timer.get("id", "")))


func finish_timer(timer: Dictionary) -> void:
	if using_native and native.has_method("finish_timer"):
		native.finish_timer(str(timer.get("id", "")))


## 锁屏或灵动岛上点了取消的那个计时 id；没有就是空。
func take_cancelled_timer() -> String:
	if using_native and native.has_method("take_cancelled_timer"):
		return str(native.take_cancelled_timer())
	return ""


func record_desktop_snooze(alarm_id: String = "") -> void:
	if using_native:
		return
	store.record_snooze(alarm_id if not alarm_id.is_empty() else "desktop")
	snoozes_updated.emit()


func preview_ring() -> void:
	var player := get_node_or_null("/root/Main/RingPlayer") as AudioStreamPlayer
	if player and player.stream:
		player.play()


func _pull_native_snoozes() -> void:
	if native == null:
		return
	var raw := str(native.snooze_log_json())
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) == TYPE_ARRAY:
		store.merge_snoozes(parsed)
		snoozes_updated.emit()


func _on_native_snoozes() -> void:
	_pull_native_snoozes()
