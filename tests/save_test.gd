extends GdUnitTestSuite


func test_old_save_keeps_alarms_once_flower_and_pot() -> void:
	var days: Array = []
	var times: Array = []
	for index in 7:
		days.append({
			"wake_hour": 6 if index == 0 else 7,
			"wake_minute": 30 if index == 0 else 0,
			"sleep_hour": 23,
			"sleep_minute": 0,
			"enabled": true,
		})
		times.append({"hour": 9, "minute": 0, "enabled": index == 0})
	_write({
		"days": days,
		"tasks": [{"id": "task-old", "name": "读书", "times": times}],
		"once_reminders": [{
			"id": "once-old",
			"name": "旧提醒",
			"date": "2099-06-01",
			"hour": 9,
			"minute": 30,
		}],
		"flower_kind": 1,
		"flower_kind_v": 2,
		"pot_kind": 3,
		"tutorial_seen": true,
		"tutorial_v": 4,
		"once_tutorial_seen": true,
		"once_tutorial_v": 3,
		"not_a_real_key": true,
	})
	AlarmStore.load_data()
	assert_int(int(AlarmStore.find_alarm("wake-1").get("hour", -1))).is_equal(6)
	assert_int(int(AlarmStore.find_alarm("wake-1").get("minute", -1))).is_equal(30)
	assert_str(str(AlarmStore.once_named("once-old").get("name", ""))).is_equal("旧提醒")
	assert_int(AlarmStore.task_count()).is_equal(1)
	assert_str(str(AlarmStore.task_at(0).get("name", ""))).is_equal("读书")
	assert_int(AlarmStore.flower_kind).is_equal(1)
	assert_int(AlarmStore.pot_kind).is_equal(3)


func test_missing_keys_still_open() -> void:
	var days: Array = []
	for _index in 7:
		days.append({
			"wake_hour": 5,
			"wake_minute": 15,
			"sleep_hour": 22,
			"sleep_minute": 0,
			"enabled": true,
		})
	_write({"days": days})
	AlarmStore.load_data()
	assert_int(int(AlarmStore.find_alarm("wake-1").get("hour", -1))).is_equal(5)
	assert_int(int(AlarmStore.find_alarm("wake-1").get("minute", -1))).is_equal(15)
	assert_int(AlarmStore.task_count()).is_equal(0)
	assert_int(AlarmStore.flower_kind).is_equal(0)
	assert_int(AlarmStore.pot_kind).is_equal(0)
	assert_str(str(AlarmStore.once_named("sample-once").get("name", ""))).is_not_empty()


func _write(data: Dictionary) -> void:
	var file := FileAccess.open("user://sunflower_alarms.json", FileAccess.WRITE)
	assert_object(file).is_not_null()
	file.store_string(JSON.stringify(data))
	file.close()
