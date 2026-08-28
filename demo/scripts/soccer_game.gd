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


func _ready() -> void:
	drone = get_node(drone_path) as DroneBody
	controller = get_node(controller_path)
	chase_camera = get_node(chase_camera_path) as Camera3D
	fpv_camera = get_node(fpv_camera_path) as Camera3D
	get_node(arena_path).goal_scored.connect(_on_goal_scored)
	_build_hud()
	reset_drone()
	if not InputProfile.has_saved_profile():
		call_deferred("open_calibration")


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
	row.add_theme_constant_override("separation", 28)
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
	_device_label.custom_minimum_size.x = 260
	_device_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_device_label)

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
	help.text = "Enter 解锁  ·  Backspace 锁定  ·  R 复位  ·  C 视角  ·  K 校准"
	bottom_row.add_child(help)

	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.position = Vector2(-220, 118)
	_toast.size = Vector2(440, 60)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 30)
	_toast.visible = false
	layer.add_child(_toast)


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
