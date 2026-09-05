extends Node

@export var drone_path: NodePath
@export var controller_path: NodePath
@export var chase_camera_path: NodePath
@export var fpv_camera_path: NodePath
@export var observer_camera_path: NodePath
@export var arena_path: NodePath

var drone: DroneBody
var controller: Node
var chase_camera
var fpv_camera: Camera3D
var observer_camera: Camera3D
var input_blocked := false
var score := [0, 0]
var elapsed := 0.0
var status := "已锁定 · 请使用已映射的遥控器解锁开关"
var _score_label: Label
var _time_label: Label
var _status_label: Label
var _device_label: Label
var _flight_label: Label
var _toast: Label
var _pause_panel: PanelContainer
var _stick_monitor: Control
var _reticle: Label
var _fps_label: Label
var _los_back := Vector3(1.0, 0.0, 1.0).normalized()


func _ready() -> void:
	drone = get_node(drone_path) as DroneBody
	controller = get_node(controller_path)
	chase_camera = get_node(chase_camera_path) as Camera3D
	fpv_camera = get_node(fpv_camera_path) as Camera3D
	observer_camera = get_node(observer_camera_path) as Camera3D
	get_node(arena_path).goal_scored.connect(_on_goal_scored)
	_build_hud()
	reset_drone()
	if not InputProfile.has_saved_profile() or InputProfile.consume_calibration_request():
		call_deferred("open_calibration")


