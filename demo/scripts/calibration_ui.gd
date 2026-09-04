extends CanvasLayer
const CONTROLS := [&"roll", &"pitch", &"yaw", &"throttle"]
const LABELS := ["ROLL 横滚", "PITCH 俯仰", "YAW 偏航", "THROTTLE 油门"]
const POSITIVE_DIRECTIONS := ["向右", "向后拉（机头抬起）", "向右", "推到最高"]
const SAMPLE_SECONDS := 4.0
const RAW_AXIS_COUNT := 16
@export var game_path: NodePath
var game: Node
var device: OptionButton
var hint: Label
var progress: ProgressBar
var bars: Array[ProgressBar] = []
var values: Array[Label] = []
var buttons: Array[Button] = []
var raw_button_labels: Array[Label] = []
var monitor: Control
var curve: Control
var current := -1
var sampling := false
var sample_time := 0.0
var baseline: Array[float] = []
var minima: Array[float] = []
var maxima: Array[float] = []
var positive_motion: Array[float] = []

func _ready() -> void:
	game = get_node(game_path)
	layer = 20
	_build_ui()
	visible = false

func _process(delta: float) -> void:
	if visible: _update_live()
	if not sampling: return
	sample_time += delta
	for axis in RAW_AXIS_COUNT:
		var raw: float = InputProfile.raw_axis(axis)
		minima[axis] = minf(minima[axis], raw)
		maxima[axis] = maxf(maxima[axis], raw)
		if sample_time <= SAMPLE_SECONDS * 0.5:
			var movement: float = raw - baseline[axis]
			if absf(movement) > absf(positive_motion[axis]): positive_motion[axis] = movement
	progress.value = sample_time
	if sample_time >= SAMPLE_SECONDS: _finish_sample()

func _build_ui() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.018, 0.028, 0.98)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-570, -390)
	panel.size = Vector2(1500, 860)
	panel.theme = _reference_theme()
	shade.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	panel.add_child(outer)
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 64
	outer.add_child(header)
	var title := Label.new()
	title.text = "  无人机设置"
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var save := Button.new()
	save.text = "保存并返回"
	save.custom_minimum_size = Vector2(160, 54)
	save.pressed.connect(close_ui)
	header.add_child(save)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(tabs)
	tabs.add_child(_controller_page())
	tabs.add_child(_basic_page())
	tabs.add_child(_physics_page())

func _page(name_value: String) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.name = name_value
	page.add_theme_constant_override("separation", 14)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	scroll.add_child(margin)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)
	return page

func _content(page: VBoxContainer) -> VBoxContainer:
	return page.get_child(0).get_child(0).get_child(0) as VBoxContainer

