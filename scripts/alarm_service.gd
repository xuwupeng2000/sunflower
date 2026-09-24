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
	print("桌面预览：已记下闹钟 %s %02d:%02d" % [alarm.get("label", ""), int(alarm.get("hour", 0)), int(alarm.get("minute", 0))])


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
