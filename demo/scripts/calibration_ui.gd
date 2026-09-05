extends CanvasLayer
const CONTROLS := [&"roll", &"pitch", &"yaw", &"throttle"]
const LABELS := ["ROLL 横滚", "PITCH 俯仰", "YAW 偏航", "THROTTLE 油门"]
const POSITIVE_DIRECTIONS := ["向右", "向后拉（机头抬起）", "向右", "推到最高"]
const SAMPLE_SECONDS := 3.0
const RAW_AXIS_COUNT := 16
@export var game_path: NodePath
var game: Node
var device: OptionButton
var hint: Label
var progress: ProgressBar
var bars: Array[ProgressBar] = []
var values: Array[Label] = []
var buttons: Array[Button] = []
var aux_labels := {}
var aux_state_labels := {}
var aux_sampling := false
var current_aux := ""
var aux_baseline: Array[float] = []
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
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	visible = false

func _input(event: InputEvent) -> void:
	if visible and (event is InputEventJoypadMotion or event is InputEventJoypadButton):
		# Input singleton has already recorded the radio state, so calibration can
		# read it while the GUI is prevented from treating it as navigation/clicks.
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if visible: _update_live()
	if aux_sampling:
		for button_index in 32:
			if InputProfile.device_id in InputProfile.connected_devices() and Input.is_joy_button_pressed(InputProfile.device_id, button_index):
				InputProfile.aux_buttons[current_aux] = {"type":"button", "index":button_index}
				InputProfile.save_profile()
				aux_labels[current_aux].text = "BUTTON-%d" % (button_index + 1)
				hint.text = "完成：已识别 %s 为 BUTTON-%d" % [current_aux, button_index + 1]
				aux_sampling = false
				for button in buttons: button.disabled = false
				break
		if aux_sampling:
			for axis_index in RAW_AXIS_COUNT:
				var raw_aux := InputProfile.raw_axis(axis_index)
				if absf(raw_aux - aux_baseline[axis_index]) > 0.45:
					InputProfile.aux_buttons[current_aux] = {"type":"axis", "index":axis_index, "threshold":(raw_aux + aux_baseline[axis_index]) * 0.5, "active_high":raw_aux > aux_baseline[axis_index]}
					InputProfile.save_profile()
					aux_labels[current_aux].text = "AXIS-%d" % (axis_index + 1)
					hint.text = "完成：%s 已映射到 AXIS-%d" % [current_aux, axis_index + 1]
					aux_sampling = false
					for identify_button in buttons: identify_button.disabled = false
					break
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
	var shade := preload("res://demo/scripts/hex_background.gd").new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 42
	panel.offset_top = 34
	panel.offset_right = -42
	panel.offset_bottom = -34
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
	tabs.add_child(_graphics_page())

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
	hint.text = "识别时：先推向标注正方向，再推到反方向，最后回中。"
	hint.custom_minimum_size.y = 38
	left.add_child(hint)
	for i in CONTROLS.size(): _add_channel(left, i)
	_add_section_title(left, "开关通道 · 全部通过识别完成")
	_add_aux_identify(left, "解锁", "arm")
	_add_aux_identify(left, "锁定", "disarm")
	_add_aux_identify(left, "重置飞机", "reset")
	_add_aux_identify(left, "切换相机", "camera")
	_add_aux_identify(left, "切换飞行模式", "flight_mode")
	progress = ProgressBar.new()
	progress.max_value = SAMPLE_SECONDS
	progress.show_percentage = false
	left.add_child(progress)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 450
	right.add_theme_constant_override("separation", 10)
	split.add_child(right)
	var state_title := Label.new()
	state_title.text = "控制状态 · 校准后请在这里确认方向"
	state_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_title.add_theme_font_size_override("font_size", 24)
	right.add_child(state_title)
	monitor = preload("res://demo/scripts/controller_monitor.gd").new()
	monitor.custom_minimum_size = Vector2(430, 255)
	right.add_child(monitor)
	var switch_grid := GridContainer.new()
	switch_grid.columns = 2
	right.add_child(switch_grid)
	for switch_item in [["arm", "解锁"], ["disarm", "锁定"], ["reset", "重置"], ["camera", "相机"], ["flight_mode", "飞行模式"]]:
		var switch_name := Label.new(); switch_name.text = String(switch_item[1]); switch_grid.add_child(switch_name)
		var switch_state := Label.new(); switch_state.text = "未触发"; switch_state.add_theme_color_override("font_color", Color("777777")); switch_grid.add_child(switch_state)
		aux_state_labels[String(switch_item[0])] = switch_state
	var verify_note := Label.new()
	verify_note.text = "拨动每个摇杆和开关，确认显示方向与实际操作一致。"
	verify_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(verify_note)
	var actions := VBoxContainer.new()
	right.add_child(actions)
	var all_button := Button.new()
	all_button.text = "依次校准四通道"
	all_button.custom_minimum_size.y = 52
	all_button.pressed.connect(_start_full_calibration)
	actions.add_child(all_button)
	var reset_button := Button.new()
	reset_button.text = "重置校准数据"
	reset_button.custom_minimum_size.y = 52
	reset_button.pressed.connect(_reset_defaults)
	actions.add_child(reset_button)
	return page