func _controller_page() -> VBoxContainer:
	var page := _page("控制器设置")
	var body := _content(page)
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 24)
	body.add_child(split)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 9)
	split.add_child(left)
	var title := Label.new()
	title.text = "控制器设置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 25)
	left.add_child(title)
	device = OptionButton.new()
	device.custom_minimum_size.y = 44
	device.item_selected.connect(_select_device)
	left.add_child(device)
	hint = Label.new()
	hint.text = "识别时：前 2 秒推向标注正方向，后 2 秒推向反方向。"
	hint.custom_minimum_size.y = 38
	left.add_child(hint)
	for i in CONTROLS.size(): _add_channel(left, i)
	var aux_row := HBoxContainer.new()
	left.add_child(aux_row)
	_add_aux_choice(aux_row, "重置", "reset")
	_add_aux_choice(aux_row, "慢动作", "slow_motion")
	_add_aux_choice(aux_row, "相机切换", "camera")
	_add_aux_choice(aux_row, "飞行模式", "flight_mode")
	progress = ProgressBar.new()
	progress.max_value = SAMPLE_SECONDS
	progress.show_percentage = false
	left.add_child(progress)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 610
	right.add_theme_constant_override("separation", 10)
	split.add_child(right)
	var raw_title := Label.new()
	raw_title.text = "控制器原始输入"
	raw_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	raw_title.add_theme_font_size_override("font_size", 24)
	right.add_child(raw_title)
	var raw_grid := GridContainer.new()
	raw_grid.name = "RawGrid"
	raw_grid.columns = 4
	right.add_child(raw_grid)
	for axis in RAW_AXIS_COUNT:
		var raw_label := Label.new()
		raw_label.name = "Axis%d" % axis
		raw_label.text = "AXIS-%02d  0.000" % (axis + 1)
		raw_label.custom_minimum_size = Vector2(140, 25)
		raw_grid.add_child(raw_label)
	var button_grid := GridContainer.new()
	button_grid.columns = 10
	right.add_child(button_grid)
	for button_index in 20:
		var button_label := Label.new()
		button_label.text = "%02d" % (button_index + 1)
		button_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button_label.custom_minimum_size = Vector2(48, 28)
		button_grid.add_child(button_label)
		raw_button_labels.append(button_label)
	var state_title := Label.new()
	state_title.text = "控制状态"
	state_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_title.add_theme_font_size_override("font_size", 24)
	right.add_child(state_title)
	monitor = preload("res://demo/scripts/controller_monitor.gd").new()
	monitor.custom_minimum_size = Vector2(590, 215)
	right.add_child(monitor)
	var quick_modes := HBoxContainer.new()
	right.add_child(quick_modes)
	for mode_name in ["Acro", "Angle", "Altitude"]:
		var mode_button := Button.new()
		mode_button.text = mode_name
		mode_button.pressed.connect(_set_flight_mode.bind(mode_name))
		quick_modes.add_child(mode_button)
	for camera_name in ["FPV", "Chase", "LOS"]:
		var camera_button := Button.new()
		camera_button.text = camera_name
		camera_button.pressed.connect(_set_camera_mode.bind(camera_name))
		quick_modes.add_child(camera_button)
	var actions := HBoxContainer.new()
	right.add_child(actions)
	var all_button := Button.new()
	all_button.text = "依次校准四通道"
	all_button.custom_minimum_size = Vector2(260, 52)
	all_button.pressed.connect(_start_full_calibration)
	actions.add_child(all_button)
	var reset_button := Button.new()
	reset_button.text = "重置校准数据"
	reset_button.custom_minimum_size = Vector2(260, 52)
	reset_button.pressed.connect(_reset_defaults)
	actions.add_child(reset_button)
	return page

func _add_channel(parent: VBoxContainer, index: int) -> void:
	var card := HBoxContainer.new()
	card.add_theme_constant_override("separation", 7)
	parent.add_child(card)
	var label := Label.new()
	label.text = LABELS[index]
	label.custom_minimum_size.x = 125
	card.add_child(label)
	var bar := ProgressBar.new()
	bar.min_value = -100
	bar.max_value = 100
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(190, 34)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(bar)
	bars.append(bar)
	var value := Label.new()
	value.custom_minimum_size.x = 52
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	card.add_child(value)
	values.append(value)
	var axis_choice := OptionButton.new()
	axis_choice.custom_minimum_size.x = 102
	for axis_index in RAW_AXIS_COUNT: axis_choice.add_item("AXIS-%d" % (axis_index + 1), axis_index)
	axis_choice.select(clampi(int(InputProfile.mappings[String(CONTROLS[index])].axis), 0, RAW_AXIS_COUNT - 1))
	axis_choice.item_selected.connect(_axis_changed.bind(axis_choice, index))
	card.add_child(axis_choice)
	var invert := CheckButton.new()
	invert.text = "反向"
	invert.button_pressed = bool(InputProfile.mappings[String(CONTROLS[index])].invert)
	invert.toggled.connect(_invert_changed.bind(index))
	card.add_child(invert)
	var dz := SpinBox.new()
	dz.prefix = "死区 "
	dz.min_value = 0.0
	dz.max_value = 0.30
	dz.step = 0.01
	dz.value = float(InputProfile.mappings[String(CONTROLS[index])].get("deadzone", InputProfile.deadzone))
	dz.custom_minimum_size.x = 100
	dz.value_changed.connect(_deadzone_changed.bind(index))
	card.add_child(dz)
	var identify := Button.new()
	identify.text = "识别"
	identify.custom_minimum_size.x = 74
	identify.pressed.connect(_start_sample.bind(index))
	card.add_child(identify)
	buttons.append(identify)

