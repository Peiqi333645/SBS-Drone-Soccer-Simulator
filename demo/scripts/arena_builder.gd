extends Node3D

signal goal_scored(team: int)

const FIELD_W := 24.0
const FIELD_L := 52.0
const RUNOFF_W := 64.0
const RUNOFF_L := 92.0

var blue := Color("2a9dff")
var yellow := Color("ffd23f")
var _decor_transforms: Array[Transform3D] = []
var _decor_colors: Array[Color] = []


func _ready() -> void:
	_build_floor()
	_build_lines()
	_build_goal(Vector3(0, 2.8, -FIELD_L * 0.5 + 2.0), 0, blue)
	_build_goal(Vector3(0, 2.8, FIELD_L * 0.5 - 2.0), 1, yellow)
	_build_launch_pad()
	_build_markers()
	_build_stadium()
	_flush_decorations()
	_build_lights()


func _material(color: Color, emission := Color.BLACK, roughness := 0.72) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	if emission != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = 2.2
	return mat


func _box(
	parent: Node, node_name: String, pos: Vector3, size: Vector3, color: Color, collision := true
) -> Node3D:
	if not collision:
		_decor_transforms.append(Transform3D(Basis.IDENTITY.scaled(size), pos))
		_decor_colors.append(color)
		return self
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

func _flush_decorations() -> void:
	if _decor_transforms.is_empty(): return
	var batch := MultiMeshInstance3D.new()
	batch.name = "ArenaDecorationBatch"
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.mesh = BoxMesh.new()
	instances.instance_count = _decor_transforms.size()
	for index in _decor_transforms.size():
		instances.set_instance_transform(index, _decor_transforms[index])
		instances.set_instance_color(index, _decor_colors[index])
	batch.multimesh = instances
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.72
	batch.material_override = material
	add_child(batch)


func _build_floor() -> void:
	# Large open terrain prevents the camera from looking into a black void.
	_box(self, "OpenGround", Vector3(0, -0.38, 0), Vector3(RUNOFF_W, 0.6, RUNOFF_L), Color("5e8546"))
	var field := _box(self, "Field", Vector3(0, -0.06, 0), Vector3(FIELD_W, 0.08, FIELD_L), Color("285b4d"))
	# A single reusable procedural texture adds turf detail without geometry or
	# extra draw calls, keeping the stadium suitable for integrated graphics.
	var field_mesh := field.get_child(0) as MeshInstance3D
	if field_mesh:
		var turf := FastNoiseLite.new()
		turf.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		turf.frequency = 0.075
		turf.fractal_octaves = 3
		var turf_texture := NoiseTexture2D.new()
		turf_texture.width = 512
		turf_texture.height = 512
		turf_texture.seamless = true
		turf_texture.noise = turf
		var turf_material := field_mesh.material_override as StandardMaterial3D
		turf_material.albedo_texture = turf_texture
		turf_material.uv1_scale = Vector3(8.0, 20.0, 1.0)
	# Alternating low-contrast turf bands add speed and altitude cues without textures.
	var strip_count := 26 if int(InputProfile.graphics.get("quality", 1)) >= 2 else 16
	var strip_length := FIELD_L / float(strip_count)
	for i in strip_count:
		var strip_color := Color("34705d") if i % 2 == 0 else Color("2f6756")
		var strip_z := -FIELD_L * 0.5 + strip_length * (float(i) + 0.5)
		_box(self, "TurfStrip_%02d" % i, Vector3(0, -0.014, strip_z), Vector3(FIELD_W - 0.24, 0.012, strip_length - 0.035), strip_color, false)
	# A pale outer apron makes the playable area readable without enclosing walls.
	_box(self, "NorthApron", Vector3(0, -0.015, -FIELD_L * 0.5 - 1.5), Vector3(FIELD_W + 4.0, 0.04, 3.0), Color("c5b991"), false)
	_box(self, "SouthApron", Vector3(0, -0.015, FIELD_L * 0.5 + 1.5), Vector3(FIELD_W + 4.0, 0.04, 3.0), Color("c5b991"), false)
	_box(self, "WestApron", Vector3(-FIELD_W * 0.5 - 1.5, -0.015, 0), Vector3(3.0, 0.04, FIELD_L), Color("c5b991"), false)
	_box(self, "EastApron", Vector3(FIELD_W * 0.5 + 1.5, -0.015, 0), Vector3(3.0, 0.04, FIELD_L), Color("c5b991"), false)