func _add_channel(parent: VBoxContainer, index: int) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _setting_card_style())
	parent.add_child(panel)
	var inset := MarginContainer.new()
	inset.add_theme_constant_override("margin_left", 12)
	inset.add_theme_constant_override("margin_right", 12)
	inset.add_theme_constant_override("margin_top", 5)
	inset.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(inset)
	var card := HBoxContainer.new()
	card.add_theme_constant_override("separation", 7)
	inset.add_child(card)
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
	var axis_display := Label.new()
	axis_display.name = "MappedAxis%d" % index
	axis_display.text = "AXIS-%d" % (int(InputProfile.mappings[String(CONTROLS[index])].axis) + 1)
	axis_display.custom_minimum_size.x = 90
	axis_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	axis_display.add_theme_color_override("font_color", Color("56c7ff"))
	card.add_child(axis_display)
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

func _add_aux_identify(parent: VBoxContainer, caption: String, action: String) -> void:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	parent.add_child(box)
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size.x = 180
	box.add_child(label)
	var channel := Label.new()
	channel.text = _aux_mapping_label(InputProfile.aux_buttons.get(action, {}))
	channel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	channel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	channel.add_theme_color_override("font_color", Color("f2c800"))
	box.add_child(channel)
	aux_labels[action] = channel
	var identify := Button.new()
	identify.text = "识别"
	identify.custom_minimum_size.x = 92
	identify.pressed.connect(_start_aux_sample.bind(action, caption))
	box.add_child(identify)
	buttons.append(identify)

