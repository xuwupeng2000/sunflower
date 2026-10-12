extends Node


func _ready() -> void:
	var store: Node = get_node("/root/AlarmStore")
	var day: int = store.today_weekday_index()
	var date: String = store.next_date(day, int(store.days[day]["sleep_hour"]), int(store.days[day]["sleep_minute"]))
	print("today local=", store.local_today_key(), " skip date=", date, " weekday=", store.date_weekday_index(date))
	store.set_skipped(date, store.skip_key(), true)
	var weekly := 0
	for group in store.due_groups():
		if group.has("dates"):
			print(group["id"], " ", group["label"], " dates=", JSON.stringify(group["dates"].map(func(o): return [o["date"], o["events"].size()])))
		else:
			weekly += 1
	print("weekly groups=", weekly)
	store.set_skipped(date, store.skip_key(), false)
	print("after undo dated groups=", store.due_groups().filter(func(g): return g.has("dates")).size())
	get_tree().quit()
