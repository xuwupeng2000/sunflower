extends GdUnitTestSuite

const Drive := preload("res://tests/drive.gd")
const Reel := preload("res://tests/shot_reel.gd")

var _runner


func before_test() -> void:
	AlarmStore.custom_timers.clear()
	AlarmStore.clear_timer()


func test_create_start_and_stop_timer() -> void:
	var opened: Array = await Drive.open(self)
	_runner = opened[0]
	var main: Node = opened[1]
	await Drive.show_tab(self, main, "计时")
	var timer: Control = main.get_node("UI/界面/计时页/计时")
	assert_bool(timer.get_node("边框/内容/大字/取消").visible).is_false()
	await Reel.snap(timer, "计时", "还没开始")
	(timer.get_node("边框/内容/滚动/按钮/自定") as Button).pressed.emit()
	var dialog := main.get_node("UI/界面/自定计时") as Control
	assert_bool(dialog.visible).is_true()
	(dialog.get_node("居中/面板/内容/名字") as LineEdit).text = "泡茶"
	var hour: Control = dialog.get_node("居中/面板/内容/滚轮区/列/时")
	var minute: Control = dialog.get_node("居中/面板/内容/滚轮区/列/分")
	hour.value = 0
	minute.value = 8
	hour.queue_redraw()
	minute.queue_redraw()
	await Reel.snap(main, "计时", "写上泡茶，定 8 分钟")
	(dialog.get_node("居中/面板/内容/开始") as Button).pressed.emit()
	await Drive.frames(self, 2)
	assert_int(AlarmStore.custom_timers.size()).is_equal(1)
	assert_str(str(AlarmStore.custom_timers[0]["title"])).is_equal("泡茶")
	assert_int(int(AlarmStore.custom_timers[0]["minutes"])).is_equal(8)
	assert_bool(AlarmStore.active_timer.is_empty()).is_false()
	assert_bool(timer.get_node("边框/内容/大字/取消").visible).is_true()
	assert_str((timer.get_node("边框/内容/大字/名字") as Label).text).is_equal("泡茶")
	await Reel.snap(timer, "计时", "泡茶开始倒计时")
	(timer.get_node("边框/内容/大字/取消") as Button).pressed.emit()
	await Drive.frames(self, 2)
	assert_bool(AlarmStore.active_timer.is_empty()).is_true()
	assert_bool(timer.get_node("边框/内容/大字/取消").visible).is_false()
	await Reel.snap(timer, "计时", "停掉了，泡茶还留在下面")
