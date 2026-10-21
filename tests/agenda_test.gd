extends GdUnitTestSuite

const Reel := preload("res://tests/shot_reel.gd")
const WEEKDAYS := ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
const THIS_DAYS := "边框/内容/滚动/边距/列表/本周条/内容/底色/内边距/列/本周天"
const NEXT_DAYS := "边框/内容/滚动/边距/列表/下周条/内容/内边距/列/下周天"
const DONE := "边框/内容/滚动/边距/列表/已完成条"

var _runner: GdUnitSceneRunner


func before_test() -> void:
	AlarmStore.once_tutorial_seen = true
	AlarmStore.tutorial_seen = true
	AlarmStore.timer_tutorial_seen = true
	AlarmStore.once_reminders.clear()
	AlarmStore.tasks.clear()
	for index in AlarmStore.day_count():
		AlarmStore.days[index]["enabled"] = true
	AlarmStore._sync_day_alarms()


func test_this_week_hides_past_days_and_next_week_keeps_seven() -> void:
	var page := await _open_agenda()
	var today := AlarmStore.local_today_key()
	var monday := AlarmStore.monday_of(today)
	var this_days := page.get_node(THIS_DAYS) as VBoxContainer
	var next_days := page.get_node(NEXT_DAYS) as VBoxContainer
	assert_int(this_days.get_child_count()).is_equal(7)
	assert_int(next_days.get_child_count()).is_equal(7)
	assert_bool(this_days.visible).is_true()
	assert_bool(next_days.visible).is_true()
	for index in 7:
		var this_date := AlarmStore.shift_date(monday, index)
		var this_day := this_days.get_child(index) as VBoxContainer
		var next_day := next_days.get_child(index) as VBoxContainer
		assert_bool(this_day.visible).is_equal(this_date >= today)
		if this_day.visible:
			assert_str((this_day.get_node("标题") as Label).text).is_equal(_title(this_date, index))
		assert_bool(next_day.visible).is_true()
		assert_str((next_day.get_node("标题") as Label).text).is_equal(tr(WEEKDAYS[index]))
	assert_bool(page.get_node(DONE).visible).is_false()
	var today_text := ""
	for child in this_days.get_children():
		var day := child as VBoxContainer
		if day == null or not day.visible:
			continue
		if not (day.get_node("标题") as Label).text.contains(tr("今天")):
			continue
		for row in day.get_children():
			if row is Button:
				today_text += (row as Button).text
	assert_bool(today_text.contains(tr("起床"))).is_true()
	assert_bool(today_text.contains(tr("睡觉"))).is_true()
	page._scroll.scroll_vertical = 0
	await Reel.snap(page, "本周从今天开始", "本周只留下今天和后面的日子")
	await _scroll_to(page, page.get_node("边框/内容/滚动/边距/列表/下周条"), 8)
	await Reel.snap(page, "本周从今天开始", "下周仍然从周一排到周日")


func test_today_lists_a_once_whose_time_already_passed() -> void:
	var page := await _open_agenda()
	var item := AlarmStore.add_once("早上的事", AlarmStore.local_today_key(), 0, 0)
	var once_id := str(item.get("id", ""))
	assert_bool(AlarmStore.once_done(AlarmStore.once_named(once_id))).is_true()
	var row := _find_row(page, once_id)
	assert_object(row).is_not_null()
	assert_str(_section_of(row)).is_equal("本周条")
	assert_bool(page.get_node(DONE).visible).is_false()
	await _scroll_to(page, row, 120)
	await Reel.snap(page, "今天已经过去的也列出", "今天早上的这条还在今天")


func test_empty_schedule_is_only_the_snow_line() -> void:
	for index in AlarmStore.day_count():
		AlarmStore.set_day_enabled(index, false)
	var page := await _open_agenda()
	var snow := page.get_node("边框/内容/空提示") as Label
	assert_bool(snow.visible).is_true()
	assert_str(snow.text).is_equal(tr("白茫茫大雪真干净"))
	assert_bool(page.get_node("边框/内容/滚动/边距/列表/本周条").visible).is_false()
	assert_bool(page.get_node("边框/内容/滚动/边距/列表/下周条").visible).is_false()
	await Reel.snap(page, "什么也没有", "只剩白茫茫大雪真干净")


func test_done_once_can_be_deleted_and_undone() -> void:
	var page := await _open_agenda()
	var yesterday := AlarmStore.shift_date(AlarmStore.local_today_key(), -1)
	var item := AlarmStore.add_once("旧事", yesterday, 8, 0)
	var once_id := str(item.get("id", ""))
	var row := _find_row(page, once_id)
	assert_object(row).is_not_null()
	assert_bool(str(row.text).contains(yesterday.split("-")[0])).is_true()
	assert_bool(page.get_node(DONE).visible).is_true()
	await _scroll_to(page, row, 160)
	await Reel.snap(page, "已完成可以删掉再撤销", "已完成里出现这条旧事")
	_hold(page, row)
	var menu: Control = page.hold_menu
	assert_bool(menu.get_node("菜单/列表/删除").visible).is_true()
	assert_bool(menu.get_node("菜单/列表/编辑").visible).is_false()
	assert_bool(menu.get_node("菜单/列表/详情").visible).is_false()
	await Reel.snap(page, "已完成可以删掉再撤销", "长按只有删除")
	menu.get_node("菜单/列表/删除").pressed.emit()
	assert_bool(AlarmStore.once_named(once_id).is_empty()).is_true()
	var undo := page.get_node("边框/内容/添加行/动作/撤销") as Button
	assert_bool(undo.visible).is_true()
	await get_tree().process_frame
	page._scroll.scroll_vertical = int(page._scroll.get_v_scroll_bar().max_value)
	await Reel.snap(page, "已完成可以删掉再撤销", "删掉了，可以撤销")
	undo.pressed.emit()
	assert_str(str(AlarmStore.once_named(once_id).get("id", ""))).is_equal(once_id)
	row = _find_row(page, once_id)
	if row:
		await _scroll_to(page, row, 160)
	await Reel.snap(page, "已完成可以删掉再撤销", "撤销之后它回来了")