func _add_section_title(parent: VBoxContainer, caption: String) -> void:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", Color("70b9ff"))
	parent.add_child(label)

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
	var page := _page("机体基础")
	var root := _content(page)
	var title := Label.new()
	title.text = "机体设置  ·  基础"
	title.add_theme_font_size_override("font_size", 27)
	root.add_child(title)
	var flight_header := Label.new()
	flight_header.text = "飞控"
	flight_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flight_header.add_theme_font_size_override("font_size", 22)
	root.add_child(flight_header)
	var rate_top := HBoxContainer.new()
	root.add_child(rate_top)
	var rate_label := Label.new()
	rate_label.text = "RATE 类型"
	rate_label.custom_minimum_size.x = 125
	rate_top.add_child(rate_label)
	var type_choice := OptionButton.new()
	var rate_names := ["Actual", "Betaflight", "Raceflight", "KISS"]
	for rate_name in rate_names: type_choice.add_item(rate_name)
	type_choice.select(maxi(0, rate_names.find(InputProfile.rate_type)))
	type_choice.item_selected.connect(_rate_type_index_changed.bind(rate_names))
	rate_top.add_child(type_choice)
	var flight_choice := OptionButton.new()
	for mode_name in ["Acro 手动模式", "Angle 自稳模式", "Altitude 定高模式"]: flight_choice.add_item(mode_name)
	flight_choice.select(maxi(0, ["Acro", "Angle", "Altitude"].find(InputProfile.flight_mode)))
	flight_choice.item_selected.connect(_flight_mode_changed.bind(flight_choice))
	rate_top.add_child(flight_choice)
	var rate_split := HBoxContainer.new()
	rate_split.add_theme_constant_override("separation", 18)
	root.add_child(rate_split)
	var table := VBoxContainer.new()
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rate_split.add_child(table)
	var heading := Label.new()
	heading.text = "轴       Center 灵敏度     Max Rate     Expo      FF 前馈"
	heading.add_theme_color_override("font_color", Color("dddddd"))
	table.add_child(heading)
	for axis_name in ["roll", "pitch", "yaw"]: _add_actual_row(table, axis_name)
	curve = preload("res://demo/scripts/rate_curve.gd").new()
	curve.custom_minimum_size = Vector2(430, 245)
	rate_split.add_child(curve)
	_add_profile_slider(root, "自稳灵敏度", "level", "sensitivity", 10.0, 100.0, float(InputProfile.level.sensitivity), "")
	_add_profile_slider(root, "角度限制", "level", "angle_limit", 15.0, 85.0, float(InputProfile.level.angle_limit), "°")
	_add_profile_slider(root, "电机怠速", "general", "motor_idle", 0.02, 0.12, InputProfile.motor_idle, "")
	var camera_header := Label.new()
	camera_header.text = "摄像头"
	camera_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	camera_header.add_theme_font_size_override("font_size", 22)
	root.add_child(camera_header)
	var camera_grid := GridContainer.new()
	camera_grid.columns = 2
	root.add_child(camera_grid)
	_add_number_input(camera_grid, "镜头仰角", "angle", -10, 55, float(InputProfile.camera.angle), "°")
	_add_number_input(camera_grid, "视野 FOV", "fov", 70, 150, float(InputProfile.camera.fov), "°")
	_add_number_input(camera_grid, "跟随距离", "follow_distance", 3.5, 14, float(InputProfile.camera.follow_distance), " m")
	_add_number_input(camera_grid, "跟随高度", "follow_height", 1.5, 8, float(InputProfile.camera.follow_height), " m")
	_add_number_input(camera_grid, "目视距离", "los_distance", 4, 14, float(InputProfile.camera.los_distance), " m")
	_add_number_input(camera_grid, "目视高度", "los_height", 1.5, 8, float(InputProfile.camera.los_height), " m")
	return page

func _add_color_palette(parent: Control, caption: String, part: String) -> void:
	var row := HBoxContainer.new(); parent.add_child(row)
	var label := Label.new(); label.text = caption; label.custom_minimum_size.x = 100; row.add_child(label)
	for color_hex in ["7d5cff", "ff2d7d", "18b7ff", "18d775", "ffb312", "f4f4f4", "24262c"]:
		var swatch := Button.new()
		swatch.text = "■"
		swatch.custom_minimum_size = Vector2(58, 38)
		swatch.add_theme_font_size_override("font_size", 25)
		swatch.add_theme_color_override("font_color", Color(color_hex))
		swatch.pressed.connect(_color_changed.bind(part, color_hex))
		row.add_child(swatch)

func _add_compact_setting(parent: HBoxContainer, caption: String, group: String, key: String, minimum: float, maximum: float, value: float) -> void:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	var label := Label.new()
	label.text = caption
	box.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = 0.01
	spin.value = value
	spin.value_changed.connect(_compact_changed.bind(group, key))
	box.add_child(spin)

func _compact_changed(value: float, group: String, key: String) -> void:
	if group == "level":
		InputProfile.level[key] = value
		InputProfile.save_profile()
		InputProfile.profile_changed.emit()
	else:
		InputProfile.set_general_value(key, value)

