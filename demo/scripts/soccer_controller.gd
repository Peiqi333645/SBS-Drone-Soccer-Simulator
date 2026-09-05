extends Node
@export var drone_path: NodePath
@export var game_path: NodePath
@export_range(0.0, 1.0, 0.01) var throttle_smoothing := 0.08
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
	if Input.is_action_just_pressed("drone_disarm"): disarm()
	if Input.is_action_just_pressed("soccer_reset"): game.reset_drone()
	if Input.is_action_just_pressed("soccer_camera"): game.toggle_camera()
	if Input.is_action_just_pressed("soccer_calibrate"): game.open_calibration()
	if _aux_pressed("reset"): game.reset_drone()
	if _aux_pressed("arm"): arm()
	if _aux_pressed("disarm"): disarm()
	if _aux_pressed("camera"): game.toggle_camera()
	if _aux_pressed("slow_motion"):
		InputProfile.slow_motion = 0.35 if InputProfile.slow_motion > 0.5 else 1.0
		Engine.time_scale = InputProfile.slow_motion
	if _aux_pressed("flight_mode"):
		var modes := ["Acro", "Angle", "Altitude"]
		InputProfile.flight_mode = modes[(modes.find(InputProfile.flight_mode) + 1) % modes.size()]
		InputProfile.save_profile()
	if not armed or game.input_blocked: return
	if InputProfile.device_id not in InputProfile.connected_devices():
		game.set_status("遥控器连接丢失，已自动锁定")
		disarm()
		return
	var throttle: float = clampf((InputProfile.value(&"throttle") + 1.0) * 0.5, 0.0, 1.0)
	# Treat the bottom 2.5% as an explicit motor cut. HID jitter can no longer
	# turn into lift, while the remaining travel retains immediate response.
	if throttle < 0.025: throttle = 0.0
	else: throttle = inverse_lerp(0.025, 1.0, throttle)
	# The radio command is already sampled at the physics rate. Avoid a second
	# software low-pass; motor/prop inertia remains modeled in the native rotor.
	throttle_smoothed = _throttle_curve(throttle)
	# Zero stick is true zero thrust. Idle no longer causes an unexplained lift.
	if throttle <= 0.001:
		throttle_smoothed = 0.0
	else:
		throttle_smoothed = maxf(throttle_smoothed, InputProfile.motor_idle * InputProfile.motor_output_limit)
	# 65 Hz command response keeps the radio connected to the craft without
	# injecting single-frame HID noise. This feels like an FC, not a camera rig.
	roll_filtered = InputProfile.value(&"roll")
	pitch_filtered = InputProfile.value(&"pitch")
	yaw_filtered = InputProfile.value(&"yaw")
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
		if throttle <= 0.001: thrust = 0.0
		drone.set_attitude_setpoint(roll_filtered * angle_limit, pitch_filtered * angle_limit, yaw_rate, thrust)
	if drone.global_position.y < -2.0 or drone.global_position.y > 60.0:
		game.reset_drone()
	elif drone.angular_velocity.length() > 45.0 or drone.linear_velocity.length() > 100.0:
		game.set_status("检测到异常刚体状态，已安全复位")
		game.reset_drone()
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
		for node in quad.get_children():
			var mesh := node as MeshInstance3D
			if mesh == null: continue
			if String(mesh.name).begins_with("FrontLight") or String(mesh.name) == "RearLight":
				mesh.visible = bool(InputProfile.components.get("led", true))
			elif String(mesh.name).begins_with("PropGuard"):
				mesh.visible = bool(InputProfile.components.get("prop_guards", false))
	var fpv := game.get_node_or_null("../DroneBody/FPVCamera") as Camera3D
	var chase := game.get_node_or_null("../ChaseCamera") as Camera3D
	if fpv:
		fpv.rotation_degrees.x = float(InputProfile.camera.angle)
		fpv.fov = float(InputProfile.camera.fov)
	if chase:
		chase.set("follow_distance", float(InputProfile.camera.follow_distance))
		chase.set("follow_height", float(InputProfile.camera.follow_height))
	# Graphics and OSD settings are applied immediately, so every control has a
	# visible runtime effect rather than only changing a saved number.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(InputProfile.graphics.vsync) else DisplayServer.VSYNC_DISABLED)
	get_viewport().scaling_3d_scale = float(InputProfile.graphics.render_scale)
	var msaa_levels: Array[Viewport.MSAA] = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_8X]
	get_viewport().msaa_3d = msaa_levels[clampi(int(InputProfile.graphics.anti_aliasing), 0, 3)]
	var world_environment := game.get_node_or_null("../WorldEnvironment") as WorldEnvironment
	if world_environment and world_environment.environment:
		world_environment.environment.glow_enabled = bool(InputProfile.graphics.glow)
		world_environment.environment.fog_enabled = int(InputProfile.graphics.quality) > 0
		var forward_renderer := String(ProjectSettings.get_setting("rendering/renderer/rendering_method", "gl_compatibility")) != "gl_compatibility"
		world_environment.environment.ssao_enabled = bool(InputProfile.graphics.ssao) and forward_renderer
	var sun := game.get_node_or_null("../Arena/Sun") as DirectionalLight3D
	if sun: sun.shadow_enabled = bool(InputProfile.graphics.shadows)
	var body_color := Color(String(InputProfile.colors.body))
	var accent_color := Color(String(InputProfile.colors.accent))
	var prop_color := Color(String(InputProfile.colors.prop))
	var led_color := Color(String(InputProfile.colors.led))
	for node in drone.get_children():
		var mesh := node as MeshInstance3D
		if mesh == null: continue
		var part_name := String(mesh.name)
		if part_name.contains("Arm") or part_name.contains("Shell") or part_name == "Battery":
			var material := mesh.material_override.duplicate() as StandardMaterial3D
			if material: material.albedo_color = body_color; mesh.material_override = material
		elif part_name.begins_with("Prop"):
			var prop_material := mesh.material_override.duplicate() as StandardMaterial3D
			if prop_material: prop_material.albedo_color = prop_color; mesh.material_override = prop_material
		elif part_name.contains("Lens") or part_name.begins_with("Antenna"):
			var accent_material := mesh.material_override.duplicate() as StandardMaterial3D
			if accent_material: accent_material.albedo_color = accent_color; mesh.material_override = accent_material
		elif part_name.contains("Light"):
			var led_material := mesh.material_override.duplicate() as StandardMaterial3D
			if led_material: led_material.albedo_color = led_color; led_material.emission = led_color; mesh.material_override = led_material

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
	var binding = InputProfile.aux_buttons.get(action, {})
	if not binding is Dictionary or InputProfile.device_id not in InputProfile.connected_devices(): return false
	var map: Dictionary = binding
	var index := int(map.get("index", -1))
	if index < 0: return false
	var down := false
	if String(map.get("type", "none")) == "button":
		down = Input.is_joy_button_pressed(InputProfile.device_id, index)
	elif String(map.get("type", "none")) == "axis":
		var raw := InputProfile.raw_axis(index)
		var threshold := float(map.get("threshold", 0.0))
		down = raw >= threshold if bool(map.get("active_high", true)) else raw <= threshold
	var previous: bool = bool(aux_previous.get(action, false))
	aux_previous[action] = down
	return down and not previous

func rate_summary() -> String:
	var r: Dictionary = InputProfile.axis_rates["roll"]
	var maximum := int(200.0 * float(r.rc) / maxf(0.05, 1.0 - float(r.super)))
	return "%s · %s · 横滚 %d°/s" % [InputProfile.flight_mode, InputProfile.rate_type, maximum]
