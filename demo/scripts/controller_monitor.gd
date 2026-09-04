extends Control

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.018, 0.024, 0.032, 1.0), true)
	var half: float = size.x * 0.5
	_draw_stick(Rect2(10, 24, half - 20, size.y - 34), InputProfile.value(&"yaw"), InputProfile.value(&"throttle"), "偏航 / 油门")
	_draw_stick(Rect2(half + 10, 24, half - 20, size.y - 34), InputProfile.value(&"roll"), -InputProfile.value(&"pitch"), "横滚 / 俯仰")
	var status := "%s  ·  %s  ·  %.2fx" % [InputProfile.flight_mode, InputProfile.camera_mode, InputProfile.slow_motion]
	draw_string(ThemeDB.fallback_font, Vector2(10, 17), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("ffd46a"))

func _draw_stick(rect: Rect2, x_value: float, y_value: float, caption: String) -> void:
	draw_rect(rect, Color(0.03, 0.04, 0.052, 1.0), true)
	draw_rect(rect, Color("53616a"), false, 2.0)
	var center := rect.get_center()
	draw_line(Vector2(rect.position.x, center.y), Vector2(rect.end.x, center.y), Color("3b4851"), 1)
	draw_line(Vector2(center.x, rect.position.y), Vector2(center.x, rect.end.y), Color("3b4851"), 1)
	var point := center + Vector2(clampf(x_value, -1.0, 1.0) * rect.size.x * 0.45, clampf(y_value, -1.0, 1.0) * rect.size.y * 0.45)
	draw_circle(point, 7.0, Color("f4f6f7"))
	draw_circle(point, 9.0, Color("73828c"), false, 2.0)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(6, 16), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("a8b6bf"))