func _physics_page() -> VBoxContainer:
	var page := _page("物理")
	var body := _content(page)
	var help := Label.new()
	help.text = "电机响应速度与最大输出分别计算。推荐从 420 g / 2700 KV / 56% 输出开始，再按机型微调。"
	help.add_theme_font_size_override("font_size", 20)
	body.add_child(help)
	var physics_grid := GridContainer.new()
	physics_grid.columns = 2
	physics_grid.add_theme_constant_override("h_separation", 12)
	physics_grid.add_theme_constant_override("v_separation", 10)
	body.add_child(physics_grid)
	_add_profile_slider(physics_grid, "机体重量", "physics", "mass", 0.20, 1.50, float(InputProfile.physics.mass), " kg")
	_add_profile_slider(physics_grid, "重力倍率", "physics", "gravity", 0.80, 1.60, float(InputProfile.physics.gravity), " x")
	_add_profile_slider(physics_grid, "总推力倍率", "physics", "thrust", 0.50, 1.80, float(InputProfile.physics.thrust), " x")
	_add_profile_slider(physics_grid, "低速阻力", "physics", "drag_low", 0.0, 0.20, float(InputProfile.physics.drag_low), "")
	_add_profile_slider(physics_grid, "高速阻力", "physics", "drag_high", 0.02, 0.60, float(InputProfile.physics.drag_high), "")
	_add_profile_slider(physics_grid, "空气乱流", "physics", "turbulence", 0.0, 2.0, float(InputProfile.physics.turbulence), "")
	_add_profile_slider(physics_grid, "电机 KV", "physics", "motor_kv", 1200.0, 4200.0, float(InputProfile.physics.motor_kv), " KV")
	_add_profile_slider(physics_grid, "电池电压", "physics", "voltage", 7.4, 25.2, float(InputProfile.physics.voltage), " V")
	_add_profile_slider(physics_grid, "慢动作倍率", "general", "slow_motion", 0.2, 1.0, InputProfile.slow_motion, " x")
	_add_profile_slider(physics_grid, "电机最大输出", "output", "motor_output_limit", 0.30, 1.0, InputProfile.motor_output_limit, "")
	_add_section_title(body, "预设")
	var presets := HBoxContainer.new()
	body.add_child(presets)
	_add_physics_preset(presets, "足球机 420 g", 0.42, 2700.0, 1.0, 0.56)
	_add_physics_preset(presets, "竞速机 650 g", 0.65, 2450.0, 1.05, 0.66)
	_add_physics_preset(presets, "训练机 500 g", 0.50, 2200.0, 0.95, 0.50)
	return page

func _graphics_page() -> VBoxContainer:
	var page := _page("画质与 OSD")
	var body := _content(page)
	_add_section_title(body, "图形设置")
	_add_choice(body, "画质预设", ["性能（低配置）", "均衡", "高清", "超清"], int(InputProfile.graphics.quality), _quality_changed)
	_add_profile_slider(body, "渲染比例", "graphics", "render_scale", 0.50, 1.50, float(InputProfile.graphics.render_scale), " x")
	_add_dict_toggle(body, "垂直同步 VSync（关闭可降低操作延迟）", "graphics", "vsync")
	_add_dict_toggle(body, "动态阴影", "graphics", "shadows")
	_add_dict_toggle(body, "辉光 Glow", "graphics", "glow")
	_add_section_title(body, "OSD 屏幕显示")
	_add_profile_slider(body, "OSD 比例", "osd", "scale", 0.70, 1.60, float(InputProfile.osd.scale), " x")
	for item in [["显示全部 OSD", "visible"], ["摇杆视图", "sticks"], ["速度", "speed"], ["高度", "altitude"], ["飞行模式", "flight_mode"], ["相机模式", "camera_mode"], ["镜头仰角", "camera_angle"], ["中心点", "reticle"], ["帧数 FPS", "fps"]]:
		_add_dict_toggle(body, String(item[0]), "osd", String(item[1]))
	return page

func _add_choice(parent: Control, caption: String, labels: Array, selected: int, callback: Callable) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new(); label.text = caption; label.custom_minimum_size.x = 260; row.add_child(label)
	var choice := OptionButton.new()
	for option in labels: choice.add_item(String(option))
	choice.select(clampi(selected, 0, labels.size() - 1))
	choice.item_selected.connect(callback)
	row.add_child(choice)

func _add_dict_toggle(parent: Control, caption: String, group: String, key: String) -> void:
	var toggle := CheckButton.new()
	toggle.text = caption
	var settings: Dictionary = InputProfile.get(group)
	toggle.button_pressed = bool(settings.get(key, false))
	toggle.toggled.connect(_dict_toggle_changed.bind(group, key))
	parent.add_child(toggle)

func _add_physics_preset(parent: Control, caption: String, mass_value: float, kv: float, thrust_value: float, output_value: float) -> void:
	var button := Button.new(); button.text = caption
	button.pressed.connect(_physics_preset.bind(mass_value, kv, thrust_value, output_value))
	parent.add_child(button)