func test_upcoming_once_offers_edit_and_delete() -> void:
	var page := await _open_agenda()
	var tomorrow := AlarmStore.shift_date(AlarmStore.local_today_key(), 1)
	var item := AlarmStore.add_once("明天的事", tomorrow, 18, 0)
	var row := _find_row(page, str(item.get("id", "")))
	assert_object(row).is_not_null()
	await _show_row(page, row)
	await Reel.snap(page, "还没到的提醒", "明天的这条还在行程里")
	_hold(page, row)
	var menu: Control = page.hold_menu
	assert_bool(menu.get_node("菜单/列表/编辑").visible).is_true()
	assert_bool(menu.get_node("菜单/列表/删除").visible).is_true()
	assert_bool(menu.get_node("菜单/列表/详情").visible).is_false()
	await Reel.snap(page, "还没到的提醒", "长按可以编辑，也可以删除")


func test_weekly_row_opens_detail_only() -> void:
	var page := await _open_agenda()
	var row := _find_weekly(page)
	assert_object(row).is_not_null()
	await _show_row(page, row)
	await Reel.snap(page, "每周重复只看详情", "今天的起床和睡觉")
	_hold(page, row)
	var menu: Control = page.hold_menu
	assert_bool(menu.get_node("菜单/列表/详情").visible).is_true()
	assert_bool(menu.get_node("菜单/列表/编辑").visible).is_false()
	assert_bool(menu.get_node("菜单/列表/删除").visible).is_false()
	await Reel.snap(page, "每周重复只看详情", "长按只有详情")


func test_week_buckets() -> void:
	var today := AlarmStore.local_today_key()
	assert_str(AlarmStore.week_bucket(today)).is_equal("this")
	assert_str(AlarmStore.week_bucket(AlarmStore.shift_date(today, 7))).is_equal("next")
	assert_str(AlarmStore.week_bucket(AlarmStore.shift_date(today, 14))).is_equal("after")
	assert_str(AlarmStore.week_bucket(AlarmStore.shift_date(today, 21))).is_equal("later")


func _open_agenda() -> Control:
	_runner = scene_runner("res://scenes/main.tscn")
	var main := _runner.scene()
	_quiet(main)
	for _index in 8:
		await get_tree().process_frame
	main.get_node("UI/界面/底栏/图标/行程").pressed.emit()
	for _index in 12:
		await get_tree().process_frame
	_hide_guides(main)
	if not AlarmStore.once_named(AlarmStore.SAMPLE_ONCE_ID).is_empty():
		AlarmStore.remove_once(AlarmStore.SAMPLE_ONCE_ID)
	await get_tree().process_frame
	await get_tree().process_frame
	return main.get_node("UI/界面/行程页/行程")


func _show_row(page: Control, row: Button) -> void:
	await _scroll_to(page, row, 120)


func _scroll_to(page: Control, target: Control, from_top: int) -> void:
	var scroll: ScrollContainer = page._scroll
	for _index in 3:
		await get_tree().process_frame
	var y := target.global_position.y - scroll.global_position.y + scroll.scroll_vertical
	var limit := int(scroll.get_v_scroll_bar().max_value)
	scroll.scroll_vertical = clampi(int(y) - from_top, 0, limit)
	await get_tree().process_frame


func _quiet(main: Node) -> void:
	for child in main.get_children():
		if child is AudioStreamPlayer:
			child.stream_paused = true


func _hide_guides(main: Node) -> void:
	for node_name in ["教程", "计时教程", "行程教程"]:
		var guide := main.get_node_or_null("UI/界面/" + node_name)
		if guide:
			guide.visible = false


func _hold(page: Control, row: Button) -> void:
	var rect := row.get_global_rect()
	assert_bool(rect.size.x > 1.0).is_true()
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = rect.get_center()
	event.global_position = rect.get_center()
	page._on_scroll_input(event)
	page._process(0.5)


func _find_row(page: Control, once_id: String) -> Button:
	for row in page._all_rows():
		var item: Dictionary = row.get_meta("item", {})
		if str(item.get("id", "")) == once_id:
			return row
	return null


func _find_weekly(page: Control) -> Button:
	for row in page._all_rows():
		var item: Dictionary = row.get_meta("item", {})
		if str(item.get("kind", "")) == "weekly" and row.visible:
			return row
	return null


func _section_of(row: Node) -> String:
	var node := row
	while node:
		if str(node.name) in ["本周条", "下周条", "下下周条", "更远条", "已完成条"]:
			return str(node.name)
		node = node.get_parent()
	return ""


func _title(date_key: String, index: int) -> String:
	var name := tr(WEEKDAYS[index])
	if date_key == AlarmStore.local_today_key():
		return "%s · %s" % [name, tr("今天")]
	return name
