extends Control

func _process(_delta: float) -> void:
	# The in-flight stick overlay must reflect the radio every rendered frame.
	# Calibration used to redraw it manually, while the game HUD stayed frozen.
	queue_redraw()

func _draw() -> void:
	draw_style_box(_panel_style(), Rect2(Vector2.ZERO, size))
	var stick_side := minf((size.x - 34.0) * 0.5, size.y - 48.0)
	var total_width := stick_side * 2.0 + 14.0
	var start_x := (size.x - total_width) * 0.5
	var start_y := 34.0 + maxf(0.0, (size.y - 42.0 - stick_side) * 0.5)
	_draw_stick(Rect2(start_x, start_y, stick_side, stick_side), InputProfile.value(&"yaw"), -InputProfile.value(&"throttle"), "偏航 / 油门")
	_draw_stick(Rect2(start_x + stick_side + 14.0, start_y, stick_side, stick_side), InputProfile.value(&"roll"), -InputProfile.value(&"pitch"), "横滚 / 俯仰")
	var status := "%s  ·  %s  ·  %.2fx" % [InputProfile.flight_mode, InputProfile.camera_mode, InputProfile.slow_motion]
	draw_string(ThemeDB.fallback_font, Vector2(10, 17), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("ffd46a"))

func _draw_stick(rect: Rect2, x_value: float, y_value: float, caption: String) -> void:
	draw_style_box(_stick_style(), rect)
	var center := rect.get_center()
	draw_line(Vector2(rect.position.x, center.y), Vector2(rect.end.x, center.y), Color("3b4851"), 1)
	draw_line(Vector2(center.x, rect.position.y), Vector2(center.x, rect.end.y), Color("3b4851"), 1)
	var point := center + Vector2(clampf(x_value, -1.0, 1.0) * rect.size.x * 0.45, clampf(y_value, -1.0, 1.0) * rect.size.y * 0.45)
	draw_circle(point, 13.0, Color(1.0, 0.72, 0.08, 0.12))
	draw_circle(point, 7.0, Color("ffc21a"))
	draw_circle(point, 8.5, Color("fff0b0"), false, 1.5, true)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, -7), caption, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 12, Color("b8c0c5"))

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.018, 0.026, 0.82)
	style.border_color = Color(0.95, 0.69, 0.08, 0.38)
	style.set_border_width_all(1)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0, 0, 0, 0.32)
	style.shadow_size = 10
	return style

func _stick_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.035, 0.045, 0.92)
	style.border_color = Color(0.48, 0.55, 0.60, 0.62)
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	return style