func _add_profile_slider(parent: Control, caption: String, group: String, key: String, minimum: float, maximum: float, value: float, suffix: String) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _setting_card_style())
	parent.add_child(card)
	var inset := MarginContainer.new()
	for side in ["margin_left", "margin_right"]: inset.add_theme_constant_override(side, 16)
	inset.add_theme_constant_override("margin_top", 5)
	inset.add_theme_constant_override("margin_bottom", 5)
	card.add_child(inset)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	inset.add_child(row)
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size.x = 190
	row.add_child(label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var input := SpinBox.new()
	input.min_value = minimum
	input.max_value = maximum
	input.step = 1.0 if maximum - minimum > 100.0 else 0.01
	input.value = value
	input.suffix = suffix
	input.custom_minimum_size = Vector2(190, 40)
	input.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(input)
	input.value_changed.connect(_profile_input_changed.bind(group, key))

func _add_number_input(parent: Control, caption: String, key: String, minimum: float, maximum: float, value: float, suffix: String) -> void:
	var card := PanelContainer.new(); card.add_theme_stylebox_override("panel", _setting_card_style()); parent.add_child(card)
	var inset := MarginContainer.new(); inset.add_theme_constant_override("margin_left", 14); inset.add_theme_constant_override("margin_right", 14); inset.add_theme_constant_override("margin_top", 5); inset.add_theme_constant_override("margin_bottom", 5); card.add_child(inset)
	var row := HBoxContainer.new(); row.custom_minimum_size.x = 360; inset.add_child(row)
	var label := Label.new(); label.text = caption; label.custom_minimum_size.x = 150; row.add_child(label)
	var input := SpinBox.new(); input.min_value = minimum; input.max_value = maximum; input.step = 0.1; input.value = value; input.suffix = suffix; input.custom_minimum_size = Vector2(170, 42); row.add_child(input)
	input.value_changed.connect(_camera_number_changed.bind(key))

func _setting_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.105, 0.11, 0.122, 0.88)
	style.border_color = Color(0.32, 0.33, 0.35, 0.62)
	style.set_border_width_all(1)
	style.set_corner_radius_all(11)
	return style

func _camera_number_changed(value: float, key: String) -> void:
	InputProfile.set_camera_value(key, value)

func _profile_input_changed(value: float, group: String, key: String) -> void:
	if group == "physics": InputProfile.set_physics_value(key, value)
	elif group == "level":
		InputProfile.level[key] = value; InputProfile.save_profile(); InputProfile.profile_changed.emit()
	elif group == "graphics" or group == "osd":
		var settings: Dictionary = InputProfile.get(group)
		settings[key] = value; InputProfile.set(group, settings); InputProfile.save_profile(); InputProfile.profile_changed.emit()
	else: InputProfile.set_general_value(key, value)

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
		InputProfile.device_id = id if InputProfile.device_id not in ids else InputProfile.device_id
		var detected_name := Input.get_joy_name(id).strip_edges()
		if detected_name.is_empty() or detected_name == "Unknown": detected_name = "USB 遥控器 · " + Input.get_joy_guid(id).left(8)
		device.add_item("%d: %s" % [id, detected_name], id)
		if id == InputProfile.device_id: device.select(device.item_count - 1)
func _select_device(index: int) -> void:
	InputProfile.device_id = device.get_item_id(index)
	InputProfile.save_profile()
func _update_live() -> void:
	for i in CONTROLS.size():
		var map: Dictionary = InputProfile.mappings[String(CONTROLS[i])]
		bars[i].value = InputProfile.value(CONTROLS[i]) * 100.0
		values[i].text = "AXIS-%d  %+.0f" % [int(map.axis) + 1, bars[i].value]
	for action in aux_state_labels:
		var active := _aux_mapping_active(InputProfile.aux_buttons.get(action, {}))
		aux_state_labels[action].text = "已触发" if active else "未触发"
		aux_state_labels[action].add_theme_color_override("font_color", Color("f2b705") if active else Color("777777"))
	if monitor: monitor.queue_redraw()

