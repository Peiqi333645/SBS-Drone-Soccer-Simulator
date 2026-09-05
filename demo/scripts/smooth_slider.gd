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
var _hovered := false

func _ready() -> void:
	custom_minimum_size = Vector2(180, 40)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	mouse_entered.connect(func(): _hovered = true; queue_redraw())
	mouse_exited.connect(func(): _hovered = false; queue_redraw())

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
	var start := Vector2(14, center_y)
	var finish := Vector2(size.x - 14, center_y)
	# Layered strokes give the control a recessed track without a costly shader.
	draw_line(start, finish, Color(0, 0, 0, 0.42), 12.0, true)
	draw_line(start, finish, Color("343a40"), 8.0, true)
	draw_line(start + Vector2(0, -1), finish + Vector2(0, -1), Color(0.58, 0.62, 0.65, 0.16), 2.0, true)
	var ratio := inverse_lerp(min_value, max_value, value)
	var knob := start.lerp(finish, ratio)
	draw_line(start, knob, Color("d99500"), 8.0, true)
	draw_line(start, knob, Color("ffc21a"), 3.0, true)
	var glow_radius := 15.0 if _hovered or _dragging else 12.0
	draw_circle(knob, glow_radius, Color(1.0, 0.70, 0.04, 0.14))
	draw_circle(knob, 9.0, Color("17191d"))
	draw_circle(knob, 7.0, Color("ffc21a"))
	draw_circle(knob + Vector2(-2, -2), 2.2, Color(1, 0.94, 0.68, 0.82))