func _build_lines() -> void:
	var white := Color("f3f7ed")
	_box(self, "CenterLine", Vector3(0, 0.015, 0), Vector3(FIELD_W, 0.025, 0.11), white, false)
	_box(self, "LeftLine", Vector3(-FIELD_W * 0.5, 0.015, 0), Vector3(0.11, 0.025, FIELD_L), white, false)
	_box(self, "RightLine", Vector3(FIELD_W * 0.5, 0.015, 0), Vector3(0.11, 0.025, FIELD_L), white, false)
	_box(self, "NorthLine", Vector3(0, 0.015, -FIELD_L * 0.5), Vector3(FIELD_W, 0.025, 0.11), white, false)
	_box(self, "SouthLine", Vector3(0, 0.015, FIELD_L * 0.5), Vector3(FIELD_W, 0.025, 0.11), white, false)
	_box(self, "BlueEndLine", Vector3(0, 0.02, -FIELD_L * 0.5 + 5.0), Vector3(FIELD_W, 0.03, 0.14), blue, false)
	_box(self, "YellowEndLine", Vector3(0, 0.02, FIELD_L * 0.5 - 5.0), Vector3(FIELD_W, 0.03, 0.14), yellow, false)
	for z in [-18.0, -9.0, 9.0, 18.0]:
		_box(self, "Guide_%s" % z, Vector3(0, 0.012, z), Vector3(FIELD_W, 0.018, 0.045), Color(1, 1, 1, 0.24), false)


func _build_launch_pad() -> void:
	var pad := MeshInstance3D.new()
	pad.name = "LaunchPad"
	pad.position = Vector3(0, 0.035, 0)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.65
	mesh.bottom_radius = 1.65
	mesh.height = 0.045
	pad.mesh = mesh
	pad.material_override = _material(Color("243b48"), Color("0d4258"))
	add_child(pad)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.28
	torus.outer_radius = 1.38
	torus.rings = 40
	torus.ring_segments = 10
	ring.mesh = torus
	ring.material_override = _material(Color("72e3ff"), Color("32bbdc"))
	ring.position = Vector3(0, 0.075, 0)
	add_child(ring)


func _build_goal(pos: Vector3, team: int, color: Color) -> void:
	var root := Node3D.new()
	root.name = "BlueGoal" if team == 0 else "YellowGoal"
	root.position = pos
	add_child(root)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.65
	torus.outer_radius = 1.88
	torus.rings = 40
	torus.ring_segments = 18
	ring.mesh = torus
	ring.rotation_degrees.x = 90.0
	ring.material_override = _material(color, color, 0.28)
	root.add_child(ring)
	var area := Area3D.new()
	area.set_script(load("res://demo/scripts/goal_trigger.gd"))
	area.set("scoring_team", team)
	root.add_child(area)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.62
	shape.height = 0.7
	collision.shape = shape
	collision.rotation_degrees.x = 90.0
	area.add_child(collision)
	area.connect("scored", Callable(self, "_on_goal"))
	_box(root, "Stand", Vector3(0, -1.85, 0), Vector3(0.28, 2.0, 0.28), color)
	_box(root, "Base", Vector3(0, -2.72, 0), Vector3(2.4, 0.16, 1.2), Color(color, 0.85))


func _build_markers() -> void:
	for side in [-1.0, 1.0]:
		for z in [-20.0, -10.0, 0.0, 10.0, 20.0]:
			var post_color := blue if z < 0.0 else yellow
			_box(self, "Marker_%s_%s" % [side, z], Vector3(side * (FIELD_W * 0.5 + 1.1), 0.8, z), Vector3(0.14, 1.6, 0.14), post_color)
	# Low distant blocks provide motion/depth cues while keeping the arena open.
	for x in [-25.0, 25.0]:
		for z in [-34.0, 0.0, 34.0]:
			_box(self, "Landscape_%s_%s" % [x, z], Vector3(x, 0.5, z), Vector3(5.0, 1.0, 7.0), Color("45634a"), false)


