class_name TimerTemplate
extends Resource

## 计时页上的一个快捷按钮：点一下就开始倒计时，到点发通知。

@export var title := "⏳ 计时"
@export_range(1, 720) var minutes := 5
