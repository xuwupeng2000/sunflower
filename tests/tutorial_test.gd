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


func test_tutorials_step_through() -> void:
	var opened: Array = await Drive.open(self)
	_runner = opened[0]
	var main: Node = opened[1]
	await _walk(main, "定时", "教程", "定时教程", [
		["加号说明", "先圈住加号"],
		["星期说明", "星期和时间"],
		["长按说明", "长按上面的标签"],
		["日期说明", "长按左边的某一天"],
	])
	await _walk(main, "计时", "计时教程", "计时教程", [
		["模板说明", "点一下就开始计时"],
		["长按说明", "长按自己加的可以删"],
		["自定说明", "点加号自己定时长"],
	])
	await _walk(main, "行程", "行程教程", "行程教程", [
		["颜色说明", "蓝的每周重复，黄的只响一次"],
		["跳转说明", "长按蓝的可以去改闹钟"],
		["添加说明", "点这里加一条只响一次"],
		["删除说明", "长按黄的可以改，也可以删"],
	])


func _walk(main: Node, tab: String, guide_name: String, story: String, steps: Array) -> void:
	await Drive.show_tab(self, main, tab, false)
	var guide := main.get_node("UI/界面/" + guide_name) as Control
	await Drive.until_visible(self, guide)
	assert_bool(guide.visible).is_true()
	for step in steps:
		var note := guide.get_node(str(step[0])) as CanvasItem
		assert_bool(note.visible).is_true()
		await Reel.snap(main, story, str(step[1]))
		Drive.tap_guide(guide)
		await Drive.frames(self, 2)
	assert_bool(guide.visible).is_false()
	await Reel.snap(main, story, "点完最后一步，教程收起")
