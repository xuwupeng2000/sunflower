extends GdUnitTestSuite

const Drive := preload("res://tests/drive.gd")
const Reel := preload("res://tests/shot_reel.gd")

var _runner


func before_test() -> void:
	AlarmStore.fertilizer = 0
	AlarmStore.fertilizer_used = 0
	AlarmStore.last_watered = AlarmStore.today_key()
	AlarmStore.care.clear()
	AlarmStore.flower_kind = 0
	AlarmStore.tutorial_seen = true
	AlarmStore.timer_tutorial_seen = true
	AlarmStore.once_tutorial_seen = true


func test_wilt_then_water() -> void:
	AlarmStore.fertilizer_used = 2
	AlarmStore.last_watered = AlarmStore.shift_date(AlarmStore.today_key(), -7)
	var opened: Array = await Drive.open(self)
	_runner = opened[0]
	var main: Node = opened[1]
	var flower: Node3D = main._sunflower
	await _wait_grown(main, flower, 2)
	assert_int(AlarmStore.wilt_level()).is_equal(3)
	assert_int(flower._wilt_level).is_equal(3)
	await Reel.snap(main, "枯萎再浇水", "七天没浇，干枯低头")
	var at: Vector2 = flower.plant_screen_position()
	assert_bool(flower.hits_plant(at)).is_true()
	main._start_care_drag("water", main._water_button)
	main._drag_care_to(at, at)
	await Drive.frames(self, 4)
	await Reel.snap(main, "枯萎再浇水", "水壶拖到花上")
	main._finish_care_drag(at, at)
	await _wait_grown(main, flower, 2)
	assert_int(AlarmStore.wilt_level()).is_equal(0)
	assert_int(flower._wilt_level).is_equal(0)
	assert_bool(AlarmStore.watered_today()).is_true()
	await Reel.snap(main, "枯萎再浇水", "浇完，头抬起来了")


func test_ten_feeds_each_grows() -> void:
	AlarmStore.fertilizer = 10
	var opened: Array = await Drive.open(self)
	_runner = opened[0]
	var main: Node = opened[1]
	var flower: Node3D = main._sunflower
	await _wait_grown(main, flower, 0)
	var height := _height(flower)
	await Reel.snap(main, "施肥十次", "还没施肥，高 %s" % _text(height))
	for pack in 10:
		var at: Vector2 = flower.plant_screen_position()
		assert_bool(flower.hits_plant(at)).is_true()
		main._start_care_drag("feed", main._feed_button)
		main._finish_care_drag(at, at)
		var used := pack + 1
		await _wait_grown(main, flower, used)
		assert_int(AlarmStore.fertilizer_used).is_equal(used)
		assert_int(AlarmStore.fertilizer).is_equal(10 - used)
		var next := _height(flower)
		assert_bool(next > height).is_true()
		height = next
		await Reel.snap(main, "施肥十次", "第 %d 包，高 %s" % [used, _text(height)])


func _height(flower: Node3D) -> float:
	var growth := float(flower._growth_shown)
	var lifted := 0.0
	if flower._stretch:
		lifted = float(flower._stretch.stem_length()) * float(flower._stretch.stretch)
	return snapped(float(flower._rig_height) * float(flower._rig_scale(growth)) + lifted, 0.01)


func _text(height: float) -> String:
	return "%.2f" % height


func _wait_grown(main: Node, flower: Node3D, used: int) -> void:
	var tip := main.get_node("UI/界面/看花页/飘字") as CanvasItem
	for _index in 500:
		var motion: Tween = flower._motion
		var rig: Tween = flower._rig_tween
		var busy := bool(main._feeding) or (motion != null and motion.is_valid()) or (rig != null and rig.is_valid())
		var grown := absf(float(flower._growth_shown) - float(used)) < 0.02
		if grown and not busy and not tip.visible:
			await Drive.frames(self, 2)
			return
		await get_tree().process_frame
