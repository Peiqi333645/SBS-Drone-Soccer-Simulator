extends Node

signal profile_changed
const SAVE_PATH := "user://sbs_controller_profile.json"
const PROFILE_VERSION := 12
const AXES := [&"throttle", &"yaw", &"pitch", &"roll"]
var device_id := 0
var device_guid := ""
var deadzone := 0.04
var expo := 0.0
var calibration_requested := false
var bf_rc_rate := 1.0
var bf_super_rate := 0.70
var bf_rate_expo := 0.20
var bf_yaw_rate := 0.85
var bf_yaw_super_rate := 0.65
var motor_output_limit := 1.0
var airframe_id := "5inch"
var rate_type := "Betaflight"
var flight_mode := "Acro"
var camera_mode := "Chase"
var slow_motion := 1.0
var motor_idle := 0.055
var aux_buttons := {
	"arm": {"type":"none", "index":-1},
	"disarm": {"type":"none", "index":-1},
	"reset": {"type":"none", "index":-1},
	"camera": {"type":"none", "index":-1},
	"flight_mode": {"type":"none", "index":-1},
}
var throttle_mid := 0.50
var throttle_expo := 0.15
var axis_rates := {
	"roll": {"rc": 1.0, "super": 0.70, "expo": 0.20},
	"pitch": {"rc": 1.0, "super": 0.70, "expo": 0.20},
	"yaw": {"rc": 0.85, "super": 0.65, "expo": 0.10},
}
var actual_rates := {
	"roll": {"center": 220.0, "max": 850.0, "expo": 0.0, "ff": 0.0},
	"pitch": {"center": 220.0, "max": 850.0, "expo": 0.0, "ff": 0.0},
	"yaw": {"center": 220.0, "max": 750.0, "expo": 0.0, "ff": 0.0},
}
var level := {"sensitivity": 50.0, "angle_limit": 50.0}
var components := {"led": true, "prop_guards": false}
const AIRFRAMES := {
	"1inch": {"name":"1寸微型穿越机", "mass":0.022, "wheelbase":0.065, "prop_diameter":0.0254, "motor_kv":30000.0, "voltage":4.35, "drag_low":0.006, "drag_high":0.020, "inertia":[0.000008,0.000014,0.000008], "visual_scale":0.082, "camera_angle":20.0, "camera_fov":105.0},
	"2_5inch": {"name":"2.5寸轻量穿越机", "mass":0.125, "wheelbase":0.125, "prop_diameter":0.0635, "motor_kv":6000.0, "voltage":13.05, "drag_low":0.010, "drag_high":0.030, "inertia":[0.00022,0.00040,0.00022], "visual_scale":0.158, "camera_angle":25.0, "camera_fov":110.0},
	"3inch": {"name":"3寸竞速/足球穿越机", "mass":0.245, "wheelbase":0.160, "prop_diameter":0.0762, "motor_kv":3800.0, "voltage":17.4, "drag_low":0.014, "drag_high":0.038, "inertia":[0.00062,0.00105,0.00062], "visual_scale":0.202, "camera_angle":30.0, "camera_fov":115.0},
	"5inch": {"name":"5寸自由式穿越机", "mass":0.650, "wheelbase":0.220, "prop_diameter":0.1270, "motor_kv":1950.0, "voltage":25.2, "drag_low":0.020, "drag_high":0.050, "inertia":[0.0038,0.0068,0.0038], "visual_scale":0.278, "camera_angle":25.0, "camera_fov":120.0},
}
var physics := {"mass":0.650, "gravity":1.0, "thrust":1.0, "drag_low":0.020, "drag_high":0.050, "turbulence":0.0, "motor_kv":1950.0, "voltage":25.2, "prop_radius":0.0635, "motor_arm":0.110, "inertia":[0.0038,0.0068,0.0038], "visual_scale":0.278}
var camera := {"angle": 25.0, "fov": 120.0, "follow_distance": 5.8, "follow_height": 2.2, "los_distance": 7.5, "los_height": 2.8, "motion_blur": 0.15, "lens_distortion": 0.08}
var graphics := {"quality": 1, "render_scale": 0.85, "vsync": true, "shadows": true, "glow": false, "ssao": false, "anti_aliasing": 1}
var osd := {"visible": true, "scale": 1.0, "sticks": true, "speed": true, "altitude": true, "flight_mode": true, "camera_mode": true, "camera_angle": true, "reticle": true, "fps": true}
var colors := {"body":"20252a", "accent":"d14b38", "prop":"4f555a", "led":"e04b36"}
var mappings := {
	# OpenTX/EdgeTX USB Joystick default order: AETR (Godot indices 0..3).
	"roll": {"axis": 0, "min": -1.0, "center": 0.0, "max": 1.0, "invert": false, "deadzone": 0.04},
	"pitch": {"axis": 1, "min": -1.0, "center": 0.0, "max": 1.0, "invert": false, "deadzone": 0.04},
	"throttle": {"axis": 2, "min": -1.0, "center": 0.0, "max": 1.0, "invert": false, "deadzone": 0.02},
	"yaw": {"axis": 3, "min": -1.0, "center": 0.0, "max": 1.0, "invert": false, "deadzone": 0.04},
}