func _rate_page() -> VBoxContainer:
	var page := _page("RATE")
	var body := _content(page)
	var help := Label.new()
	help.text = "Betaflight Rate · 分轴调节。RC Rate 控制中心响应，Super Rate 提高杆端转速，Expo 让中心更柔和。"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(help)
	var type_row := HBoxContainer.new()
	body.add_child(type_row)
	var type_label := Label.new()
	type_label.text = "RATE 类型"
	type_label.custom_minimum_size.x = 120
	type_row.add_child(type_label)
	var type_choice := OptionButton.new()
	for rate_name in ["Actual", "Betaflight", "Raceflight", "KISS"]: type_choice.add_item(rate_name)
	type_choice.select(["Actual", "Betaflight", "Raceflight", "KISS"].find(InputProfile.rate_type))
	type_choice.item_selected.connect(_rate_type_changed.bind(type_choice))
	type_row.add_child(type_choice)
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 24)
	body.add_child(split)
	var table := VBoxContainer.new()
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(table)
	var heading := Label.new()
	heading.text = "轴                  RC RATE          SUPER RATE          EXPO          最大角速度"
	heading.add_theme_color_override("font_color", Color("8edcff"))
	table.add_child(heading)
	for axis_name in ["roll", "pitch", "yaw"]: _add_rate_row(table, axis_name)
	curve = preload("res://demo/scripts/rate_curve.gd").new()
	curve.custom_minimum_size = Vector2(430, 330)
	split.add_child(curve)
	var actual_title := Label.new()
	actual_title.text = "Actual Rate（中心灵敏度 / 最大角速度 / Expo / Feed Forward）"
	actual_title.add_theme_color_override("font_color", Color("9fb8c8"))
	table.add_child(actual_title)
	for actual_axis in ["roll", "pitch", "yaw"]: _add_actual_row(table, actual_axis)
	var level_title := Label.new()
	level_title.text = "自稳 / 定高模式"
	level_title.add_theme_color_override("font_color", Color("9fb8c8"))
	table.add_child(level_title)
	_add_dict_slider(table, "自稳灵敏度", "level", "sensitivity", 10.0, 100.0, float(InputProfile.level.sensitivity))
	_add_dict_slider(table, "电机怠速", "general", "motor_idle", 0.02, 0.12, InputProfile.motor_idle)
	_add_dict_slider(table, "角度限制", "level", "angle_limit", 15.0, 85.0, float(InputProfile.level.angle_limit))
	var preset := HBoxContainer.new()
	table.add_child(preset)
	for item in [["柔和", 0.72, 0.55, 0.30], ["默认", 1.0, 0.70, 0.20], ["竞速", 1.25, 0.78, 0.12]]:
		var button := Button.new()
		button.text = item[0]
		button.pressed.connect(_rate_preset.bind(float(item[1]), float(item[2]), float(item[3])))
		preset.add_child(button)
	return page

