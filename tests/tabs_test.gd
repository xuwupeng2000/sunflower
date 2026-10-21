extends GdUnitTestSuite

const Reel := preload("res://tests/shot_reel.gd")

var _runner: GdUnitSceneRunner


func before() -> void:
	AlarmStore.once_tutorial_seen = true
	AlarmStore.tutorial_seen = true
	AlarmStore.timer_tutorial_seen = true


func test_tab_icons_open_pages_and_return_to_flower() -> void:
	_runner = scene_runner("res://scenes/main.tscn")
	var main := _runner.scene()
	for child in main.get_children():
		if child is AudioStreamPlayer:
			child.stream_paused = true
	for _index in 8:
		await get_tree().process_frame
	var icons := main.get_node("UI/界面/底栏/图标")
	await Reel.snap(main, "底栏切换", "先在看花")
	await _open(main, icons.get_node("行程"), "行程")
	assert_bool(main.get_node("UI/界面/行程页").visible).is_true()
	assert_bool(main.get_node("UI/界面/看花页").visible).is_false()
	await _open(main, icons.get_node("行程"), "再点行程，回到看花")
	assert_bool(main.get_node("UI/界面/看花页").visible).is_true()
	assert_bool(main.get_node("UI/界面/行程页").visible).is_false()
	await _open(main, icons.get_node("花盆"), "花盆")
	assert_bool(main.get_node("UI/界面/花盆页").visible).is_true()
	assert_bool(main.get_node("UI/界面/看花页").visible).is_true()
	await _open(main, icons.get_node("定时"), "定时")
	assert_bool(main.get_node("UI/界面/定时页").visible).is_true()
	assert_bool(main.get_node("UI/界面/看花页").visible).is_false()
	await _open(main, icons.get_node("计时"), "计时")
	assert_bool(main.get_node("UI/界面/计时页").visible).is_true()
	assert_bool(main.get_node("UI/界面/定时页").visible).is_false()


func _open(main: Node, button: Button, caption: String) -> void:
	button.pressed.emit()
	for _index in 12:
		await get_tree().process_frame
	for node_name in ["教程", "计时教程", "行程教程"]:
		var guide := main.get_node_or_null("UI/界面/" + node_name)
		if guide:
			guide.visible = false
	await Reel.snap(main, "底栏切换", caption)