func _ready() -> void:
	load_profile()
	select_available_device()
func select_available_device() -> int:
	var devices := connected_devices()
	if devices.is_empty(): return -1
	if not device_guid.is_empty():
		for candidate in devices:
			if Input.get_joy_guid(candidate) == device_guid:
				device_id = candidate
				return device_id
	if device_id not in devices: device_id = devices[0]
	if not device_guid.is_empty() and Input.get_joy_guid(device_id) != device_guid:
		calibration_requested = true
	device_guid = Input.get_joy_guid(device_id)
	return device_id
func request_calibration() -> void:
	calibration_requested = true
func consume_calibration_request() -> bool:
	var requested: bool = calibration_requested
	calibration_requested = false
	return requested
func has_saved_profile() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
func connected_devices() -> Array[int]:
	return Input.get_connected_joypads()
func device_name() -> String:
	if select_available_device() < 0: return "未检测到 USB 遥控器"
	var detected := Input.get_joy_name(device_id).strip_edges()
	if detected.is_empty() or detected == "Unknown":
		var guid := Input.get_joy_guid(device_id)
		detected = "USB 遥控器" if guid.is_empty() else "USB 遥控器 · " + guid.left(8)
	return "%d: %s" % [device_id, detected]
func raw_axis(index: int) -> float:
	if device_id not in connected_devices(): return 0.0
	return Input.get_joy_axis(device_id, index)
func value(control: StringName) -> float:
	var map: Dictionary = mappings.get(String(control), {})
	if map.is_empty(): return 0.0
	var raw: float = raw_axis(int(map.axis))
	var minimum: float = minf(float(map.min), float(map.max))
	var maximum: float = maxf(float(map.min), float(map.max))
	var center: float = clampf(float(map.center), minimum + 0.001, maximum - 0.001)
	var normalized: float
	if raw >= center:
		normalized = inverse_lerp(center, maxf(maximum, center + 0.01), raw)
	else:
		normalized = -inverse_lerp(center, minf(minimum, center - 0.01), raw)
	normalized = clamp(normalized, -1.0, 1.0)
	if bool(map.invert): normalized *= -1.0
	var channel_deadzone: float = clampf(float(map.get("deadzone", deadzone)), 0.0, 0.30)
	if absf(normalized) <= channel_deadzone: return 0.0
	var dz: float = (absf(normalized) - channel_deadzone) / maxf(0.01, 1.0 - channel_deadzone)
	return signf(normalized) * dz
func set_mapping(control: StringName, axis: int, minimum: float, center: float, maximum: float, invert: bool) -> void:
	var old: Dictionary = mappings.get(String(control), {})
	mappings[String(control)] = {"axis": axis, "min": minimum, "center": center, "max": maximum, "invert": invert, "deadzone": float(old.get("deadzone", deadzone))}
	save_profile()
	profile_changed.emit()
