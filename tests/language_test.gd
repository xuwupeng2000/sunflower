extends GdUnitTestSuite

const Drive := preload("res://tests/drive.gd")
const Reel := preload("res://tests/shot_reel.gd")
const NAMES := {
	"ja": "日本語", "ko": "한국어", "de": "Deutsch", "fr": "Français",
	"it": "Italiano", "es": "Español", "ru": "Русский",
}

var _runner


func before_test() -> void:
	AlarmStore.once_reminders.clear()
	AlarmStore.tasks.clear()
	for index in AlarmStore.day_count():
		AlarmStore.days[index]["enabled"] = true
	AlarmStore._sync_day_alarms()
	AlarmStore.tutorial_seen = false
	AlarmStore.timer_tutorial_seen = false
	AlarmStore.once_tutorial_seen = false


func after_test() -> void:
	_use("zh")
	AlarmStore.once_reminders.clear()
	AlarmStore.tasks.clear()
	AlarmStore._sync_day_alarms()


func test_japanese() -> void:
	await _tour("ja")


func test_korean() -> void:
	await _tour("ko")


func test_german() -> void:
	await _tour("de")


func test_french() -> void:
	await _tour("fr")


func test_italian() -> void:
	await _tour("it")


func test_spanish() -> void:
	await _tour("es")


func test_russian() -> void:
	await _tour("ru")


func _use(language: String) -> void:
	AlarmStore.language = language
	AlarmStore._apply_locale()


func _tour(language: String) -> void:
	_use(language)
	assert_str(TranslationServer.get_locale()).is_equal(language)
	assert_str(tr("今天")).is_not_equal("今天")
	var story := "语言：%s" % NAMES[language]
	var opened: Array = await Drive.open(self)
	_runner = opened[0]
	var main: Node = opened[1]
	await Reel.snap(main, story, "看花")

	await Drive.show_tab(self, main, "定时", false)
	var guide := main.get_node("UI/界面/教程") as Control
	await Drive.until_visible(self, guide)
	await Reel.snap(main, story, "定时教程第一步")
	Drive.hide_guides(main)
	AlarmStore.tutorial_seen = true
	await Drive.frames(self, 2)
	await Reel.snap(main, story, "定时")

	(main.get_node("UI/界面/定时页/定时/边框/内容/标签行/加号") as Button).pressed.emit()
	var name_field := main.get_node("UI/界面/任务命名/居中/面板/内容/名字") as LineEdit
	name_field.text = tr("🚌 上班")
	await Reel.snap(main, story, "起名字和模板")
	(main.get_node("UI/界面/任务命名/居中/面板/内容/完成") as Button).pressed.emit()
	await Drive.frames(self, 2)
	(main.get_node("UI/界面/定时页/定时/边框/内容/行列/时间/任务时间/添加时间边距/添加时间") as Button).pressed.emit()
	var picker := main.get_node("UI/界面/时间选择") as Control
	Drive.set_clock(picker, 0, 8, 30)
	await Reel.snap(main, story, "选时间和提前多久")
	(picker.get_node("居中/面板/内容/完成") as Button).pressed.emit()
	var apply := main.get_node("UI/界面/应用到") as Control
	for child in apply.get_node("居中/面板/内容/星期").get_children():
		(child as Button).button_pressed = true
	await Reel.snap(main, story, "用在哪几天")
	(apply.get_node("居中/面板/内容/完成") as Button).pressed.emit()
	await Drive.frames(self, 2)
	assert_bool(AlarmStore.task_has_reminder(0)).is_true()
	await Reel.snap(main, story, "定时，加好一条")

	await Drive.show_tab(self, main, "计时", false)
	await Drive.until_visible(self, main.get_node("UI/界面/计时教程") as Control)
	await Reel.snap(main, story, "计时教程第一步")
	Drive.hide_guides(main)
	AlarmStore.timer_tutorial_seen = true
	await Drive.frames(self, 2)
	await Reel.snap(main, story, "计时")

	await Drive.show_tab(self, main, "行程", false)
	await Drive.until_visible(self, main.get_node("UI/界面/行程教程") as Control)
	await Reel.snap(main, story, "行程教程第一步")
	Drive.hide_guides(main)
	AlarmStore.once_tutorial_seen = true
	await Drive.frames(self, 2)
	await Reel.snap(main, story, "行程")
	var page: Control = main.get_node("UI/界面/行程页/行程")
	(page.get_node("边框/内容/添加行/动作/添加") as Button).pressed.emit()
	await Drive.frames(self, 4)
	await Reel.snap(main, story, "加一条只响一次的：选日子")
