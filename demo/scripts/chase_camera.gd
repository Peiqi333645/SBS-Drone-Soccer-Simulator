## Stable third-person camera for open-field drone training.
extends Camera3D

@export var target: Node3D
@export var target_path: NodePath
@export_range(3.0, 20.0, 0.5) var follow_distance: float = 9.0
@export_range(1.5, 12.0, 0.5) var follow_height: float = 4.0
@export_range(0.5, 20.0, 0.5) var follow_speed: float = 7.0
@export_range(0.5, 15.0, 0.5) var heading_speed: float = 4.0
@export var look_height: float = 0.35
@export var snap_distance: float = 22.0

var _backward := Vector3.BACK


func _ready() -> void:
	if target == null and not target_path.is_empty():
		target = get_node_or_null(target_path)
	current = true
	if target:
		_backward = _flat_backward()
		_snap_to_target()


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var wanted_back := _flat_backward()
	var heading_t := 1.0 - exp(-heading_speed * delta)
	_backward = _backward.lerp(wanted_back, heading_t).normalized()
	var desired := target.global_position + Vector3.UP * follow_height + _backward * follow_distance
	if global_position.distance_to(desired) > snap_distance:
		global_position = desired
	else:
		var follow_t := 1.0 - exp(-follow_speed * delta)
		global_position = global_position.lerp(desired, follow_t)
	look_at(target.global_position + Vector3.UP * look_height, Vector3.UP)


func _flat_backward() -> Vector3:
	var back := target.global_basis.z
	back.y = 0.0
	if back.length_squared() < 0.001:
		return _backward
	return back.normalized()


func _snap_to_target() -> void:
	global_position = target.global_position + Vector3.UP * follow_height + _backward * follow_distance
	look_at(target.global_position + Vector3.UP * look_height, Vector3.UP)
