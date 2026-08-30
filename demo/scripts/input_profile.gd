extends Node

signal profile_changed

const SAVE_PATH := "user://sbs_controller_profile.json"
const AXES := [&"throttle", &"yaw", &"pitch", &"roll"]

var device_id := 0
var deadzone := 0.04
var expo := 0.28
var calibration_requested := false
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
	var requested := calibration_requested
	calibration_requested = false
	return requested


func has_saved_profile() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func connected_devices() -> Array[int]:
	return Input.get_connected_joypads()


func device_name() -> String:
	return Input.get_joy_name(device_id) if device_id in connected_devices() else "未检测到 USB 遥控器"


func raw_axis(index: int) -> float:
	if device_id not in connected_devices():
		return 0.0
	return Input.get_joy_axis(device_id, index)


func value(control: StringName) -> float:
	var map: Dictionary = mappings.get(String(control), {})
	if map.is_empty():
		return 0.0
	var raw := raw_axis(int(map.axis))
	var center := float(map.center)
	var normalized: float
	if raw >= center:
		normalized = inverse_lerp(center, max(float(map.max), center + 0.01), raw)
	else:
		normalized = -inverse_lerp(center, min(float(map.min), center - 0.01), raw)
	normalized = clamp(normalized, -1.0, 1.0)
	if bool(map.invert):
		normalized *= -1.0
	if abs(normalized) <= deadzone:
		return 0.0
	var dz: float = (abs(normalized) - deadzone) / (1.0 - deadzone)
	normalized = sign(normalized) * dz
	return lerp(normalized, normalized * normalized * normalized, expo)


func set_mapping(control: StringName, axis: int, minimum: float, center: float, maximum: float, invert: bool) -> void:
	mappings[String(control)] = {"axis": axis, "min": minimum, "center": center, "max": maximum, "invert": invert}
	save_profile()
	profile_changed.emit()


func save_profile() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"device_id": device_id, "deadzone": deadzone, "expo": expo, "mappings": mappings}, "\t"))


func load_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if parsed is not Dictionary:
		return
	device_id = int(parsed.get("device_id", device_id))
	deadzone = float(parsed.get("deadzone", deadzone))
	expo = float(parsed.get("expo", expo))
	var loaded = parsed.get("mappings", {})
	if loaded is Dictionary:
		for axis_name in AXES:
			if loaded.has(String(axis_name)):
				mappings[String(axis_name)] = loaded[String(axis_name)]
