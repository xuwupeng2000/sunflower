extends GdUnitTestSuite

const Drive := preload("res://tests/drive.gd")
const Reel := preload("res://tests/shot_reel.gd")

var _runner


func before_test() -> void:
	AlarmStore.once_reminders.clear()
	AlarmStore.tasks.clear()
	for index in AlarmStore.day_count():
		AlarmStore.days[index]["enabled"] = true
	AlarmStore._sync_day_alarms()


func test_four_once_alarms_then_move_and_delete() -> void:
	var opened: Array = await Drive.open(self)
	_runner = opened[0]
	var main: Node = opened[1]
	await Drive.show_tab(self, main, "行程")
	var page: Control = main.get_node("UI/界面/行程页/行程")
	await _add_on_day(main, page, "本周一事", "本周")
	await _add_on_day(main, page, "下周一事", "下周")
	await _add_on_day(main, page, "下下周一事", "下下周")
	await _add_on_custom(main, page, "更远一事", _year_ahead(), 3, 1, "更远")
	assert_str(_bucket_of("本周一事")).is_equal("this")
	assert_str(_bucket_of("下周一事")).is_equal("next")
	assert_str(_bucket_of("下下周一事")).is_equal("after")
	assert_str(_bucket_of("更远一事")).is_equal("later")
	assert_str(Drive.section_of(Drive.find_label(page, "本周一事"))).is_equal("本周条")
	assert_str(Drive.section_of(Drive.find_label(page, "下周一事"))).is_equal("下周条")
	assert_str(Drive.section_of(Drive.find_label(page, "下下周一事"))).is_equal("下下周条")
	assert_str(Drive.section_of(Drive.find_label(page, "更远一事"))).is_equal("更远条")
	var moving := Drive.find_label(page, "本周一事")
	var moving_id := str((moving.get_meta("item") as Dictionary).get("id", ""))
	await Drive.scroll_to(self, page, moving, 140)
	Drive.hold_row(page, moving)
	await Reel.snap(page, "四个一次性提醒", "长按本周这一条")
	(page.hold_menu.get_node("菜单/列表/编辑") as Button).pressed.emit()
	await Drive.frames(self, 3)
	await _pick_custom_date(main, _year_ahead(), 8, 8)
	await _finish_time(main, "改到明年 8 月 8 日")
	await Drive.frames(self, 2)
	assert_str(AlarmStore.week_bucket(str(AlarmStore.once_named(moving_id).get("date", "")))).is_equal("later")
	page = main.get_node("UI/界面/行程页/行程")
	moving = Drive.find_label(page, "本周一事")
	assert_str(Drive.section_of(moving)).is_equal("更远条")
	await Drive.scroll_to(self, page, moving, 140)
	await Reel.snap(page, "四个一次性提醒", "它跑到了更远")
	Drive.hold_row(page, moving)
	(page.hold_menu.get_node("菜单/列表/编辑") as Button).pressed.emit()
	await Drive.frames(self, 3)
	var back := Drive.first_open_day(main.get_node("UI/界面/单次日期"), "下周")
	await _pick_day(main, back, "改回下周")
	await _finish_time(main, "时间还是晚上 11 点")
	await Drive.frames(self, 2)
	assert_str(AlarmStore.week_bucket(str(AlarmStore.once_named(moving_id).get("date", "")))).is_equal("next")
	moving = Drive.find_label(page, "本周一事")
	assert_str(Drive.section_of(moving)).is_equal("下周条")
	await Drive.scroll_to(self, page, moving, 140)
	await Reel.snap(page, "四个一次性提醒", "又回到下周")
	Drive.hold_row(page, moving)
	await Reel.snap(page, "四个一次性提醒", "再长按，这次删掉")
	(page.hold_menu.get_node("菜单/列表/删除") as Button).pressed.emit()
	await Drive.frames(self, 2)
	assert_bool(AlarmStore.once_named(moving_id).is_empty()).is_true()
	assert_object(Drive.find_label(page, "本周一事")).is_null()
	assert_object(Drive.find_label(page, "下周一事")).is_not_null()
	assert_object(Drive.find_label(page, "下下周一事")).is_not_null()
	assert_object(Drive.find_label(page, "更远一事")).is_not_null()
	page._scroll.scroll_vertical = 0
	await Reel.snap(page, "四个一次性提醒", "本周那条不见了，另外三条还在")