func _aux_mapping_active(mapping: Variant) -> bool:
	if not mapping is Dictionary: return false
	var map: Dictionary = mapping
	var index := int(map.get("index", -1))
	if index < 0: return false
	if String(map.get("type", "")) == "button": return Input.is_joy_button_pressed(InputProfile.device_id, index)
	if String(map.get("type", "")) == "axis":
		var raw := InputProfile.raw_axis(index)
		return raw >= float(map.get("threshold", 0.0)) if bool(map.get("active_high", true)) else raw <= float(map.get("threshold", 0.0))
	return false
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
	hint.text = "识别【%s】：先%s，再推到反方向，最后回中。" % [LABELS[index], POSITIVE_DIRECTIONS[index]]
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
	else:
		# Reject a bad final sample instead of creating asymmetric, drifting sticks.
		var midpoint := (minima[best_axis] + maxima[best_axis]) * 0.5
		if absf(center - midpoint) > best_range * 0.20: center = midpoint
	InputProfile.set_mapping(CONTROLS[current], best_axis, minima[best_axis], center, maxima[best_axis], invert)
	var mapped_label := get_tree().current_scene.find_child("MappedAxis%d" % current, true, false) as Label
	if mapped_label: mapped_label.text = "AXIS-%d" % (best_axis + 1)
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
	InputProfile.set_general_value("rate_type", choice.get_item_text(index).get_slice(" ", 0))
func _rate_type_index_changed(index: int, names: Array) -> void:
	InputProfile.set_general_value("rate_type", String(names[index]))
func _camera_mode_changed(index: int, choice: OptionButton) -> void:
	InputProfile.set_general_value("camera_mode", choice.get_item_text(index))
	game.set_camera_mode(InputProfile.camera_mode)
func _flight_mode_changed(index: int, choice: OptionButton) -> void:
	InputProfile.set_general_value("flight_mode", choice.get_item_text(index).get_slice(" ", 0))
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
	elif group == "graphics" or group == "osd":
		var settings: Dictionary = InputProfile.get(group)
		settings[key] = value
		InputProfile.set(group, settings)
		InputProfile.save_profile()
		InputProfile.profile_changed.emit()
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

func _add_component_toggle(parent: Control, caption: String, key: String) -> void:
	var toggle := CheckButton.new()
	toggle.text = caption
	toggle.button_pressed = bool(InputProfile.components.get(key, false))
	toggle.toggled.connect(_component_changed.bind(key))
	parent.add_child(toggle)

func _component_changed(enabled: bool, key: String) -> void:
	InputProfile.components[key] = enabled
	InputProfile.save_profile()
	InputProfile.profile_changed.emit()

func _start_aux_sample(action: String, caption: String) -> void:
	if sampling or aux_sampling: return
	current_aux = action
	aux_sampling = true
	aux_baseline.resize(RAW_AXIS_COUNT)
	for axis_index in RAW_AXIS_COUNT: aux_baseline[axis_index] = InputProfile.raw_axis(axis_index)
	for button in buttons: button.disabled = true
	hint.text = "识别【%s】：请把遥控器开关拨到另一个位置。支持 AXIS 通道和按键。" % caption

func _aux_mapping_label(mapping: Variant) -> String:
	if not mapping is Dictionary: return "未识别"
	var map: Dictionary = mapping
	var index := int(map.get("index", -1))
	if index < 0: return "未识别"
	return ("AXIS-%d" if String(map.get("type", "")) == "axis" else "BUTTON-%d") % (index + 1)

func _dict_toggle_changed(enabled: bool, group: String, key: String) -> void:
	var settings: Dictionary = InputProfile.get(group)
	settings[key] = enabled
	InputProfile.set(group, settings)
	InputProfile.save_profile()
	InputProfile.profile_changed.emit()

func _quality_changed(index: int) -> void:
	InputProfile.graphics["quality"] = index
	# Each preset changes real renderer options; users can still override them below.
	InputProfile.graphics["render_scale"] = [0.60, 0.85, 1.15, 1.50][index]
	InputProfile.graphics["anti_aliasing"] = [0, 1, 2, 3][index]
	InputProfile.graphics["shadows"] = index >= 1
	InputProfile.graphics["glow"] = index >= 2
	InputProfile.graphics["ssao"] = index >= 2
	InputProfile.save_profile()
	InputProfile.profile_changed.emit()
	hint.text = "画质预设已即时应用；重新打开设置可查看对应数值"

func _physics_preset(mass_value: float, kv: float, thrust_value: float, output_value: float) -> void:
	InputProfile.physics["mass"] = mass_value
	InputProfile.physics["motor_kv"] = kv
	InputProfile.physics["thrust"] = thrust_value
	InputProfile.motor_output_limit = output_value
	InputProfile.save_profile()
	InputProfile.profile_changed.emit()
	hint.text = "物理预设已即时应用"

