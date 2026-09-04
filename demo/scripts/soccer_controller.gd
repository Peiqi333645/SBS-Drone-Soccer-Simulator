extends Node
@export var drone_path: NodePath
@export var game_path: NodePath
@export_range(0.0, 1.0, 0.01) var throttle_smoothing := 0.30
var drone: DroneBody
var game: Node
var armed := false
var throttle_smoothed := 0.0
var roll_filtered := 0.0
var pitch_filtered := 0.0
var yaw_filtered := 0.0
func _ready() -> void:
	drone = get_node(drone_path) as DroneBody
	game = get_node(game_path)
	InputProfile.profile_changed.connect(apply_profile)
	apply_profile()
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("drone_arm"): arm()
	if Input.is_action_just_pressed("drone_disarm"): disarm()
	if Input.is_action_just_pressed("soccer_reset"): game.reset_drone()
	if Input.is_action_just_pressed("soccer_camera"): game.toggle_camera()
	if Input.is_action_just_pressed("soccer_calibrate"): game.open_calibration()
	if not armed or game.input_blocked: return
	var throttle: float = clampf((InputProfile.value(&"throttle") + 1.0) * 0.5, 0.0, 1.0)
	var response: float = 1.0 - exp(-lerpf(4.0, 16.0, 1.0 - throttle_smoothing) * delta)
	throttle_smoothed = lerpf(throttle_smoothed, _throttle_curve(throttle), response)
	var input_response: float = 1.0 - exp(-28.0 * delta)
	roll_filtered = lerpf(roll_filtered, InputProfile.value(&"roll"), input_response)
	pitch_filtered = lerpf(pitch_filtered, InputProfile.value(&"pitch"), input_response)
	yaw_filtered = lerpf(yaw_filtered, InputProfile.value(&"yaw"), input_response)
	if not is_finite(roll_filtered) or not is_finite(pitch_filtered) or not is_finite(yaw_filtered):
		game.set_status("输入异常，已自动锁定")
		disarm()
		return
	var roll_values: Dictionary = InputProfile.axis_rates["roll"]
	var pitch_values: Dictionary = InputProfile.axis_rates["pitch"]
	var yaw_values: Dictionary = InputProfile.axis_rates["yaw"]
	var roll_rate: float = _bf_rate(roll_filtered, float(roll_values.rc), float(roll_values.super), float(roll_values.expo))
	var pitch_rate: float = _bf_rate(pitch_filtered, float(pitch_values.rc), float(pitch_values.super), float(pitch_values.expo))
	var yaw_rate: float = _bf_rate(yaw_filtered, float(yaw_values.rc), float(yaw_values.super), float(yaw_values.expo))
	drone.set_rate_setpoint(roll_rate, pitch_rate, yaw_rate, throttle_smoothed)
	if drone.global_position.y < -2.0 or drone.global_position.y > 60.0: game.reset_drone()
func _bf_rate(stick: float, rc_rate: float, super_rate: float, rate_expo: float) -> float:
	var x: float = clampf(stick, -1.0, 1.0)
	var shaped: float = x * (1.0 - rate_expo) + x * x * x * rate_expo
	var rc: float = rc_rate
	if rc > 2.0: rc += 14.54 * (rc - 2.0)
	var degrees_per_second: float = 200.0 * rc * shaped
	degrees_per_second /= maxf(0.05, 1.0 - absf(shaped) * super_rate)
	return deg_to_rad(degrees_per_second)
func _throttle_curve(value: float) -> float:
	var t: float = clampf(value, 0.0, 1.0)
	var mid: float = clampf(InputProfile.throttle_mid, 0.1, 0.9)
	var shaped: float
	if t < mid:
		shaped = mid * pow(t / mid, 1.0 + InputProfile.throttle_expo)
	else:
		shaped = mid + (1.0 - mid) * (1.0 - pow((1.0 - t) / (1.0 - mid), 1.0 + InputProfile.throttle_expo))
	return shaped * InputProfile.motor_output_limit
func apply_profile() -> void:
	if not is_instance_valid(drone): return
	drone.mass = float(InputProfile.physics.mass)
	drone.gravity_multiplier = float(InputProfile.physics.gravity)
	drone.thrust_multiplier = float(InputProfile.physics.thrust)
	drone.drag_linear = float(InputProfile.physics.drag_low)
	drone.drag_quadratic = float(InputProfile.physics.drag_high)
	drone.turbulence_intensity = float(InputProfile.physics.turbulence)
	var fpv := game.get_node_or_null("../DroneBody/FPVCamera") as Camera3D
	var chase := game.get_node_or_null("../ChaseCamera") as Camera3D
	if fpv:
		fpv.rotation_degrees.x = float(InputProfile.camera.angle)
		fpv.fov = float(InputProfile.camera.fov)
	if chase:
		chase.follow_distance = float(InputProfile.camera.follow_distance)
		chase.follow_height = float(InputProfile.camera.follow_height)

func arm() -> void:
	if armed or game.input_blocked: return
	var throttle: float = (InputProfile.value(&"throttle") + 1.0) * 0.5
	var roll_input: float = InputProfile.value(&"roll")
	var pitch_input: float = InputProfile.value(&"pitch")
	var yaw_input: float = InputProfile.value(&"yaw")
	if throttle > 0.08:
		game.set_status("无法解锁：请先把油门杆拉到最低")
		return
	if absf(roll_input) > 0.12 or absf(pitch_input) > 0.12 or absf(yaw_input) > 0.12:
		game.set_status("无法解锁：摇杆未居中，请重新校准 R/P/Y")
		return
	roll_filtered = 0.0
	pitch_filtered = 0.0
	yaw_filtered = 0.0
	drone.sleeping = false
	drone.arm()
	armed = true
	throttle_smoothed = 0.0
	game.set_status("已解锁 · Acro / BF Rate")
func disarm() -> void:
	if not armed: return
	drone.disarm()
	armed = false
	throttle_smoothed = 0.0
	roll_filtered = 0.0
	pitch_filtered = 0.0
	yaw_filtered = 0.0
	game.set_status("已锁定")
func force_disarm() -> void:
	disarm()
func rate_summary() -> String:
	var r: Dictionary = InputProfile.axis_rates["roll"]
	return "BF R %.2f / %.2f / %.2f   输出 %.0f%%" % [float(r.rc), float(r.super), float(r.expo), InputProfile.motor_output_limit * 100.0]
