extends Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("05060a"))
	var radius := 34.0
	var width := radius * 1.73
	var row_height := radius * 1.5
	var rows := int(size.y / row_height) + 3
	var cols := int(size.x / width) + 3
	for row in rows:
		for col in cols:
			var center := Vector2(col * width + (width * 0.5 if row % 2 else 0.0), row * row_height)
			var points := PackedVector2Array()
			for i in 6:
				var angle := deg_to_rad(60.0 * i - 30.0)
				points.append(center + Vector2(cos(angle), sin(angle)) * radius)
			points.append(points[0])
			draw_polyline(points, Color(0.12, 0.13, 0.19, 0.58), 2.0, true)
	# Warm amber glow keeps the black/yellow visual language without a costly shader.
	draw_circle(Vector2(size.x * 0.52, size.y * 1.05), size.x * 0.42, Color(0.35, 0.18, 0.0, 0.16))
