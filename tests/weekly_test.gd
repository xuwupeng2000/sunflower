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


func test_add_weekly_then_edit_and_delete() -> void:
	var opened: Array = await Drive.open(self)
	_runner = opened[0]
	var main: Node = opened[1]
	await Drive.show_tab(self, main, "定时")
	(main.get_node("UI/界面/定时页/定时/边框/内容/标签行/加号") as Button).pressed.emit()
	var name_field := main.get_node("UI/界面/任务命名/居中/面板/内容/名字") as LineEdit
	name_field.text = "浇花"
	await Reel.snap(main, "添加每周提醒", "写下浇花")
	(main.get_node("UI/界面/任务命名/居中/面板/内容/完成") as Button).pressed.emit()
	await Drive.frames(self, 2)
	assert_int(AlarmStore.task_count()).is_equal(1)
	assert_str(AlarmStore.task_label(AlarmStore.task_at(0))).is_equal("浇花")
	await Reel.snap(main, "添加每周提醒", "新标签还没有时间")
	(main.get_node("UI/界面/定时页/定时/边框/内容/行列/时间/任务时间/添加时间边距/添加时间") as Button).pressed.emit()
	var picker := main.get_node("UI/界面/时间选择") as Control
	Drive.set_clock(picker, 0, 9, 30)
	await Reel.snap(main, "添加每周提醒", "选上午 9:30")
	(picker.get_node("居中/面板/内容/完成") as Button).pressed.emit()
	var apply := main.get_node("UI/界面/应用到") as Control
	assert_bool(apply.visible).is_true()
	for child in apply.get_node("居中/面板/内容/星期").get_children():
		(child as Button).button_pressed = true
	await Reel.snap(main, "添加每周提醒", "七天都要提醒")
	(apply.get_node("居中/面板/内容/完成") as Button).pressed.emit()
	await Drive.frames(self, 2)
	assert_bool(AlarmStore.task_has_reminder(0)).is_true()
	await Reel.snap(main, "添加每周提醒", "浇花定在上午 9:30")
	await Drive.show_tab(self, main, "行程")
	var page: Control = main.get_node("UI/界面/行程页/行程")
	var row := Drive.find_label(page, "浇花")
	assert_object(row).is_not_null()
	await Drive.scroll_to(self, page, row, 140)
	await Reel.snap(page, "添加每周提醒", "行程里出现了浇花")
	var day := int((row.get_meta("item") as Dictionary).get("day_index", 0))
	Drive.hold_row(page, row)
	var menu: Control = page.hold_menu
	assert_bool(menu.get_node("菜单/列表/详情").visible).is_true()
	await Reel.snap(page, "添加每周提醒", "长按可以去改这个闹钟")
	(menu.get_node("菜单/列表/详情") as Button).pressed.emit()
	await Drive.frames(self, 20)
	Drive.hide_guides(main)
	await Drive.frames(self, 2)
	assert_bool(main.get_node("UI/界面/定时页").visible).is_true()
	(main.get_node("UI/界面/定时页/定时/边框/内容/行列/时间/任务时间/钟点行/开始/钟点") as Button).pressed.emit()
	Drive.set_clock(picker, 1, 4, 45)
	await Reel.snap(main, "添加每周提醒", "把这一天改成下午 4:45")
	(picker.get_node("居中/面板/内容/完成") as Button).pressed.emit()
	await Drive.frames(self, 2)
	var moment: Dictionary = AlarmStore.task_at(0)["times"][day]
	assert_int(int(moment["hour"])).is_equal(16)
	assert_int(int(moment["minute"])).is_equal(45)
	await Reel.snap(main, "添加每周提醒", "这一天已经是 16:45")
	await Drive.show_tab(self, main, "行程")
	page = main.get_node("UI/界面/行程页/行程")
	row = _row_with_time(page, "16:45")
	assert_object(row).is_not_null()
	await Drive.scroll_to(self, page, row, 140)
	await Reel.snap(page, "添加每周提醒", "行程里这一天变成 16:45")
	await Drive.show_tab(self, main, "定时")
	var tab := _tab_named(main, "浇花")
	assert_object(tab).is_not_null()
	main._open_tab_menu(tab)
	await Drive.frames(self, 2)
	menu = main.get_node("UI/界面/长按菜单")
	assert_bool(menu.get_node("菜单/列表/删除").visible).is_true()
	await Reel.snap(main, "添加每周提醒", "长按标签可以删除")
	(menu.get_node("菜单/列表/删除") as Button).pressed.emit()
	await Reel.snap(main, "添加每周提醒", "确认删掉浇花")
	(main.get_node("UI/界面/删除提醒/居中/面板/内容/按钮/删除") as Button).pressed.emit()
	await Drive.frames(self, 2)
	assert_int(AlarmStore.task_count()).is_equal(0)
	await Drive.show_tab(self, main, "行程")
	page = main.get_node("UI/界面/行程页/行程")
	assert_object(Drive.find_label(page, "浇花")).is_null()
	page._scroll.scroll_vertical = 0
	await Reel.snap(page, "添加每周提醒", "删掉之后行程里没有浇花了")


func _row_with_time(page: Control, clock: String) -> Button:
	for row in page._all_rows():
		var item: Dictionary = row.get_meta("item", {})
		if str(item.get("label", "")) != "浇花" or not row.visible:
			continue
		if row.text.contains(clock):
			return row
	return null


func _tab_named(main: Node, task_name: String) -> Button:
	for button in main._task_buttons:
		if str((button as Button).text).contains(task_name):
			return button
	return null