func save_profile() -> void:
	if device_id in connected_devices(): device_guid = Input.get_joy_guid(device_id)
	var flight := {"airframe_id":airframe_id, "bf_rc_rate": bf_rc_rate, "bf_super_rate": bf_super_rate, "bf_rate_expo": bf_rate_expo, "bf_yaw_rate": bf_yaw_rate, "bf_yaw_super_rate": bf_yaw_super_rate, "motor_output_limit": motor_output_limit, "throttle_mid": throttle_mid, "throttle_expo": throttle_expo, "axis_rates": axis_rates, "actual_rates": actual_rates, "level": level, "components": components, "physics": physics, "camera": camera, "graphics": graphics, "osd": osd, "colors": colors, "rate_type": rate_type, "flight_mode": flight_mode, "camera_mode": camera_mode, "slow_motion": slow_motion, "motor_idle": motor_idle, "aux_buttons": aux_buttons}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"version": PROFILE_VERSION, "device_id": device_id, "device_guid":device_guid, "deadzone": deadzone, "expo": expo, "mappings": mappings, "flight": flight}, "\t"))
func load_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH): return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if parsed is not Dictionary: return
	var profile_version: int = int(parsed.get("version", 1))
	device_id = int(parsed.get("device_id", device_id))
	device_guid = String(parsed.get("device_guid", device_guid))
	deadzone = float(parsed.get("deadzone", deadzone))
	expo = float(parsed.get("expo", expo))
	var loaded = parsed.get("mappings", {})
	if loaded is Dictionary:
		for axis_name in AXES:
			if loaded.has(String(axis_name)): mappings[String(axis_name)] = loaded[String(axis_name)]
	var flight: Dictionary = parsed.get("flight", {})
	airframe_id = String(flight.get("airframe_id", airframe_id))
	if not AIRFRAMES.has(airframe_id): airframe_id = "5inch"
	bf_rc_rate = float(flight.get("bf_rc_rate", bf_rc_rate))
	bf_super_rate = float(flight.get("bf_super_rate", bf_super_rate))
	bf_rate_expo = float(flight.get("bf_rate_expo", bf_rate_expo))
	bf_yaw_rate = float(flight.get("bf_yaw_rate", bf_yaw_rate))
	bf_yaw_super_rate = float(flight.get("bf_yaw_super_rate", bf_yaw_super_rate))
	motor_output_limit = float(flight.get("motor_output_limit", motor_output_limit))
	throttle_mid = float(flight.get("throttle_mid", throttle_mid))
	throttle_expo = float(flight.get("throttle_expo", throttle_expo))
	rate_type = String(flight.get("rate_type", rate_type))
	if rate_type not in ["Actual", "Betaflight"]: rate_type = "Betaflight"
	flight_mode = String(flight.get("flight_mode", flight_mode))
	camera_mode = String(flight.get("camera_mode", camera_mode))
	slow_motion = float(flight.get("slow_motion", slow_motion))
	motor_idle = float(flight.get("motor_idle", motor_idle))
	var loaded_rates = flight.get("axis_rates", {})
	if loaded_rates is Dictionary:
		for axis_name in ["roll", "pitch", "yaw"]:
			if loaded_rates.has(axis_name): axis_rates[axis_name] = loaded_rates[axis_name]
	var loaded_actual = flight.get("actual_rates", {})
	if loaded_actual is Dictionary:
		for axis_name in ["roll", "pitch", "yaw"]:
			if loaded_actual.has(axis_name): actual_rates[axis_name] = loaded_actual[axis_name]
	var loaded_level = flight.get("level", {})
	if loaded_level is Dictionary: level.merge(loaded_level, true)
	var loaded_components = flight.get("components", {})
	if loaded_components is Dictionary: components.merge(loaded_components, true)
	var loaded_aux = flight.get("aux_buttons", {})
	if loaded_aux is Dictionary: aux_buttons.merge(loaded_aux, true)
	var loaded_physics = flight.get("physics", {})
	if loaded_physics is Dictionary: physics.merge(loaded_physics, true)
	var loaded_camera = flight.get("camera", {})
	if loaded_camera is Dictionary: camera.merge(loaded_camera, true)
	var loaded_graphics = flight.get("graphics", {})
	if loaded_graphics is Dictionary: graphics.merge(loaded_graphics, true)
	var loaded_osd = flight.get("osd", {})
	if loaded_osd is Dictionary: osd.merge(loaded_osd, true)
	var loaded_colors = flight.get("colors", {})
	if loaded_colors is Dictionary: colors.merge(loaded_colors, true)
	if profile_version < PROFILE_VERSION:
		# v4 shipped with the four primary channels rotated (TAER instead of AETR).
		# Migrate only that exact broken factory layout; never overwrite a user's calibration.
		if int(mappings["throttle"].axis) == 1 and int(mappings["yaw"].axis) == 0 and int(mappings["pitch"].axis) == 3 and int(mappings["roll"].axis) == 2:
			mappings = {
				"roll":{"axis":0,"min":-1.0,"center":0.0,"max":1.0,"invert":false,"deadzone":0.04},
				"pitch":{"axis":1,"min":-1.0,"center":0.0,"max":1.0,"invert":true,"deadzone":0.04},
				"throttle":{"axis":2,"min":-1.0,"center":0.0,"max":1.0,"invert":true,"deadzone":0.02},
				"yaw":{"axis":3,"min":-1.0,"center":0.0,"max":1.0,"invert":false,"deadzone":0.04}}
		if is_equal_approx(float(physics.get("mass", 0.0)), 1.5) and is_equal_approx(float(physics.get("drag_high", 0.0)), 0.32):
			physics.merge({"mass":0.78,"gravity":1.0,"thrust":1.0,"drag_low":0.025,"drag_high":0.075,"turbulence":0.0,"motor_kv":1950.0,"voltage":16.8}, true)
		if is_equal_approx(motor_output_limit, 0.38): motor_output_limit = 0.62
		if is_equal_approx(throttle_mid, 0.35): throttle_mid = 0.50
		if is_equal_approx(throttle_expo, 0.30): throttle_expo = 0.15
		if profile_version < 6:
			# Correct the two vertical channels from the previous build.
			mappings["pitch"]["invert"] = false
			mappings["throttle"]["invert"] = false
			physics = {"mass":0.42,"gravity":1.0,"thrust":1.0,"drag_low":0.018,"drag_high":0.055,"turbulence":0.0,"motor_kv":2450.0,"voltage":16.8}
			motor_output_limit = 0.72
		if profile_version < 7:
			# Old builds stored fixed gamepad button numbers. Radio switches are
			# usually joystick axes, so force a one-time explicit recognition.
			aux_buttons = {
				"arm":{"type":"none","index":-1}, "disarm":{"type":"none","index":-1},
				"reset":{"type":"none","index":-1}, "camera":{"type":"none","index":-1},
				"flight_mode":{"type":"none","index":-1}}
			physics.merge({"gravity":1.12,"drag_low":0.035,"drag_high":0.10,"motor_kv":1450.0}, true)
			motor_output_limit = 0.68
		if profile_version < 8:
			# Keep a fast motor/ESC response and cap only maximum power. Reducing KV
			# made the whole throttle range sluggish instead of merely limiting it.
			physics.merge({"gravity":1.15,"drag_low":0.032,"drag_high":0.085,"motor_kv":2300.0}, true)
			motor_output_limit = 0.62
			graphics.merge({"quality":1,"render_scale":0.85,"shadows":true,"glow":false,"ssao":false,"anti_aliasing":1}, true)
		if profile_version < 9:
			# Heavier vertical acceleration and fast motors restore FPV momentum.
			# Keep calibrated channel maps intact; only migrate flight defaults.
			physics.merge({"gravity":1.28,"drag_low":0.026,"drag_high":0.070,"motor_kv":2450.0}, true)
			motor_output_limit = 0.72
		if profile_version < 10:
			physics.merge({"gravity":1.42,"drag_low":0.020,"drag_high":0.052,"motor_kv":2700.0}, true)
			motor_output_limit = 0.84
		if profile_version < 11:
			# Preserve the 3.5 ms motor response but separate it from maximum power.
			# The previous 84% limit with 2700 KV caused an unrealistic launch.
			physics.merge({"gravity":1.55,"drag_low":0.018,"drag_high":0.045,"motor_kv":2700.0}, true)
			motor_output_limit = 0.56
			if String(colors.get("body", "")) == "7d5cff":
				colors = {"body":"20252a","accent":"d14b38","prop":"4f555a","led":"e04b36"}
		if profile_version < 12:
			# v11 used a 10-inch effective prop, a 0.79 m frame and artificial
			# 1.55 g. Migrate the physical model to a coherent 5-inch baseline.
			airframe_id = "5inch"
			_apply_airframe_values(airframe_id)
		save_profile()