func _unhandled_input(event: InputEvent) -> void:
	if not input_blocked and InputProfile.camera_mode != "FPV":
		if event.is_action_pressed("ui_left"): chase_camera.adjust_view(-12.0, 0.0)
		elif event.is_action_pressed("ui_right"): chase_camera.adjust_view(12.0, 0.0)
		elif event.is_action_pressed("ui_up"): chase_camera.adjust_view(0.0, -0.6)
		elif event.is_action_pressed("ui_down"): chase_camera.adjust_view(0.0, 0.6)
	if event.is_action_pressed("ui_cancel"):
		if get_node("../CalibrationUI").visible:
			get_node("../CalibrationUI").close_ui()
		else:
			toggle_pause()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not input_blocked:
		elapsed += delta
	_time_label.text = _format_time(elapsed)
	_device_label.text = InputProfile.device_name()
	_status_label.text = status
	if is_instance_valid(drone) and _flight_label:
		var telemetry: Dictionary = drone.get_telemetry()
		var telemetry_items: Array[String] = []
		if bool(InputProfile.osd.altitude): telemetry_items.append("高度 %.1f m" % float(telemetry.get("altitude", 0.0)))
		if bool(InputProfile.osd.speed): telemetry_items.append("速度 %.1f m/s" % float(telemetry.get("ground_speed", 0.0)))
		if bool(InputProfile.osd.flight_mode): telemetry_items.append(controller.rate_summary())
		if bool(InputProfile.osd.camera_mode): telemetry_items.append("视角 " + InputProfile.camera_mode)
		if bool(InputProfile.osd.camera_angle): telemetry_items.append("镜头 %.0f°" % float(InputProfile.camera.angle))
		_flight_label.text = "  ·  ".join(telemetry_items.slice(0, 2))
		if telemetry_items.size() > 2: _flight_label.text += "\n" + "  ·  ".join(telemetry_items.slice(2))
	if InputProfile.camera_mode == "LOS": _update_los_camera(delta)
	if _fps_label: _fps_label.text = "FPS\n%d" % Engine.get_frames_per_second()
	_apply_osd_visibility()


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)

	var top_margin := MarginContainer.new()
	top_margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_margin.offset_left = 24
	top_margin.offset_top = 20
	top_margin.offset_right = -24
	top_margin.offset_bottom = 112
	top_margin.add_theme_constant_override("margin_left", 0)
	top_margin.add_theme_constant_override("margin_right", 0)
	layer.add_child(top_margin)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 14)
	top_margin.add_child(top_row)

	var score_card := PanelContainer.new()
	score_card.custom_minimum_size = Vector2(340, 82)
	score_card.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.024, 0.032, 0.88), Color(0.95, 0.69, 0.08, 0.42), 16))
	top_row.add_child(score_card)
	var score_margin := MarginContainer.new()
	score_margin.add_theme_constant_override("margin_left", 22)
	score_margin.add_theme_constant_override("margin_right", 22)
	score_margin.add_theme_constant_override("margin_top", 12)
	score_margin.add_theme_constant_override("margin_bottom", 12)
	score_card.add_child(score_margin)
	var score_column := VBoxContainer.new()
	score_margin.add_child(score_column)
	var score_caption := Label.new()
	score_caption.text = "开放训练场  ·  SCORE"
	score_caption.add_theme_font_size_override("font_size", 13)
	score_caption.add_theme_color_override("font_color", Color("d7a934"))
	score_column.add_child(score_caption)
	_score_label = Label.new()
	_score_label.add_theme_font_size_override("font_size", 27)
	_score_label.add_theme_color_override("font_color", Color("f5fbff"))
	_score_label.text = "蓝方  0   :   0  黄方"
	score_column.add_child(_score_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)

	var flight_card := PanelContainer.new()
	flight_card.custom_minimum_size = Vector2(420, 82)
	flight_card.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.024, 0.032, 0.88), Color(0.95, 0.69, 0.08, 0.42), 16))
	top_row.add_child(flight_card)
	var flight_margin := MarginContainer.new()
	flight_margin.add_theme_constant_override("margin_left", 20)
	flight_margin.add_theme_constant_override("margin_right", 16)
	flight_margin.add_theme_constant_override("margin_top", 10)
	flight_margin.add_theme_constant_override("margin_bottom", 10)
	flight_card.add_child(flight_margin)
	var flight_column := VBoxContainer.new()
	flight_margin.add_child(flight_column)
	var flight_top := HBoxContainer.new()
	flight_top.add_theme_constant_override("separation", 18)
	flight_column.add_child(flight_top)
	_time_label = Label.new()
	_time_label.add_theme_font_size_override("font_size", 25)
	_time_label.add_theme_color_override("font_color", Color("ffd56a"))
	flight_top.add_child(_time_label)
	_device_label = Label.new()
	_device_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_device_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_device_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	flight_top.add_child(_device_label)
	_flight_label = Label.new()
	_flight_label.add_theme_font_size_override("font_size", 15)
	_flight_label.add_theme_color_override("font_color", Color("b9d9e5"))
	flight_column.add_child(_flight_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	top_row.add_child(actions)
	var calibrate := Button.new()
	calibrate.text = "校准"
	calibrate.custom_minimum_size = Vector2(78, 82)
	calibrate.add_theme_stylebox_override("normal", _button_style(Color(0.04, 0.12, 0.16, 0.9)))
	calibrate.add_theme_stylebox_override("hover", _button_style(Color(0.08, 0.28, 0.35, 0.96)))
	calibrate.pressed.connect(open_calibration)
	actions.add_child(calibrate)
	var menu := Button.new()
	menu.text = "菜单"
	menu.custom_minimum_size = Vector2(78, 82)
	menu.add_theme_stylebox_override("normal", _button_style(Color(0.04, 0.12, 0.16, 0.9)))
	menu.add_theme_stylebox_override("hover", _button_style(Color(0.08, 0.28, 0.35, 0.96)))
	menu.pressed.connect(toggle_pause)
	actions.add_child(menu)

	var status_card := PanelContainer.new()
	status_card.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	status_card.offset_left = 24
	status_card.offset_top = -72
	status_card.offset_right = -24
	status_card.offset_bottom = -20
	status_card.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.024, 0.032, 0.84), Color(0.95, 0.69, 0.08, 0.30), 14))
	layer.add_child(status_card)
	var status_margin := MarginContainer.new()
	status_margin.add_theme_constant_override("margin_left", 20)
	status_margin.add_theme_constant_override("margin_right", 20)
	status_margin.add_theme_constant_override("margin_top", 10)
	status_margin.add_theme_constant_override("margin_bottom", 10)
	status_card.add_child(status_margin)
	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 18)
	status_margin.add_child(bottom_row)
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 17)
	_status_label.add_theme_color_override("font_color", Color("ffe08a"))
	bottom_row.add_child(_status_label)
	var help := Label.new()
	help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	help.add_theme_color_override("font_color", Color("a9bdc5"))
	help.text = "遥控器开关解锁   R 复位   C 切换视角   方向键调视角   K 设置"
	bottom_row.add_child(help)

	_reticle = Label.new()
	_reticle.text = "○"
	_reticle.set_anchors_preset(Control.PRESET_CENTER)
	_reticle.position = Vector2(-15, -22)
	_reticle.size = Vector2(30, 44)
	_reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reticle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_reticle.add_theme_font_size_override("font_size", 30)
	_reticle.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0, 0.82))
	layer.add_child(_reticle)
	_fps_label = Label.new()
	_fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fps_label.position = Vector2(-108, 128)
	_fps_label.size = Vector2(84, 58)
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps_label.add_theme_font_size_override("font_size", 19)
	_fps_label.add_theme_color_override("font_color", Color("5dff53"))
	layer.add_child(_fps_label)

	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.position = Vector2(-240, 128)
	_toast.size = Vector2(480, 64)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 30)
	_toast.add_theme_color_override("font_color", Color("ffe287"))
	_toast.visible = false
	layer.add_child(_toast)
	_build_pause_menu(layer)
	_stick_monitor = preload("res://demo/scripts/controller_monitor.gd").new()
	_stick_monitor.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_stick_monitor.position = Vector2(-190, -165)
	_stick_monitor.size = Vector2(380, 145)
	_stick_monitor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_stick_monitor)


func _panel_style(color: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.28)
	style.shadow_size = 8
	return style


func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(14)
	return style


