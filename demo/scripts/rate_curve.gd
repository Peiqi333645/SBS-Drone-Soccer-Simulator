extends Control
func _ready() -> void:
	InputProfile.profile_changed.connect(queue_redraw)
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.018, 0.026, 0.04, 1.0), true)
	for i in 5:
		var x: float = size.x * float(i) / 4.0
		var y: float = size.y * float(i) / 4.0
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.2, 0.28, 0.34, 0.55), 1)
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.2, 0.28, 0.34, 0.55), 1)
	var colors := {"roll": Color("ff3c86"), "pitch": Color("60e461"), "yaw": Color("45a5ff")}
	for axis_name in ["roll", "pitch", "yaw"]:
		var rate: Dictionary = InputProfile.actual_rates[axis_name] if InputProfile.rate_type == "Actual" else InputProfile.axis_rates[axis_name]
		var points := PackedVector2Array()
		var maximum: float = maxf(absf(RateMath.degrees_per_second(InputProfile.rate_type, 1.0, rate)), 1.0)
		for i in 65:
			var stick: float = float(i) / 64.0
			var output: float = RateMath.degrees_per_second(InputProfile.rate_type, stick, rate) / maximum
			points.append(Vector2(stick * size.x, size.y - output * size.y))
		draw_polyline(points, colors[axis_name], 3.0, true)