func airframe() -> Dictionary:
	return AIRFRAMES.get(airframe_id, AIRFRAMES["5inch"]).duplicate(true)

func set_airframe(id: String, save := true) -> void:
	if not AIRFRAMES.has(id): return
	airframe_id = id
	_apply_airframe_values(id)
	if save: save_profile()
	profile_changed.emit()

func _apply_airframe_values(id: String) -> void:
	var frame: Dictionary = AIRFRAMES[id]
	var diameter := float(frame.prop_diameter)
	physics = {
		"mass":float(frame.mass), "gravity":1.0, "thrust":1.0,
		"drag_low":float(frame.drag_low), "drag_high":float(frame.drag_high),
		"turbulence":0.0, "motor_kv":float(frame.motor_kv), "voltage":float(frame.voltage),
		"prop_radius":diameter * 0.5, "motor_arm":float(frame.wheelbase) * 0.5,
		"inertia":frame.inertia.duplicate(), "visual_scale":float(frame.visual_scale)
	}
	camera["angle"] = float(frame.camera_angle)
	camera["fov"] = float(frame.camera_fov)
	motor_output_limit = 1.0

func set_rate_value(axis_name: String, key: String, value: float) -> void:
	axis_rates[axis_name][key] = value
	save_profile()
	profile_changed.emit()