func _build_stadium() -> void:
	# Layered, open-roof arena inspired by the supplied FPV reference. The low
	# poly construction keeps the scene fast enough for a stable 400 Hz sim.
	var concrete := Color("3b383b")
	var fascia := Color("17151b")
	var seat_colors := [Color("ff385f"), Color("f08a25"), Color("743fc4"), Color("20c98a")]
	var quality := int(InputProfile.graphics.get("quality", 1))
	var tier_count := 1 if quality == 0 else (2 if quality == 1 else 3)
	var seat_step := 10.0 if quality == 0 else (7.5 if quality == 1 else 5.0)
	for side: float in [-1.0, 1.0]:
		for tier in tier_count:
			var x: float = side * (18.0 + tier * 3.2)
			var height: float = 2.0 + tier * 3.1
			_box(self, "Stand_%s_%d" % [side, tier], Vector3(x, height * 0.5, 0), Vector3(5.8, height, 68.0), concrete, false)
			_box(self, "Fascia_%s_%d" % [side, tier], Vector3(side * (15.0 + tier * 3.2), height, 0), Vector3(0.35, 0.85, 68.0), fascia, false)
			for z_index in int(60.0 / seat_step) + 1:
				var z := -30.0 + z_index * seat_step
				var color: Color = seat_colors[(z_index + tier) % seat_colors.size()]
				var row_count := 1 if quality == 0 else (2 if quality == 1 else 3)
				for seat_row in row_count:
					var row_x := side * (14.7 + tier * 3.2 + seat_row * 0.72)
					var row_y := height + 0.45 + seat_row * 0.62
					_box(self, "Seats_%s_%d_%d_%d" % [side, tier, z_index, seat_row], Vector3(row_x, row_y, z), Vector3(0.42, 0.48, seat_step * 0.70), color.darkened(seat_row * 0.05), false)
			# Bright aisle edges and fascia strips add depth at virtually no CPU cost
			# because all decorative boxes are submitted through one MultiMesh.
			_box(self, "Aisle_%s_%d" % [side, tier], Vector3(side * (14.4 + tier * 3.2), height + 0.15, 0), Vector3(0.18, 0.18, 62.0), Color("d9d5ca"), false)
	# End stands leave broad tunnels so the arena reads as open rather than caged.
	for end: float in [-1.0, 1.0]:
		for x_index in 8:
			var x: float = -14.0 + x_index * 4.0
			if absf(x) < 4.1: continue
			var color: Color = seat_colors[(x_index + (0 if end < 0 else 2)) % seat_colors.size()]
			_box(self, "EndSeats_%s_%d" % [end, x_index], Vector3(x, 4.2, end * 36.0), Vector3(3.2, 6.0, 4.0), color, false)
	# Central scoreboard and roof trusses give scale and high-altitude cues.
	_box(self, "Scoreboard", Vector3(0, 12.0, -35.0), Vector3(14.0, 5.0, 0.7), Color("111318"), false)
	for end: float in [-1.0, 1.0]:
		_box(self, "RoofBeam_%s" % end, Vector3(0, 17.0, end * 34.0), Vector3(50.0, 0.45, 0.45), Color("4a4549"), false)


func _on_goal(team: int) -> void:
	goal_scored.emit(team)


func _build_lights() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52, -32, 0)
	sun.light_color = Color("fff1d0")
	sun.light_energy = 0.95
	sun.shadow_enabled = bool(InputProfile.graphics.get("shadows", true))
	sun.directional_shadow_max_distance = 55.0
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.name = "SkyFill"
	fill.rotation_degrees = Vector3(-25, 145, 0)
	fill.light_color = Color("a9d9ff")
	fill.light_energy = 0.28
	fill.shadow_enabled = false
	add_child(fill)
