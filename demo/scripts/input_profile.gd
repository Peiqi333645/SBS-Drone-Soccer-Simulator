extends Node

signal profile_changed
const SAVE_PATH := "user://sbs_controller_profile.json"
const AXES := [&"throttle", &"yaw", &"pitch", &"roll"]
var device_id := 0
var deadzone := 0.04
var expo := 0.0
var calibration_requested := false
var bf_rc_rate := 1.0
var bf_super_rate := 0.70
var bf_rate_expo := 0.20
var bf_yaw_rate := 0.85
var bf_yaw_super_rate := 0.65
var motor_output_limit := 0.38
var throttle_mid := 0.35
var throttle_expo := 0.30
var axis_rates := {
	"roll": {"rc": 1.0, "super": 0.70, "expo": 0.20},
	"pitch": {"rc": 1.0, "super": 0.70, "expo": 0.20},
	"yaw": {"rc": 0.85, "super": 0.65, "expo": 0.10},
}
var physics := {"mass": 1.5, "gravity": 1.0, "thrust": 1.0, "drag_low": 0.06, "drag_high": 0.32, "turbulence": 0.0}
var camera := {"angle": 15.0, "fov": 100.0, "follow_distance": 9.0, "follow_height": 4.0}
var mappings := {
	"throttle": {"axis": 1, "min": -1.0, "center": 0.0, "max": 1.0, "invert": true},
	"yaw": {"axis": 0, "min": -1.0, "center": 0.0, "max": 1.0, "invert": false},
	"pitch": {"axis": 3, "min": -1.0, "center": 0.0, "max": 1.0, "invert": true},
	"roll": {"axis": 2, "min": -1.0, "center": 0.0, "max": 1.0, "invert": false},
}

func _ready() -> void:
	load_profile()
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
	return Input.get_joy_name(device_id) if device_id in connected_devices() else "未检测到 USB 遥控器"
func raw_axis(index: int) -> float:
	if device_id not in connected_devices(): return 0.0
	return Input.get_joy_axis(device_id, index)
func value(control: StringName) -> float:
	var map: Dictionary = mappings.get(String(control), {})
	if map.is_empty(): return 0.0
	var raw: float = raw_axis(int(map.axis))
	var center: float = float(map.center)
	var normalized: float
	if raw >= center:
		normalized = inverse_lerp(center, max(float(map.max), center + 0.01), raw)
	else:
		normalized = -inverse_lerp(center, min(float(map.min), center - 0.01), raw)
	normalized = clamp(normalized, -1.0, 1.0)
	if bool(map.invert): normalized *= -1.0
	if abs(normalized) <= deadzone: return 0.0
	var dz: float = (absf(normalized) - deadzone) / (1.0 - deadzone)
	return signf(normalized) * dz
func set_mapping(control: StringName, axis: int, minimum: float, center: float, maximum: float, invert: bool) -> void:
	mappings[String(control)] = {"axis": axis, "min": minimum, "center": center, "max": maximum, "invert": invert}
	save_profile()
	profile_changed.emit()
func save_profile() -> void:
	var flight := {"bf_rc_rate": bf_rc_rate, "bf_super_rate": bf_super_rate, "bf_rate_expo": bf_rate_expo, "bf_yaw_rate": bf_yaw_rate, "bf_yaw_super_rate": bf_yaw_super_rate, "motor_output_limit": motor_output_limit, "throttle_mid": throttle_mid, "throttle_expo": throttle_expo, "axis_rates": axis_rates, "physics": physics, "camera": camera}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"device_id": device_id, "deadzone": deadzone, "expo": expo, "mappings": mappings, "flight": flight}, "\t"))
func load_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH): return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if parsed is not Dictionary: return
	device_id = int(parsed.get("device_id", device_id))
	deadzone = float(parsed.get("deadzone", deadzone))
	expo = float(parsed.get("expo", expo))
	var loaded = parsed.get("mappings", {})
	if loaded is Dictionary:
		for axis_name in AXES:
			if loaded.has(String(axis_name)): mappings[String(axis_name)] = loaded[String(axis_name)]
	var flight: Dictionary = parsed.get("flight", {})
	bf_rc_rate = float(flight.get("bf_rc_rate", bf_rc_rate))
	bf_super_rate = float(flight.get("bf_super_rate", bf_super_rate))
	bf_rate_expo = float(flight.get("bf_rate_expo", bf_rate_expo))
	bf_yaw_rate = float(flight.get("bf_yaw_rate", bf_yaw_rate))
	bf_yaw_super_rate = float(flight.get("bf_yaw_super_rate", bf_yaw_super_rate))
	motor_output_limit = float(flight.get("motor_output_limit", motor_output_limit))
	throttle_mid = float(flight.get("throttle_mid", throttle_mid))
	throttle_expo = float(flight.get("throttle_expo", throttle_expo))
	var loaded_rates = flight.get("axis_rates", {})
	if loaded_rates is Dictionary:
		for axis_name in ["roll", "pitch", "yaw"]:
			if loaded_rates.has(axis_name): axis_rates[axis_name] = loaded_rates[axis_name]
	var loaded_physics = flight.get("physics", {})
	if loaded_physics is Dictionary: physics.merge(loaded_physics, true)
	var loaded_camera = flight.get("camera", {})
	if loaded_camera is Dictionary: camera.merge(loaded_camera, true)

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
