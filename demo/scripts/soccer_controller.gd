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
var altitude_target := 1.5
var last_flight_mode := ""
var aux_previous := {}
func _ready() -> void:
	drone = get_node(drone_path) as DroneBody
	game = get_node(game_path)
	InputProfile.profile_changed.connect(apply_profile)
	apply_profile()
	Engine.time_scale = InputProfile.slow_motion
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("drone_arm"): arm()
	if Input.is_action_just_pressed("drone_disarm"): disarm()
	if Input.is_action_just_pressed("soccer_reset"): game.reset_drone()
	if Input.is_action_just_pressed("soccer_camera"): game.toggle_camera()
	if Input.is_action_just_pressed("soccer_calibrate"): game.open_calibration()
	if _aux_pressed("reset"): game.reset_drone()
	if _aux_pressed("camera"): game.toggle_camera()
	if _aux_pressed("slow_motion"):
		InputProfile.slow_motion = 0.35 if InputProfile.slow_motion > 0.5 else 1.0
		Engine.time_scale = InputProfile.slow_motion
	if _aux_pressed("flight_mode"):
		var modes := ["Acro", "Angle", "Altitude"]
		InputProfile.flight_mode = modes[(modes.find(InputProfile.flight_mode) + 1) % modes.size()]
		InputProfile.save_profile()
	if not armed or game.input_blocked: return
	var throttle: float = clampf((InputProfile.value(&"throttle") + 1.0) * 0.5, 0.0, 1.0)
	var response: float = 1.0 - exp(-lerpf(4.0, 16.0, 1.0 - throttle_smoothing) * delta)
	throttle_smoothed = lerpf(throttle_smoothed, _throttle_curve(throttle), response)
	# Armed motors keep a small Betaflight-style idle; this prevents dead-prop instability.
	throttle_smoothed = maxf(throttle_smoothed, InputProfile.motor_idle * InputProfile.motor_output_limit)
	var input_response: float = 1.0 - exp(-28.0 * delta)
	roll_filtered = lerpf(roll_filtered, InputProfile.value(&"roll"), input_response)
	pitch_filtered = lerpf(pitch_filtered, InputProfile.value(&"pitch"), input_response)
	yaw_filtered = lerpf(yaw_filtered, InputProfile.value(&"yaw"), input_response)
	if not is_finite(roll_filtered) or not is_finite(pitch_filtered) or not is_finite(yaw_filtered):
		game.set_status("输入异常，已自动锁定")
		disarm()
		return
	var roll_rate: float = _command_rate("roll", roll_filtered)
	var pitch_rate: float = _command_rate("pitch", pitch_filtered)
	var yaw_rate: float = _command_rate("yaw", yaw_filtered)
	var mode: String = InputProfile.flight_mode
	if mode != last_flight_mode:
		last_flight_mode = mode
		altitude_target = float(drone.get_telemetry().get("altitude", drone.global_position.y))
	if mode == "Acro":
		drone.set_rate_setpoint(roll_rate, pitch_rate, yaw_rate, throttle_smoothed)
	else:
		var angle_limit: float = deg_to_rad(float(InputProfile.level.angle_limit))
		var thrust: float = throttle_smoothed
		if mode == "Altitude":
			var telemetry: Dictionary = drone.get_telemetry()
			var vertical_speed: float = float(telemetry.get("vertical_speed", 0.0))
			altitude_target += (throttle - 0.5) * 2.5 * delta
			var altitude_error: float = altitude_target - float(telemetry.get("altitude", 0.0))
			thrust = clampf(_throttle_curve(0.5) + altitude_error * 0.055 - vertical_speed * 0.035, 0.0, InputProfile.motor_output_limit)
		drone.set_attitude_setpoint(roll_filtered * angle_limit, pitch_filtered * angle_limit, yaw_rate, thrust)
	if drone.global_position.y < -2.0 or drone.global_position.y > 60.0: game.reset_drone()
func _command_rate(axis_name: String, stick: float) -> float:
	if InputProfile.rate_type == "Actual":
		var values: Dictionary = InputProfile.actual_rates[axis_name]
		var center: float = float(values.center)
		var maximum: float = float(values.max)
		var expo_value: float = float(values.expo)
		var shaped: float = stick * (1.0 - expo_value) + stick * stick * stick * expo_value
		var rate_deg: float = center * shaped + (maximum - center) * pow(absf(shaped), 3.0) * signf(shaped)
		return deg_to_rad(rate_deg)
	var values: Dictionary = InputProfile.axis_rates[axis_name]
	var rc: float = float(values.rc)
	var super_value: float = float(values.super)
	var expo_value: float = float(values.expo)
	if InputProfile.rate_type == "Raceflight":
		super_value = clampf(super_value * 1.08, 0.0, 0.95)
	elif InputProfile.rate_type == "KISS":
		rc *= 0.92
		expo_value = clampf(expo_value + 0.08, 0.0, 1.0)
	return _bf_rate(stick, rc, super_value, expo_value)

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
	drone.motor_kv = float(InputProfile.physics.motor_kv)
	drone.max_voltage = float(InputProfile.physics.voltage)
	Engine.time_scale = InputProfile.slow_motion
	game.set_camera_mode(InputProfile.camera_mode)
	var quad := get_node_or_null(drone_path)
	if quad:
		for child in quad.get_children():
			if String(child.name).begins_with("FrontLight") or String(child.name) == "RearLight":
				child.visible = bool(InputProfile.components.get("led", true))
			elif String(child.name).begins_with("PropGuard"):
				child.visible = bool(InputProfile.components.get("prop_guards", false))
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
	altitude_target = float(drone.get_telemetry().get("altitude", drone.global_position.y))
	last_flight_mode = InputProfile.flight_mode
	drone.sleeping = false
	drone.arm()
	armed = true
	throttle_smoothed = 0.0
	game.set_status("已解锁 · %s / %s Rate" % [InputProfile.flight_mode, InputProfile.rate_type])
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
func _aux_pressed(action: String) -> bool:
	var button: int = int(InputProfile.aux_buttons.get(action, -1))
	if button < 0 or InputProfile.device_id not in InputProfile.connected_devices(): return false
	var down: bool = Input.is_joy_button_pressed(InputProfile.device_id, button)
	var previous: bool = bool(aux_previous.get(action, false))
	aux_previous[action] = down
	return down and not previous

func rate_summary() -> String:
	var r: Dictionary = InputProfile.axis_rates["roll"]
	return "%s · %s   R %.2f/%.2f/%.2f   输出 %.0f%%" % [InputProfile.flight_mode, InputProfile.rate_type, float(r.rc), float(r.super), float(r.expo), InputProfile.motor_output_limit * 100.0]
