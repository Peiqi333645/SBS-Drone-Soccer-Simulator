extends Node
@export var drone_path: NodePath
@export var game_path: NodePath
@export_range(0.0, 1.0, 0.01) var throttle_smoothing := 0.30
var drone: DroneBody
var game: Node
var armed := false
var throttle_smoothed := 0.0
func _ready() -> void:
	drone = get_node(drone_path) as DroneBody
	game = get_node(game_path)
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("drone_arm"): arm()
	if Input.is_action_just_pressed("drone_disarm"): disarm()
	if Input.is_action_just_pressed("soccer_reset"): game.reset_drone()
	if Input.is_action_just_pressed("soccer_camera"): game.toggle_camera()
	if Input.is_action_just_pressed("soccer_calibrate"): game.open_calibration()
	if not armed or game.input_blocked: return
	var throttle := clampf((InputProfile.value(&"throttle") + 1.0) * 0.5, 0.0, 1.0)
	var response := 1.0 - exp(-lerpf(4.0, 16.0, 1.0 - throttle_smoothing) * delta)
	throttle_smoothed = lerpf(throttle_smoothed, _throttle_curve(throttle), response)
	var roll_rate := _bf_rate(InputProfile.value(&"roll"), InputProfile.bf_rc_rate, InputProfile.bf_super_rate, InputProfile.bf_rate_expo)
	var pitch_rate := _bf_rate(InputProfile.value(&"pitch"), InputProfile.bf_rc_rate, InputProfile.bf_super_rate, InputProfile.bf_rate_expo)
	var yaw_rate := _bf_rate(InputProfile.value(&"yaw"), InputProfile.bf_yaw_rate, InputProfile.bf_yaw_super_rate, 0.0)
	drone.set_rate_setpoint(roll_rate, pitch_rate, yaw_rate, throttle_smoothed)
	if drone.global_position.y < -2.0 or drone.global_position.y > 60.0: game.reset_drone()
func _bf_rate(stick: float, rc_rate: float, super_rate: float, rate_expo: float) -> float:
	var x := clampf(stick, -1.0, 1.0)
	var shaped := x * (1.0 - rate_expo) + x * x * x * rate_expo
	var rc := rc_rate
	if rc > 2.0: rc += 14.54 * (rc - 2.0)
	var degrees_per_second := 200.0 * rc * shaped
	degrees_per_second /= maxf(0.05, 1.0 - absf(shaped) * super_rate)
	return deg_to_rad(degrees_per_second)
func _throttle_curve(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	var mid := clampf(InputProfile.throttle_mid, 0.1, 0.9)
	var shaped: float
	if t < mid:
		shaped = mid * pow(t / mid, 1.0 + InputProfile.throttle_expo)
	else:
		shaped = mid + (1.0 - mid) * (1.0 - pow((1.0 - t) / (1.0 - mid), 1.0 + InputProfile.throttle_expo))
	return shaped * InputProfile.motor_output_limit
func arm() -> void:
	if armed or game.input_blocked: return
	var throttle := (InputProfile.value(&"throttle") + 1.0) * 0.5
	if throttle > 0.08:
		game.set_status("无法解锁：请先把油门杆拉到最低")
		return
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
	game.set_status("已锁定")
func force_disarm() -> void:
	disarm()
func rate_summary() -> String:
	return "BF %.2f / %.2f / %.2f   输出 %.0f%%" % [InputProfile.bf_rc_rate, InputProfile.bf_super_rate, InputProfile.bf_rate_expo, InputProfile.motor_output_limit * 100.0]