func _add_on_day(main: Node, page: Control, once_name: String, week: String) -> void:
	_press_add(page)
	var add := main.get_node("UI/界面/单次日期") as Control
	await Drive.frames(self, 2)
	var day := Drive.first_open_day(add, week)
	assert_object(day).is_not_null()
	(add.get_node("居中/面板/内容/名字") as LineEdit).text = once_name
	Drive.tap_scroll(add, day)
	await Reel.snap(main, "四个一次性提醒", "选" + week + "的一天，名叫" + once_name)
	(add.get_node("居中/面板/内容/确认") as Button).pressed.emit()
	await _finish_time(main, once_name + "的时间")
	await Drive.frames(self, 2)
	var row := Drive.find_label(page, once_name)
	assert_object(row).is_not_null()
	await Drive.scroll_to(self, page, row, 140)
	await Reel.snap(page, "四个一次性提醒", once_name + "出现在" + week)


func _add_on_custom(main: Node, page: Control, once_name: String, year: int, month: int, day: int, caption: String) -> void:
	_press_add(page)
	var add := main.get_node("UI/界面/单次日期") as Control
	await Drive.frames(self, 2)
	(add.get_node("居中/面板/内容/名字") as LineEdit).text = once_name
	await _pick_custom_date(main, year, month, day)
	await _finish_time(main, once_name + "的时间")
	await Drive.frames(self, 2)
	var row := Drive.find_label(page, once_name)
	assert_object(row).is_not_null()
	await Drive.scroll_to(self, page, row, 120)
	await Reel.snap(page, "四个一次性提醒", once_name + "出现在" + caption)


func _pick_day(main: Node, day: Button, caption: String) -> void:
	var add := main.get_node("UI/界面/单次日期") as Control
	assert_bool(add.visible).is_true()
	Drive.tap_scroll(add, day)
	await Reel.snap(main, "四个一次性提醒", caption)
	(add.get_node("居中/面板/内容/确认") as Button).pressed.emit()


func _pick_custom_date(main: Node, year: int, month: int, day_number: int) -> void:
	var add := main.get_node("UI/界面/单次日期") as Control
	var custom := add.get_node("居中/面板/内容/滚动/块/自选边距/自选日期") as Control
	Drive.tap_scroll(add, custom)
	await Drive.frames(self, 2)
	var popup := add.get_node("自选弹窗") as Control
	assert_bool(popup.visible).is_true()
	var year_wheel: Control = popup.get_node("居中/面板/内容/滚轮区/列/年")
	var month_wheel: Control = popup.get_node("居中/面板/内容/滚轮区/列/月")
	var day_wheel: Control = popup.get_node("居中/面板/内容/滚轮区/列/日")
	year_wheel.value = year
	month_wheel.value = month
	day_wheel.value = day_number
	year_wheel.queue_redraw()
	month_wheel.queue_redraw()
	day_wheel.queue_redraw()
	await Reel.snap(main, "四个一次性提醒", "自选 %d-%02d-%02d" % [year, month, day_number])
	(popup.get_node("居中/面板/内容/完成") as Button).pressed.emit()


func _finish_time(main: Node, caption: String) -> void:
	var picker := main.get_node("UI/界面/时间选择") as Control
	assert_bool(picker.visible).is_true()
	Drive.set_clock(picker, 1, 11, 0)
	await Reel.snap(main, "四个一次性提醒", caption)
	(picker.get_node("居中/面板/内容/完成") as Button).pressed.emit()
	var summary := main.get_node("UI/界面/单次确认") as Control
	assert_bool(summary.visible).is_true()
	await Reel.snap(main, "四个一次性提醒", "确认这条提醒")
	(summary.get_node("居中/面板/内容/按钮/确认") as Button).pressed.emit()


func _press_add(page: Control) -> void:
	(page.get_node("边框/内容/添加行/动作/添加") as Button).pressed.emit()


func _bucket_of(once_name: String) -> String:
	for item in AlarmStore.once_reminders:
		if str(item.get("name", "")) == once_name:
			return AlarmStore.week_bucket(str(item.get("date", "")))
	return ""


func _year_ahead() -> int:
	return int(Time.get_date_dict_from_system()["year"]) + 1
