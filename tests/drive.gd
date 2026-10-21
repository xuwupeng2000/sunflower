extends RefCounted

const Reel := preload("res://tests/shot_reel.gd")
const DAY_PATHS := [
	"行1/周一", "行1/周二", "行1/周三",
	"行2/周四", "行2/周五",
	"行3/周六", "行3/周日",
]
const SECTIONS := ["本周条", "下周条", "下下周条", "更远条", "已完成条"]


static func open(suite) -> Array:
	var runner = suite.scene_runner("res://scenes/main.tscn")
	var main: Node = runner.scene()
	_quiet(main)
	for _index in 8:
		await suite.get_tree().process_frame
	return [runner, main]


static func frames(suite, count: int) -> void:
	for _index in count:
		await suite.get_tree().process_frame


static func show_tab(suite, main: Node, tab: String, settle_guides := true) -> void:
	(main.get_node("UI/界面/底栏/图标/" + tab) as Button).pressed.emit()
	await frames(suite, 20)
	if not settle_guides:
		return
	hide_guides(main)
	if tab == "行程" and not AlarmStore.once_named(AlarmStore.SAMPLE_ONCE_ID).is_empty():
		AlarmStore.remove_once(AlarmStore.SAMPLE_ONCE_ID)
	await frames(suite, 2)


static func hide_guides(main: Node) -> void:
	for node_name in ["教程", "计时教程", "行程教程"]:
		var guide := main.get_node_or_null("UI/界面/" + node_name) as CanvasItem
		if guide:
			guide.visible = false


static func tap_guide(guide: Control) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = guide.size * 0.5
	guide.gui_input.emit(event)


static func until_visible(suite, node: CanvasItem) -> void:
	for _index in 40:
		if node.visible:
			await frames(suite, 2)
			return
		await suite.get_tree().process_frame


static func set_clock(picker: Node, afternoon: int, hour12: int, minute: int) -> void:
	var ampm: Control = picker.get_node("居中/面板/内容/滚轮区/列/上下午")
	var hour: Control = picker.get_node("居中/面板/内容/滚轮区/列/时")
	var mins: Control = picker.get_node("居中/面板/内容/滚轮区/列/分")
	ampm.value = afternoon
	hour.value = hour12
	mins.value = minute
	ampm.queue_redraw()
	hour.queue_redraw()
	mins.queue_redraw()


static func tap_scroll(handler: Control, target: Control) -> void:
	var at := target.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	down.global_position = at
	handler._on_scroll_input(down)
	var up := down.duplicate()
	up.pressed = false
	handler._on_scroll_input(up)


static func first_open_day(add: Node, week: String) -> Button:
	var box := add.get_node("居中/面板/内容/滚动/块/" + week) as Node
	if box == null or not (box as CanvasItem).visible:
		return null
	for path in DAY_PATHS:
		var button := box.get_node(path) as Button
		if button.visible and button.has_meta("date"):
			return button
	return null


static func scroll_to(suite, page: Control, target: Control, from_top: int) -> void:
	var scroll: ScrollContainer = page._scroll
	for _index in 3:
		await suite.get_tree().process_frame
	var y := target.global_position.y - scroll.global_position.y + scroll.scroll_vertical
	var limit := int(scroll.get_v_scroll_bar().max_value)
	scroll.scroll_vertical = clampi(int(y) - from_top, 0, limit)
	await suite.get_tree().process_frame


static func find_label(page: Control, label: String) -> Button:
	for row in page._all_rows():
		var item: Dictionary = row.get_meta("item", {})
		if str(item.get("label", "")) == label and row.visible:
			return row
	return null


static func section_of(row: Node) -> String:
	var node := row
	while node:
		if str(node.name) in SECTIONS:
			return str(node.name)
		node = node.get_parent()
	return ""


static func hold_row(page: Control, row: Button) -> void:
	var at := row.get_global_rect().get_center()
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = at
	event.global_position = at
	page._on_scroll_input(event)
	page._process(0.5)


static func _quiet(node: Node) -> void:
	if node is AudioStreamPlayer:
		(node as AudioStreamPlayer).stream_paused = true
	for child in node.get_children():
		_quiet(child)