func set_physics_value(key: String, value: float) -> void:
	physics[key] = value
	save_profile()
	profile_changed.emit()
func set_camera_value(key: String, value: float) -> void:
	camera[key] = value
	save_profile()
	profile_changed.emit()

func set_general_value(key: String, value: Variant) -> void:
	set(key, value)
	save_profile()
	profile_changed.emit()
func reset_defaults() -> void:
	if FileAccess.file_exists(SAVE_PATH): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	device_id = 0
	device_guid = ""
	deadzone = 0.04
	rate_type = "Betaflight"
	flight_mode = "Acro"
	camera_mode = "Chase"
	slow_motion = 1.0
	motor_output_limit = 1.0
	airframe_id = "5inch"
	motor_idle = 0.055
	axis_rates = {"roll":{"rc":1.0,"super":0.70,"expo":0.20},"pitch":{"rc":1.0,"super":0.70,"expo":0.20},"yaw":{"rc":0.85,"super":0.65,"expo":0.10}}
	actual_rates = {"roll":{"center":220.0,"max":850.0,"expo":0.0,"ff":0.0},"pitch":{"center":220.0,"max":850.0,"expo":0.0,"ff":0.0},"yaw":{"center":220.0,"max":750.0,"expo":0.0,"ff":0.0}}
	level = {"sensitivity":50.0,"angle_limit":50.0}
	components = {"led":true,"prop_guards":false}
	throttle_mid = 0.50
	throttle_expo = 0.15
	mappings = {"roll":{"axis":0,"min":-1.0,"center":0.0,"max":1.0,"invert":false,"deadzone":0.04},"pitch":{"axis":1,"min":-1.0,"center":0.0,"max":1.0,"invert":false,"deadzone":0.04},"throttle":{"axis":2,"min":-1.0,"center":0.0,"max":1.0,"invert":false,"deadzone":0.02},"yaw":{"axis":3,"min":-1.0,"center":0.0,"max":1.0,"invert":false,"deadzone":0.04}}
	aux_buttons = {"arm":{"type":"none","index":-1},"disarm":{"type":"none","index":-1},"reset":{"type":"none","index":-1},"camera":{"type":"none","index":-1},"flight_mode":{"type":"none","index":-1}}
	_apply_airframe_values(airframe_id)
	camera = {"angle":25.0,"fov":120.0,"follow_distance":5.8,"follow_height":2.2,"los_distance":7.5,"los_height":2.8,"motion_blur":0.15,"lens_distortion":0.08}
	graphics = {"quality":1,"render_scale":0.85,"vsync":true,"shadows":true,"glow":false,"ssao":false,"anti_aliasing":1}
	osd = {"visible":true,"scale":1.0,"sticks":true,"speed":true,"altitude":true,"flight_mode":true,"camera_mode":true,"camera_angle":true,"reticle":true,"fps":true}
	colors = {"body":"20252a","accent":"d14b38","prop":"4f555a","led":"e04b36"}
	save_profile()
	profile_changed.emit()
