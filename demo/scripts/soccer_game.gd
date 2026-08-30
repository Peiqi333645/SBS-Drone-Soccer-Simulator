extends Node

@export var drone_path: NodePath
@export var controller_path: NodePath
@export var chase_camera_path: NodePath
@export var fpv_camera_path: NodePath
@export var arena_path: NodePath

var drone: DroneBody
var controller: Node
var chase_camera: Camera3D
var fpv_camera: Camera3D
var input_blocked := false
var score := [0, 0]
var elapsed := 0.0
var status := "已锁定 · 按 Enter 解锁"
var _score_label: Label
var _time_label: Label
var _status_label: Label
var _device_label: Label
var _toast: Label
var _pause_panel: PanelContainer


func _ready() -> void:
	drone = get_node(drone_path) as DroneBody
	controller = get_node(controller_path)
	chase_camera = get_node(chase_camera_path) as Camera3D
	fpv_camera = get_node(fpv_camera_path) as Camera3D
	get_node(arena_path).goal_scored.connect(_on_goal_scored)
	_build_hud()
	reset_drone()
	if not InputProfile.has_saved_profile() or InputProfile.consume_calibration_request():
		call_deferred("open_calibration")


func _unhandled_input(event: InputEvent) -> void:
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


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 24
	top.offset_top = 18
	top.offset_right = -24
	top.offset_bottom = 92
	layer.add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	top.add_child(row)
	_score_label = Label.new()
	_score_label.add_theme_font_size_override("font_size", 28)
	_score_label.text = "蓝方  0  :  0  黄方"
	row.add_child(_score_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_time_label = Label.new()
	_time_label.add_theme_font_size_override("font_size", 24)
	row.add_child(_time_label)
	_device_label = Label.new()
	_device_label.custom_minimum_size.x = 230
	_device_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_device_label)
	var calibrate := Button.new()
	calibrate.text = "校准遥控器"
	calibrate.pressed.connect(open_calibration)
	row.add_child(calibrate)
	var menu := Button.new()
	menu.text = "菜单  Esc"
	menu.pressed.connect(toggle_pause)
	row.add_child(menu)

	var bottom := PanelContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 24
	bottom.offset_top = -92
	bottom.offset_right = -24
	bottom.offset_bottom = -18
	layer.add_child(bottom)
	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 22)
	bottom.add_child(bottom_row)
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 20)
	bottom_row.add_child(_status_label)
	var help := Label.new()
	help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	help.text = "Enter 解锁 · Backspace 锁定 · R 复位 · C 视角 · K 校准 · Esc 菜单"
	bottom_row.add_child(help)

	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.position = Vector2(-220, 118)
	_toast.size = Vector2(440, 60)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 30)
	_toast.visible = false
	layer.add_child(_toast)
	_build_pause_menu(layer)


func _build_pause_menu(layer: CanvasLayer) -> void:
	var shade := ColorRect.new()
	shade.name = "PauseShade"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.025, 0.035, 0.76)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.visible = false
	layer.add_child(shade)
	_pause_panel = PanelContainer.new()
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
	button.pressed.connect(callback)
	return button


func toggle_pause() -> void:
	var shade := _pause_panel.get_parent()
	shade.visible = not shade.visible
	set_input_blocked(shade.visible)
	set_status("训练已暂停" if shade.visible else "继续训练 · 按 Enter 解锁")


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
	set_status("已复位 · 按 Enter 解锁")


func toggle_camera() -> void:
	if chase_camera.current:
		fpv_camera.current = true
		set_status("FPV 第一视角")
	else:
		chase_camera.current = true
		set_status("第三人称跟随视角")


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