func _add_rate_row(parent: VBoxContainer, axis_name: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var names := {"roll":"R 横滚", "pitch":"P 俯仰", "yaw":"Y 偏航"}
	var label := Label.new()
	label.text = names[axis_name]
	label.custom_minimum_size.x = 95
	row.add_child(label)
	var rate: Dictionary = InputProfile.axis_rates[axis_name]
	_rate_spin(row, axis_name, "rc", 0.2, 2.5, float(rate.rc))
	_rate_spin(row, axis_name, "super", 0.0, 0.95, float(rate.super))
	_rate_spin(row, axis_name, "expo", 0.0, 1.0, float(rate.expo))
	var max_label := Label.new()
	max_label.name = axis_name + "Max"
	max_label.custom_minimum_size.x = 100
	max_label.text = "%d °/s" % _max_rate(rate)
	row.add_child(max_label)

func _add_actual_row(parent: VBoxContainer, axis_name: String) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = axis_name.to_upper()
	label.custom_minimum_size.x = 95
	row.add_child(label)
	var values: Dictionary = InputProfile.actual_rates[axis_name]
	for key in ["center", "max", "expo", "ff"]:
		var spin := SpinBox.new()
		spin.min_value = 0.0
		spin.max_value = 1500.0 if key in ["center", "max"] else 1.0
		spin.step = 1.0 if key in ["center", "max"] else 0.01
		spin.value = float(values[key])
		spin.custom_minimum_size.x = 135
		spin.value_changed.connect(_actual_rate_changed.bind(axis_name, key))
		row.add_child(spin)

func _add_dict_slider(parent: VBoxContainer, caption: String, group: String, key: String, minimum: float, maximum: float, value: float) -> void:
	_add_profile_slider(parent, caption, group, key, minimum, maximum, value, "")

func _add_aux_choice(parent: HBoxContainer, caption: String, action: String) -> void:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	var label := Label.new()
	label.text = caption
	box.add_child(label)
	var choice := OptionButton.new()
	choice.add_item("NONE", -1)
	for button_index in 20: choice.add_item("BUTTON-%d" % (button_index + 1), button_index)
	choice.select(int(InputProfile.aux_buttons.get(action, -1)) + 1)
	choice.item_selected.connect(_aux_changed.bind(choice, action))
	box.add_child(choice)

func _rate_spin(parent: HBoxContainer, axis_name: String, key: String, minimum: float, maximum: float, value: float) -> void:
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = 0.01
	spin.value = value
	spin.custom_minimum_size.x = 135
	spin.value_changed.connect(_rate_changed.bind(axis_name, key))
	parent.add_child(spin)

func _basic_page() -> VBoxContainer:
	var page := _page("基础")
	var body := _content(page)
	var help := Label.new()
	help.text = "镜头与跟随视角"
	var camera_row := HBoxContainer.new()
	body.add_child(camera_row)
	var camera_label := Label.new()
	camera_label.text = "相机模式"
	camera_label.custom_minimum_size.x = 190
	camera_row.add_child(camera_label)
	var camera_choice := OptionButton.new()
	for camera_name in ["Chase", "FPV", "LOS"]: camera_choice.add_item(camera_name)
	camera_choice.select(["Chase", "FPV", "LOS"].find(InputProfile.camera_mode))
	camera_choice.item_selected.connect(_camera_mode_changed.bind(camera_choice))
	camera_row.add_child(camera_choice)
	var flight_row := HBoxContainer.new()
	body.add_child(flight_row)
	var flight_label := Label.new()
	flight_label.text = "飞行模式"
	flight_label.custom_minimum_size.x = 190
	flight_row.add_child(flight_label)
	var flight_choice := OptionButton.new()
	for mode_name in ["Acro", "Angle", "Altitude"]: flight_choice.add_item(mode_name)
	flight_choice.select(["Acro", "Angle", "Altitude"].find(InputProfile.flight_mode))
	flight_choice.item_selected.connect(_flight_mode_changed.bind(flight_choice))
	flight_row.add_child(flight_choice)
	help.add_theme_font_size_override("font_size", 22)
	body.add_child(help)
	_add_profile_slider(body, "FPV 镜头仰角", "camera", "angle", -10, 55, float(InputProfile.camera.angle), "°")
	_add_profile_slider(body, "FPV 视野 FOV", "camera", "fov", 70, 150, float(InputProfile.camera.fov), "°")
	_add_profile_slider(body, "跟随距离", "camera", "follow_distance", 4, 18, float(InputProfile.camera.follow_distance), " m")
	_add_profile_slider(body, "跟随高度", "camera", "follow_height", 1.5, 10, float(InputProfile.camera.follow_height), " m")
	var component_title := Label.new()
	component_title.text = "机体组件"
	component_title.add_theme_font_size_override("font_size", 22)
	body.add_child(component_title)
	_add_component_toggle(body, "导航灯 / LED", "led")
	_add_component_toggle(body, "独立桨叶保护圈", "prop_guards")
	return page

func _physics_page() -> VBoxContainer:
	var page := _page("物理")
	var body := _content(page)
	var help := Label.new()
	help.text = "这些参数直接作用于原生 C++ 刚体、旋翼和空气动力模型。"
	help.add_theme_font_size_override("font_size", 20)
	body.add_child(help)
	_add_profile_slider(body, "机体重量", "physics", "mass", 0.5, 3.0, float(InputProfile.physics.mass), " kg")
	_add_profile_slider(body, "重力倍率", "physics", "gravity", 0.6, 1.4, float(InputProfile.physics.gravity), " x")
	_add_profile_slider(body, "旋翼推力倍率", "physics", "thrust", 0.5, 1.5, float(InputProfile.physics.thrust), " x")
	_add_profile_slider(body, "低速阻力", "physics", "drag_low", 0.0, 0.20, float(InputProfile.physics.drag_low), "")
	_add_profile_slider(body, "高速阻力", "physics", "drag_high", 0.02, 0.60, float(InputProfile.physics.drag_high), "")
	_add_profile_slider(body, "空气乱流", "physics", "turbulence", 0.0, 2.0, float(InputProfile.physics.turbulence), "")
	_add_profile_slider(body, "电机 KV", "physics", "motor_kv", 800.0, 3000.0, float(InputProfile.physics.motor_kv), " KV")
	_add_profile_slider(body, "电池电压", "physics", "voltage", 7.4, 25.2, float(InputProfile.physics.voltage), " V")
	_add_profile_slider(body, "慢动作倍率", "general", "slow_motion", 0.2, 1.0, InputProfile.slow_motion, " x")
	_add_profile_slider(body, "电机最大输出", "output", "motor_output_limit", 0.2, 0.8, InputProfile.motor_output_limit, "")
	return page

func _add_profile_slider(parent: VBoxContainer, caption: String, group: String, key: String, minimum: float, maximum: float, value: float, suffix: String) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size.x = 190
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 0.01
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var number := Label.new()
	number.text = "%.2f%s" % [value, suffix]
	number.custom_minimum_size.x = 100
	row.add_child(number)
	slider.value_changed.connect(_profile_changed.bind(group, key, number, suffix))

func open() -> void:
	visible = true
	game.set_input_blocked(true)
	_refresh_devices()
func close_ui() -> void:
	sampling = false
	visible = false
	InputProfile.save_profile()
	game.set_input_blocked(false)
	game.set_status("设置已保存并应用")
func _refresh_devices() -> void:
	device.clear()
	var ids := InputProfile.connected_devices()
	if ids.is_empty():
		device.add_item("未检测到 USB 遥控器", -1)
		for button in buttons: button.disabled = true
		return
	for button in buttons: button.disabled = false
	for id in ids:
		device.add_item("%d: %s" % [id, Input.get_joy_name(id)], id)
		if id == InputProfile.device_id: device.select(device.item_count - 1)
func _select_device(index: int) -> void:
	InputProfile.device_id = device.get_item_id(index)
	InputProfile.save_profile()
func _update_live() -> void:
	for i in CONTROLS.size():
		var map: Dictionary = InputProfile.mappings[String(CONTROLS[i])]
		bars[i].value = InputProfile.value(CONTROLS[i]) * 100.0
		values[i].text = "AXIS-%d  %+.0f" % [int(map.axis), bars[i].value]
	var grid := get_tree().current_scene.find_child("RawGrid", true, false) as GridContainer
	for axis in RAW_AXIS_COUNT:
		var label := grid.get_node("Axis%d" % axis) as Label
		label.text = "AXIS-%02d  %+.3f" % [axis + 1, InputProfile.raw_axis(axis)]
	for button_index in raw_button_labels.size():
		var pressed: bool = InputProfile.device_id in InputProfile.connected_devices() and Input.is_joy_button_pressed(InputProfile.device_id, button_index)
		raw_button_labels[button_index].modulate = Color("ffd23f") if pressed else Color("75838b")
	if monitor: monitor.queue_redraw()
func _start_sample(index: int) -> void:
	if sampling: return
	current = index
	sampling = true
	sample_time = 0.0
	progress.value = 0
	baseline.resize(RAW_AXIS_COUNT); minima.resize(RAW_AXIS_COUNT); maxima.resize(RAW_AXIS_COUNT); positive_motion.resize(RAW_AXIS_COUNT)
	for axis in RAW_AXIS_COUNT:
		baseline[axis] = InputProfile.raw_axis(axis)
		minima[axis] = baseline[axis]
		maxima[axis] = baseline[axis]
		positive_motion[axis] = 0.0
	for button in buttons: button.disabled = true
	hint.text = "识别【%s】：前 2 秒%s，后 2 秒推到反方向。" % [LABELS[index], POSITIVE_DIRECTIONS[index]]
func _finish_sample() -> void:
	sampling = false
	var best_axis := 0
	var best_range := 0.0
	for axis in RAW_AXIS_COUNT:
		var travel: float = maxima[axis] - minima[axis]
		if travel > best_range: best_range = travel; best_axis = axis
	for button in buttons: button.disabled = false
	if best_range < 0.65:
		hint.text = "行程不足，请重新识别并推满。"
		return
	var center: float = InputProfile.raw_axis(best_axis)
	var invert: bool = positive_motion[best_axis] < 0.0
	if CONTROLS[current] == &"throttle":
		center = (minima[best_axis] + maxima[best_axis]) * 0.5
	InputProfile.set_mapping(CONTROLS[current], best_axis, minima[best_axis], center, maxima[best_axis], invert)
	hint.text = "完成：%s = AXIS-%d，方向%s，行程 %.0f%%。" % [LABELS[current], best_axis + 1, "已反向" if invert else "正常", best_range * 50.0]
	if not full_calibration_queue.is_empty(): call_deferred("_start_next_full_channel")
func _invert_changed(enabled: bool, index: int) -> void:
	InputProfile.mappings[String(CONTROLS[index])].invert = enabled
	InputProfile.save_profile()
func _rate_changed(value: float, axis_name: String, key: String) -> void:
	InputProfile.set_rate_value(axis_name, key, value)
	if curve: curve.queue_redraw()
	var rate: Dictionary = InputProfile.axis_rates[axis_name]
	var label := get_tree().current_scene.find_child(axis_name + "Max", true, false) as Label
	if label: label.text = "%d °/s" % _max_rate(rate)
func _max_rate(rate: Dictionary) -> int:
	var rc := float(rate.rc)
	if rc > 2.0: rc += 14.54 * (rc - 2.0)
	return int(200.0 * rc / maxf(0.05, 1.0 - float(rate.super)))
func _rate_preset(rc: float, super_rate: float, expo: float) -> void:
	for axis_name in ["roll", "pitch", "yaw"]:
		InputProfile.axis_rates[axis_name] = {"rc": rc if axis_name != "yaw" else rc * 0.85, "super": super_rate, "expo": expo}
	InputProfile.save_profile()
	InputProfile.profile_changed.emit()
	close_ui()
	game.open_calibration()
func _rate_type_changed(index: int, choice: OptionButton) -> void:
	InputProfile.set_general_value("rate_type", choice.get_item_text(index))
func _camera_mode_changed(index: int, choice: OptionButton) -> void:
	InputProfile.set_general_value("camera_mode", choice.get_item_text(index))
	game.set_camera_mode(InputProfile.camera_mode)
func _flight_mode_changed(index: int, choice: OptionButton) -> void:
	InputProfile.set_general_value("flight_mode", choice.get_item_text(index))
func _aux_changed(index: int, choice: OptionButton, action: String) -> void:
	InputProfile.aux_buttons[action] = choice.get_item_id(index)
	InputProfile.save_profile()
func _actual_rate_changed(value: float, axis_name: String, key: String) -> void:
	InputProfile.actual_rates[axis_name][key] = value
	InputProfile.save_profile()
	InputProfile.profile_changed.emit()

func _profile_changed(value: float, group: String, key: String, number: Label, suffix: String) -> void:
	number.text = "%.2f%s" % [value, suffix]
	if group == "physics": InputProfile.set_physics_value(key, value)
	elif group == "camera": InputProfile.set_camera_value(key, value)
	elif group == "level":
		InputProfile.level[key] = value
		InputProfile.save_profile()
		InputProfile.profile_changed.emit()
	elif group == "general": InputProfile.set_general_value(key, value)
	else:
		InputProfile.set(key, value)
		InputProfile.save_profile()
		InputProfile.profile_changed.emit()

func _axis_changed(_selected: int, choice: OptionButton, index: int) -> void:
	var key := String(CONTROLS[index])
	var map: Dictionary = InputProfile.mappings[key]
	map["axis"] = choice.get_selected_id()
	InputProfile.mappings[key] = map
	InputProfile.save_profile()
	InputProfile.profile_changed.emit()

func _deadzone_changed(value: float, index: int) -> void:
	var key := String(CONTROLS[index])
	InputProfile.mappings[key]["deadzone"] = value
	InputProfile.save_profile()
	InputProfile.profile_changed.emit()

func _set_flight_mode(mode: String) -> void:
	InputProfile.flight_mode = mode
	InputProfile.save_profile()
	game.set_status("飞行模式：" + mode)

func _set_camera_mode(mode: String) -> void:
	InputProfile.camera_mode = mode
	InputProfile.save_profile()
	game.set_camera_mode(mode)

func _reset_defaults() -> void:
	InputProfile.reset_defaults()
	game.set_camera_mode(InputProfile.camera_mode)
	game.set_status("已恢复默认设置；重新打开设置可查看全部默认值")

func _add_component_toggle(parent: VBoxContainer, caption: String, key: String) -> void:
	var toggle := CheckButton.new()
	toggle.text = caption
	toggle.button_pressed = bool(InputProfile.components.get(key, false))
	toggle.toggled.connect(_component_changed.bind(key))
	parent.add_child(toggle)

func _component_changed(enabled: bool, key: String) -> void:
	InputProfile.components[key] = enabled
	InputProfile.save_profile()
	InputProfile.profile_changed.emit()

func _reference_theme() -> Theme:
	var theme := Theme.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("242424")
	panel_style.border_color = Color("515151")
	panel_style.set_border_width_all(3)
	theme.set_stylebox("panel", "PanelContainer", panel_style)
	var button_style := StyleBoxFlat.new()
	button_style.bg_color = Color("514e6d")
	button_style.border_color = Color("77749c")
	button_style.set_border_width_all(2)
	theme.set_stylebox("normal", "Button", button_style)
	var hover_style := button_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color("68638e")
	theme.set_stylebox("hover", "Button", hover_style)
	theme.set_color("font_color", "Label", Color("e8e8e8"))
	theme.set_color("font_color", "Button", Color("f3f3f3"))
	theme.set_color("font_color", "OptionButton", Color("f3f3f3"))
	theme.set_color("font_color", "SpinBox", Color("f2c800"))
	theme.set_font_size("font_size", "Label", 16)
	theme.set_font_size("font_size", "Button", 16)
	return theme

var full_calibration_queue: Array[int] = []

func _start_full_calibration() -> void:
	if sampling: return
	full_calibration_queue = [0, 1, 2, 3]
	_start_next_full_channel()

func _start_next_full_channel() -> void:
	if full_calibration_queue.is_empty():
		hint.text = "四通道校准完成，请检查控制状态后保存。"
		return
	var next_channel: int = full_calibration_queue.pop_front()
	_start_sample(next_channel)
