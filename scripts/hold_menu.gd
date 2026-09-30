extends Control
## 长按弹出的小菜单：挨着按住的那个按钮，别处暗一点；点外面就收起。

const GAP := 12.0
const EDGE := 16.0

@onready var _menu: Control = $菜单
@onready var _pause: Button = $菜单/列表/暂停
@onready var _line: Control = $菜单/列表/分隔
@onready var _delete: Button = $菜单/列表/删除

var _target: Control
var _on_choose: Callable


func _ready() -> void:
	visible = false
	gui_input.connect(_on_gui_input)
	_pause.pressed.connect(_choose.bind("pause"))
	_delete.pressed.connect(_choose.bind("delete"))


## pause_text 为空就不显示暂停那一行；can_delete 为假就不显示删除。
## 选了之后调 on_choose("pause") 或 on_choose("delete")。
func open(target: Control, pause_text: String, can_delete: bool, on_choose: Callable) -> void:
	close()
	_target = target
	_on_choose = on_choose
	_pause.visible = not pause_text.is_empty()
	_pause.text = pause_text
	_delete.visible = can_delete
	_line.visible = _pause.visible and _delete.visible
	# 按住的那个浮在遮罩上面，看着像被拎起来。
	_target.z_index = 1
	visible = true
	_menu.reset_size()
	var rect := target.get_global_rect()
	var screen := get_global_rect()
	var x := clampf(rect.position.x, screen.position.x + EDGE, screen.end.x - EDGE - _menu.size.x)
	var y := rect.end.y + GAP
	if y + _menu.size.y > screen.end.y - EDGE:
		y = rect.position.y - GAP - _menu.size.y
	_menu.global_position = Vector2(x, y)
	Input.vibrate_handheld(15)


func close() -> void:
	if _target != null and is_instance_valid(_target):
		_target.z_index = 0
	_target = null
	visible = false


func _choose(action: String) -> void:
	var callback := _on_choose
	close()
	if callback.is_valid():
		callback.call(action)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()
		accept_event()
