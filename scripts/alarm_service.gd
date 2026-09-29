extends Node

const PLUGIN_NAME := "AlarmKit"
const SNOOZE_SECONDS := 9 * 60

var store: Node
var native: Object = null
var using_native := false

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
		native.schedule_weekly(alarm)
		return
	var names := PackedStringArray()
	for event in alarm.get("events", []):
		if typeof(event) == TYPE_DICTIONARY:
			names.append(str(event.get("label", "")))
	var shown := "、".join(names) if names.size() > 0 else str(alarm.get("label", ""))
	print("桌面预览：已记下闹钟 %s %02d:%02d" % [shown, int(alarm.get("hour", 0)), int(alarm.get("minute", 0))])


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
	for item in seen:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var state := str(item.get("state", ""))
		var alarm_id := str(item.get("id", ""))
		if state == "countdown" or state == "paused":
			store.record_snooze_once(alarm_id)
		if state == "alerting" or state == "countdown" or state == "paused":
			ringing.append(item)
	return ringing


func cancel(alarm_id: String) -> void:
	if using_native:
		native.cancel(alarm_id)


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
