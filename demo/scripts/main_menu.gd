extends Control

const ARENA_SCENE := "res://demo/soccer_arena.tscn"

var _device_label: Label
var _help_panel: PanelContainer


func _ready() -> void:
	_build_background()
	_build_menu()
	_build_help()
	_refresh_device()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _build_background() -> void:
	var background := preload("res://demo/scripts/hex_background.gd").new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var accent := ColorRect.new()
	accent.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	accent.offset_top = -8
	accent.color = Color("f2b705")
	background.add_child(accent)


func _build_menu() -> void:
	var safe := MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.add_theme_constant_override("margin_left", 72)
	safe.add_theme_constant_override("margin_right", 72)
	safe.add_theme_constant_override("margin_top", 56)
	safe.add_theme_constant_override("margin_bottom", 48)
	add_child(safe)
	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 74)
	safe.add_child(layout)

	var intro := VBoxContainer.new()
	intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intro.add_theme_constant_override("separation", 18)
	layout.add_child(intro)
	var badge := Label.new()
	badge.text = "SBS  ·  DRONE SOCCER"
	badge.add_theme_color_override("font_color", Color("ffca14"))
	badge.add_theme_font_size_override("font_size", 20)
	intro.add_child(badge)
	var title := Label.new()
	title.text = "SBS FPV\n穿越机训练模拟器"
	title.add_theme_font_size_override("font_size", 58)
	title.add_theme_color_override("font_color", Color("f4fbff"))
	intro.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "真实 Acro 手感 · Betaflight Rate · USB 遥控器校准"
	subtitle.add_theme_font_size_override("font_size", 21)
	subtitle.add_theme_color_override("font_color", Color("a8c5cd"))
	intro.add_child(subtitle)
	var feature := Label.new()
	feature.text = "● FPV / 跟随 / 目视视角    ● 独立通道映射    ● 400 Hz 物理"
	feature.add_theme_font_size_override("font_size", 17)
	feature.add_theme_color_override("font_color", Color("75a6b0"))
	intro.add_child(feature)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	intro.add_child(spacer)
	var version := Label.new()
	version.text = "FIRST PLAYABLE · Godot 4"
	version.add_theme_color_override("font_color", Color("547985"))
	intro.add_child(version)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(430, 0)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.08, 0.08, 0.095, 0.96)
	card_style.border_color = Color("595765")
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(18)
	card.add_theme_stylebox_override("panel", card_style)
	layout.add_child(card)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 34)
	card.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)
	var heading := Label.new()
	heading.text = "进入开放训练场"
	heading.add_theme_font_size_override("font_size", 30)
	column.add_child(heading)
	_device_label = Label.new()
	_device_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_device_label.add_theme_color_override("font_color", Color("84dbe7"))
	_device_label.custom_minimum_size.y = 52
	column.add_child(_device_label)
	column.add_child(_make_button("开始训练", _start_training, true))
	column.add_child(_make_button("控制器识别与校准", _start_calibration))
	column.add_child(_make_button("设置 · 画质 / OSD / 飞控", _start_settings))
	column.add_child(_make_button("操作说明", _toggle_help))
	column.add_child(_make_button("退出游戏", _quit_game))
	var note := Label.new()
	note.text = "首次使用建议先完成遥控器校准。训练中按 Esc 可暂停、返回主页或退出。"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", Color("76949b"))
	column.add_child(note)


func _make_button(text_value: String, callback: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 58
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(callback)
	if primary:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("e7a51a")
		style.set_corner_radius_all(10)
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_color_override("font_color", Color("172027"))
	return button


func _build_help() -> void:
	_help_panel = PanelContainer.new()
	_help_panel.set_anchors_preset(Control.PRESET_CENTER)
	_help_panel.position = Vector2(-330, -250)
	_help_panel.size = Vector2(660, 500)
	_help_panel.visible = false
	add_child(_help_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	_help_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	margin.add_child(column)
	var title := Label.new()
	title.text = "操作说明"
	title.add_theme_font_size_override("font_size", 30)
	column.add_child(title)
	var body := Label.new()
	body.text = "遥控器\n左摇杆：油门 / 偏航　　右摇杆：俯仰 / 横滚\n解锁、锁定与重置均可在控制器设置中识别遥控器开关。\n\n键盘辅助\nR 复位　C 切换视角　方向键旋转及拉近镜头　K 设置\nEsc 暂停与返回主页\n\n训练目标\n控制无人机稳定穿过蓝、黄球门。穿门后自动计分并复位。"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	column.add_child(_make_button("关闭", _toggle_help, true))


func _start_training() -> void:
	get_tree().change_scene_to_file(ARENA_SCENE)


func _start_calibration() -> void:
	InputProfile.request_calibration()
	get_tree().change_scene_to_file(ARENA_SCENE)

func _start_settings() -> void:
	InputProfile.request_calibration()
	get_tree().change_scene_to_file(ARENA_SCENE)


func _toggle_help() -> void:
	_help_panel.visible = not _help_panel.visible


func _quit_game() -> void:
	get_tree().quit()


func _refresh_device() -> void:
	var connected := not InputProfile.connected_devices().is_empty()
	_device_label.text = ("● 已连接：" + InputProfile.device_name()) if connected else "○ 未检测到 USB 遥控器，可先使用键盘查看场景"


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_refresh_device()
