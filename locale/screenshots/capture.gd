extends SceneTree

var store: Node
var main: Node
var viewport: SubViewport
const OUT := "/Users/pengwu/Documents/GitHub/sunflower/locale/screenshots/1.5"
const LANGS := {"en-US": "en", "zh-Hans": "zh", "zh-Hant": "zh_TW", "ja": "ja", "ko": "ko", "de": "de", "fr": "fr", "it": "it", "es": "es", "ru": "ru"}

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in count:
		await process_frame

func shot(locale: String, name: String) -> void:
	await frames(12)
	RenderingServer.force_draw(false)
	var image := viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	var dir := OUT.path_join(locale)
	DirAccess.make_dir_recursive_absolute(dir)
	var file := dir.path_join(name + ".png")
	image.save_png(file)
	print("CAPTURE ", file, " ", image.get_size())

func tab(name: String) -> void:
	main.get_node("UI/界面/底栏/图标/" + name).pressed.emit()
	await frames(25)

func quiet(node: Node) -> void:
	if node is AudioStreamPlayer:
		node.stream_paused = true
	for child in node.get_children():
		quiet(child)

func run() -> void:
	store = root.get_node("AlarmStore")
	root.size = Vector2i(390, 844)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1320, 2868)
	viewport.size_2d_override = Vector2i(390, 847)
	viewport.size_2d_override_stretch = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)
	var args := OS.get_cmdline_user_args()
	var all_flowers := "--all-flowers" in args
	var flower_only := "--flower-only" in args or all_flowers
	var locales: Array[String] = []
	for value in args:
		if not value.begins_with("--"):
			locales.append(value)
	for locale in LANGS:
		if not locales.is_empty() and locale not in locales:
			continue
		ProjectSettings.set_setting("screenshots/language", LANGS[locale])
		store.language = LANGS[locale]
		store._apply_locale()
		store.tasks.clear()
		store.once_reminders.clear()
		store.skips.clear()
		store.care.clear()
		store.snoozes.clear()
		store.active_timer = {}
		store.custom_timers.clear()
		store.tutorial_seen = true
		store.timer_tutorial_seen = true
		store.once_tutorial_seen = true
		store.sleep_paused = false
		store.fertilizer = 3
		store.fertilizer_used = 0
		store.flower_kind = 0
		store.pot_kind = 7
		store.last_watered = store.today_key()
		for i in 7:
			store.days[i] = {"wake_hour": 8 if i >= 5 else 7, "wake_minute": 30 if i >= 5 else 0, "sleep_hour": 23, "sleep_minute": 0, "enabled": true}
		var work := tr("🚌 上班")
		var grocery := tr("🛒 买菜")
		store.add_task(work)
		store.set_task_times_on_days(0, [0,1,2,3,4], 9, 0, {"hour":17,"minute":30}, 30)
		var today: String = store.local_today_key()
		store.add_once(grocery, today, 19, 0)
		store.add_once(tr("📅 会议"), store.shift_date(today, 1), 10, 30, 15)
		store.add_once(tr("📚 上课"), store.shift_date(today, 7), 14, 0, 15)
		store._sync_day_alarms()
		main = load("res://scenes/main.tscn").instantiate()
		viewport.add_child(main)
		quiet(main)
		await frames(180)
		await shot(locale, "01-flower")
		if all_flowers:
			var kinds := ["07-moth-orchid", "08-clivia", "09-cyclamen", "10-kalanchoe"]
			for kind in range(1, 5):
				main.queue_free()
				await frames(5)
				store.flower_kind = kind
				main = load("res://scenes/main.tscn").instantiate()
				viewport.add_child(main)
				quiet(main)
				await frames(180)
				await shot(locale, kinds[kind - 1])
		if flower_only:
			main.queue_free()
			await frames(5)
			continue
		await tab("定时")
		main._show_custom_task(0)
		await shot(locale, "02-weekly")
		for day in 5:
			store.clear_task_end(0, day)
			store.set_task_lead(0, day, 0)
		await tab("行程")
		await shot(locale, "03-agenda")
		main._open_once_add()
		var add: Control = main.get_node("UI/界面/单次日期")
		add.open(grocery, store.shift_date(today,1))
		await shot(locale, "04-once")
		add.visible = false
		await tab("定时")
		main._show_custom_task(0)
		store.set_task_times_on_days(0, [0,1,2,3,4], 9, 0, {"hour":17,"minute":30}, 30)
		main._selected_day = 0
		main._open_time_picker("task")
		await shot(locale, "05-arrival")
		main.get_node("UI/界面/时间选择").visible = false
		await tab("计时")
		main.get_node("UI/界面/计时页/计时").start_timer(tr(load("res://timers/noodle.tres").title), 5)
		await shot(locale, "06-timer")
		main.queue_free()
		await frames(5)
	quit()
