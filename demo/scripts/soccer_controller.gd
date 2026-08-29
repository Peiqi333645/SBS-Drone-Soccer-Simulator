extends Node

@export var drone_path: NodePath
@export var game_path: NodePath
@export_range(10.0, 45.0, 1.0) var max_angle_deg := 28.0
@export_range(30.0, 240.0, 1.0) var max_yaw_rate_deg := 115.0
@export_range(0.0, 1.0, 0.01) var throttle_smoothing := 0.18

var drone: DroneBody
var game: Node
var armed := false
var throttle_smoothed := 0.0


func _ready() -> void:
	drone = get_node(drone_path) as DroneBody
	game = get_node(game_path)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("drone_arm"):
		arm()
	if Input.is_action_just_pressed("drone_disarm"):
		disarm()
	if Input.is_action_just_pressed("soccer_reset"):
		game.reset_drone()
	if Input.is_action_just_pressed("soccer_camera"):
		game.toggle_camera()
	if Input.is_action_just_pressed("soccer_calibrate"):
		game.open_calibration()
	if not armed or game.input_blocked:
		return

	var throttle: float = clampf((InputProfile.value(&"throttle") + 1.0) * 0.5, 0.0, 1.0)
	var yaw := InputProfile.value(&"yaw")
	var pitch := InputProfile.value(&"pitch")
	var roll := InputProfile.value(&"roll")
	var response := 1.0 - exp(-lerp(5.0, 18.0, 1.0 - throttle_smoothing) * delta)
	throttle_smoothed = lerp(throttle_smoothed, throttle, response)
	drone.set_attitude_setpoint(
		deg_to_rad(roll * max_angle_deg),
		deg_to_rad(pitch * max_angle_deg),
		deg_to_rad(yaw * max_yaw_rate_deg),
		throttle_smoothed
	)


func arm() -> void:
	if armed or game.input_blocked:
		return
	drone.arm()
	armed = true
	game.set_status("已解锁 · 自稳训练模式")


func disarm() -> void:
	if not armed:
		return
	drone.disarm()
	armed = false
	throttle_smoothed = 0.0
	game.set_status("已锁定")


func force_disarm() -> void:
	disarm()