func _color_changed(part: String, color_hex: String) -> void:
	InputProfile.colors[part] = color_hex
	InputProfile.save_profile()
	InputProfile.profile_changed.emit()

func _on_joy_connection_changed(_id: int, _connected: bool) -> void:
	if visible: call_deferred("_refresh_devices")

func _reference_theme() -> Theme:
	var theme := Theme.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.085, 0.085, 0.095, 0.96)
	panel_style.border_color = Color("34363b")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(16)
	panel_style.shadow_color = Color(0, 0, 0, 0.42)
	panel_style.shadow_size = 18
	theme.set_stylebox("panel", "PanelContainer", panel_style)
	var button_style := StyleBoxFlat.new()
	button_style.bg_color = Color("242424")
	button_style.border_color = Color("45474c")
	button_style.set_border_width_all(1)
	button_style.set_corner_radius_all(9)
	button_style.content_margin_left = 14
	button_style.content_margin_right = 14
	button_style.content_margin_top = 9
	button_style.content_margin_bottom = 9
	theme.set_stylebox("normal", "Button", button_style)
	var hover_style := button_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color("d99f00")
	hover_style.border_color = Color("ffc21a")
	theme.set_stylebox("hover", "Button", hover_style)
	var pressed_style := hover_style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color("b88400")
	theme.set_stylebox("pressed", "Button", pressed_style)
	var toggle_style := button_style.duplicate() as StyleBoxFlat
	toggle_style.bg_color = Color("1b1d21")
	toggle_style.border_color = Color("383b40")
	theme.set_stylebox("normal", "CheckButton", toggle_style)
	theme.set_stylebox("hover", "CheckButton", toggle_style)
	theme.set_stylebox("pressed", "CheckButton", toggle_style)
	var field_style := StyleBoxFlat.new()
	field_style.bg_color = Color("17191d")
	field_style.border_color = Color("45484e")
	field_style.set_border_width_all(1)
	field_style.set_corner_radius_all(9)
	field_style.content_margin_left = 12
	field_style.content_margin_right = 12
	field_style.content_margin_top = 8
	field_style.content_margin_bottom = 8
	theme.set_stylebox("normal", "LineEdit", field_style)
	theme.set_stylebox("normal", "OptionButton", field_style)
	var tab_selected := StyleBoxFlat.new()
	tab_selected.bg_color = Color("24262a")
	tab_selected.border_color = Color("f2b705")
	tab_selected.border_width_bottom = 3
	tab_selected.set_corner_radius_all(7)
	tab_selected.content_margin_left = 18
	tab_selected.content_margin_right = 18
	tab_selected.content_margin_top = 10
	tab_selected.content_margin_bottom = 10
	var tab_unselected := tab_selected.duplicate() as StyleBoxFlat
	tab_unselected.bg_color = Color("151619")
	tab_unselected.border_width_bottom = 0
	theme.set_stylebox("tab_selected", "TabBar", tab_selected)
	theme.set_stylebox("tab_unselected", "TabBar", tab_unselected)
	theme.set_stylebox("tab_hovered", "TabBar", tab_unselected)
	var slider_track := StyleBoxFlat.new()
	slider_track.bg_color = Color("5a4a12")
	slider_track.set_corner_radius_all(5)
	slider_track.content_margin_top = 5
	slider_track.content_margin_bottom = 5
	theme.set_stylebox("slider", "HSlider", slider_track)
	var slider_fill := StyleBoxFlat.new()
	slider_fill.bg_color = Color("f2b705")
	slider_fill.set_corner_radius_all(5)
	slider_fill.content_margin_top = 5
	slider_fill.content_margin_bottom = 5
	theme.set_stylebox("grabber_area", "HSlider", slider_fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", slider_fill)
	theme.set_color("font_color", "Label", Color("e8e8e8"))
	theme.set_color("font_color", "Button", Color("f3f3f3"))
	theme.set_color("font_color", "OptionButton", Color("f3f3f3"))
	theme.set_color("font_color", "SpinBox", Color("f2c800"))
	theme.set_font_size("font_size", "Label", 16)
	theme.set_font_size("font_size", "Button", 16)
	theme.set_constant("separation", "VBoxContainer", 12)
	theme.set_constant("separation", "HBoxContainer", 12)
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