func _build_pause_menu(layer: CanvasLayer) -> void:
	var shade := ColorRect.new()
	shade.name = "PauseShade"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.025, 0.035, 0.76)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.visible = false
	layer.add_child(shade)
	_pause_panel = PanelContainer.new()
	_pause_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.028, 0.034, 0.98), Color(0.95, 0.69, 0.08, 0.55), 18))
	_pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	_pause_panel.position = Vector2(-230, -280)
	_pause_panel.size = Vector2(460, 560)
	shade.add_child(_pause_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 38)
	margin.add_theme_constant_override("margin_right", 38)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_bottom", 34)
	_pause_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 15)
	margin.add_child(column)
	var title := Label.new()
	title.text = "训练已暂停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	column.add_child(title)
	column.add_child(_menu_button("继续训练", toggle_pause))
	column.add_child(_menu_button("校准遥控器", open_calibration))
	column.add_child(_menu_button("重新开始本局", restart_match))
	column.add_child(_menu_button("返回主页面", return_to_main_menu))
	column.add_child(_menu_button("退出游戏", quit_game))
	var tip := Label.new()
	tip.text = "也可以再次按 Esc 继续"
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_color_override("font_color", Color("7fa3ad"))
	column.add_child(tip)


func _menu_button(text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 55
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_stylebox_override("normal", _button_style(Color("25282d")))
	button.add_theme_stylebox_override("hover", _button_style(Color("b98500")))
	button.add_theme_stylebox_override("pressed", _button_style(Color("8f6800")))
	button.pressed.connect(callback)
	return button


func toggle_pause() -> void:
	var shade := _pause_panel.get_parent()
	shade.visible = not shade.visible
	set_input_blocked(shade.visible)
	set_status("训练已暂停" if shade.visible else "继续训练 · 请使用遥控器解锁开关")


func restart_match() -> void:
	score = [0, 0]
	elapsed = 0.0
	_score_label.text = "蓝方  0  :  0  黄方"
	reset_drone()
	if _pause_panel.get_parent().visible:
		toggle_pause()


func return_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://demo/main_menu.tscn")


func quit_game() -> void:
	get_tree().quit()


func _on_goal_scored(team: int) -> void:
	score[team] += 1
	_score_label.text = "蓝方  %d  :  %d  黄方" % [score[0], score[1]]
	_show_toast("蓝方得分！" if team == 0 else "黄方得分！")
	controller.force_disarm()
	await get_tree().create_timer(1.0).timeout
	reset_drone()


func _show_toast(message: String) -> void:
	_toast.text = message
	_toast.visible = true
	await get_tree().create_timer(1.4).timeout
	_toast.visible = false


func reset_drone() -> void:
	if not is_instance_valid(drone):
		return
	controller.force_disarm()
	drone.linear_velocity = Vector3.ZERO
	drone.angular_velocity = Vector3.ZERO
	drone.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 1.4, 0))
	set_status("已复位 · 请使用遥控器解锁开关")


func toggle_camera() -> void:
	var modes := ["Chase", "FPV", "LOS"]
	var index := modes.find(InputProfile.camera_mode)
	set_camera_mode(modes[(index + 1) % modes.size()])

func set_camera_mode(mode: String) -> void:
	InputProfile.camera_mode = mode
	InputProfile.save_profile()
	if mode == "FPV":
		fpv_camera.current = true
		set_status("FPV 第一视角")
	elif mode == "LOS":
		observer_camera.current = true
		set_status("LOS 目视跟随视角")
	else:
		chase_camera.current = true
		set_status("第三人称追尾视角")


func open_calibration() -> void:
	if is_instance_valid(_pause_panel):
		_pause_panel.get_parent().visible = false
	var calibration := get_node_or_null("../CalibrationUI")
	if calibration:
		calibration.open()


func set_input_blocked(blocked: bool) -> void:
	input_blocked = blocked
	if blocked:
		controller.force_disarm()


func set_status(message: String) -> void:
	status = message


func _format_time(seconds: float) -> String:
	var whole := int(seconds)
	return "%02d:%02d" % [whole / 60, whole % 60]

func _update_los_camera(delta: float) -> void:
	if not is_instance_valid(drone): return
	var motion: Vector3 = drone.linear_velocity
	motion.y = 0.0
	if motion.length_squared() > 0.5: _los_back = _los_back.lerp(-motion.normalized(), 1.0 - exp(-1.8 * delta)).normalized()
	var distance := float(InputProfile.camera.los_distance)
	var height := float(InputProfile.camera.los_height)
	var desired: Vector3 = drone.global_position + _los_back * distance + Vector3.UP * height
	observer_camera.global_position = observer_camera.global_position.lerp(desired, 1.0 - exp(-7.0 * delta))
	observer_camera.look_at(drone.global_position + Vector3.UP * 0.15, Vector3.UP)

func _apply_osd_visibility() -> void:
	var show_all := bool(InputProfile.osd.visible)
	if _stick_monitor:
		_stick_monitor.visible = show_all and bool(InputProfile.osd.sticks)
		_stick_monitor.scale = Vector2.ONE * float(InputProfile.osd.scale)
	if _reticle: _reticle.visible = show_all and bool(InputProfile.osd.reticle)
	if _fps_label: _fps_label.visible = show_all and bool(InputProfile.osd.fps)
	if _flight_label: _flight_label.visible = show_all and (bool(InputProfile.osd.speed) or bool(InputProfile.osd.altitude) or bool(InputProfile.osd.flight_mode))
