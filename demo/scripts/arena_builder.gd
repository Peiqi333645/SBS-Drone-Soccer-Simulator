extends Node3D

signal goal_scored(team: int)

const FIELD_W := 18.0
const FIELD_L := 44.0
const WALL_H := 7.0

var blue := Color("26a7ff")
var yellow := Color("ffd43b")


func _ready() -> void:
	_build_floor()
	_build_boundary()
	_build_lines()
	_build_goal(Vector3(0, 2.6, -FIELD_L * 0.5 + 0.8), 0, blue)
	_build_goal(Vector3(0, 2.6, FIELD_L * 0.5 - 0.8), 1, yellow)
	_build_lights()


func _material(color: Color, emission := Color.BLACK) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.72
	if emission != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = 1.8
	return mat


func _box(
	parent: Node, node_name: String, pos: Vector3, size: Vector3, color: Color, collision := true
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	parent.add_child(body)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _material(color)
	body.add_child(mesh)
	if collision:
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.add_child(shape)
	return body


func _build_floor() -> void:
	_box(self, "Field", Vector3(0, -0.15, 0), Vector3(FIELD_W, 0.3, FIELD_L), Color("254a42"))
	_box(
		self,
		"Runoff",
		Vector3(0, -0.28, 0),
		Vector3(FIELD_W + 8.0, 0.25, FIELD_L + 8.0),
		Color("162a31")
	)


func _build_boundary() -> void:
	var fence := Color(0.08, 0.16, 0.19, 0.38)
	_box(
		self,
		"LeftFence",
		Vector3(-FIELD_W / 2.0, WALL_H / 2.0, 0),
		Vector3(0.15, WALL_H, FIELD_L),
		fence
	)
	_box(
		self,
		"RightFence",
		Vector3(FIELD_W / 2.0, WALL_H / 2.0, 0),
		Vector3(0.15, WALL_H, FIELD_L),
		fence
	)
	_box(
		self,
		"NorthFence",
		Vector3(0, WALL_H / 2.0, -FIELD_L / 2.0),
		Vector3(FIELD_W, WALL_H, 0.15),
		fence
	)
	_box(
		self,
		"SouthFence",
		Vector3(0, WALL_H / 2.0, FIELD_L / 2.0),
		Vector3(FIELD_W, WALL_H, 0.15),
		fence
	)
	_box(self, "Ceiling", Vector3(0, WALL_H, 0), Vector3(FIELD_W, 0.12, FIELD_L), fence)


func _build_lines() -> void:
	var white := Color("e8f3ef")
	_box(self, "CenterLine", Vector3(0, 0.015, 0), Vector3(FIELD_W, 0.025, 0.08), white, false)
	_box(
		self,
		"BlueEndLine",
		Vector3(0, 0.015, -FIELD_L / 2.0 + 3.0),
		Vector3(FIELD_W, 0.025, 0.08),
		blue,
		false
	)
	_box(
		self,
		"YellowEndLine",
		Vector3(0, 0.015, FIELD_L / 2.0 - 3.0),
		Vector3(FIELD_W, 0.025, 0.08),
		yellow,
		false
	)


func _build_goal(pos: Vector3, team: int, color: Color) -> void:
	var root := Node3D.new()
	root.name = "BlueGoal" if team == 0 else "YellowGoal"
	root.position = pos
	add_child(root)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.45
	torus.outer_radius = 1.66
	torus.rings = 32
	torus.ring_segments = 16
	ring.mesh = torus
	ring.rotation_degrees.x = 90.0
	ring.material_override = _material(color, color)
	root.add_child(ring)
	var area := Area3D.new()
	area.set_script(load("res://demo/scripts/goal_trigger.gd"))
	area.set("scoring_team", team)
	root.add_child(area)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.42
	shape.height = 0.65
	collision.shape = shape
	collision.rotation_degrees.x = 90.0
	area.add_child(collision)
	area.connect("scored", Callable(self, "_on_goal"))
	_box(root, "Stand", Vector3(0, -1.7, 0), Vector3(0.25, 1.8, 0.25), color)


func _on_goal(team: int) -> void:
	goal_scored.emit(team)


func _build_lights() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)
	for z in [-14.0, 0.0, 14.0]:
		var light := OmniLight3D.new()
		light.position = Vector3(0, 6.2, z)
		light.omni_range = 20.0
		light.light_energy = 5.0
		add_child(light)
