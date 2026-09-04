extends Control

signal value_changed(value: float)

var min_value := 0.0
var max_value := 1.0
var step := 0.01
var value := 0.0:
	set(next_value):
		var snapped := snappedf(clampf(next_value, min_value, max_value), step)
		if is_equal_approx(value, snapped): return
		value = snapped
		queue_redraw()
		value_changed.emit(value)

var _dragging := false

func _ready() -> void:
	custom_minimum_size = Vector2(180, 34)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if _dragging: _set_from_x(event.position.x)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_set_from_x(event.position.x)
		accept_event()
	elif event.is_action_pressed("ui_left"):
		value -= step; accept_event()
	elif event.is_action_pressed("ui_right"):
		value += step; accept_event()

func _set_from_x(x: float) -> void:
	value = lerpf(min_value, max_value, clampf((x - 12.0) / maxf(1.0, size.x - 24.0), 0.0, 1.0))

func _draw() -> void:
	var center_y := size.y * 0.5
	var start := Vector2(12, center_y)
	var finish := Vector2(size.x - 12, center_y)
	draw_line(start, finish, Color("3b3d42"), 6.0, true)
	var ratio := inverse_lerp(min_value, max_value, value)
	var knob := start.lerp(finish, ratio)
	draw_line(start, knob, Color("f0ae00"), 6.0, true)
	draw_circle(knob, 10.0, Color(0.94, 0.68, 0.0, 0.18))
	draw_circle(knob, 7.0, Color("ffc21a"))
	draw_circle(knob, 7.0, Color("fff0b0"), false, 1.5, true)
