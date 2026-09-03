extends CanvasLayer
const CONTROLS := [&"throttle", &"yaw", &"pitch", &"roll"]
const LABELS := ["油门 THR", "偏航 YAW", "俯仰 PIT", "横滚 ROL"]
const SAMPLE_SECONDS := 4.0
@export var game_path: NodePath
var game: Node
var device: OptionButton
var hint: Label
var sample_progress: ProgressBar
var row_bars: Array[ProgressBar] = []
var row_values: Array[Label] = []
var row_buttons: Array[Button] = []
var current := -1
var sampling := false
var sample_time := 0.0
var baseline: Array[float] = []
var minima: Array[float] = []
var maxima: Array[float] = []
func _ready() -> void:
	game = get_node(game_path)
	layer = 20
	_build_ui()
	visible = false
func _process(delta: float) -> void:
	_update_live_rows()
	if not sampling: return
	sample_time += delta
	for axis in 8:
		var raw := InputProfile.raw_axis(axis)
		minima[axis] = minf(minima[axis], raw)
		maxima[axis] = maxf(maxima[axis], raw)
	sample_progress.value = sample_time
	if sample_time >= SAMPLE_SECONDS: _finish_sample()
func _build_ui() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.018, 0.035, 0.05, 0.96)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-430, -350)
	panel.size = Vector2(860, 700)
	shade.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 13)
	margin.add_child(column)
	var title := Label.new()
	title.text = "遥控器通道校准"
	title.add_theme_font_size_override("font_size", 30)
	column.add_child(title)
	device = OptionButton.new()
	device.item_selected.connect(_select_device)
	column.add_child(device)
	hint = Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.y = 55
	column.add_child(hint)
	for i in CONTROLS.size(): _add_channel_row(column, i)
	sample_progress = ProgressBar.new()
	sample_progress.max_value = SAMPLE_SECONDS
	sample_progress.show_percentage = false
	column.add_child(sample_progress)
	var rate_title := Label.new()
	rate_title.text = "Betaflight Acro 参数"
	rate_title.add_theme_font_size_override("font_size", 18)
	column.add_child(rate_title)
	var rate_help := Label.new()
	rate_help.text = "RC Rate 基础转速 · Super Rate 杆端加速 · Expo 中心柔和 · Output 最大动力"
	rate_help.add_theme_color_override("font_color", Color("8eb7c6"))
	column.add_child(rate_help)
	var rate_row := HBoxContainer.new()
	rate_row.add_theme_constant_override("separation", 12)
	column.add_child(rate_row)
	_add_setting(rate_row, "RC RATE", 0.2, 2.5, 0.01, InputProfile.bf_rc_rate, "bf_rc_rate")
	_add_setting(rate_row, "SUPER", 0.0, 0.95, 0.01, InputProfile.bf_super_rate, "bf_super_rate")
	_add_setting(rate_row, "EXPO", 0.0, 1.0, 0.01, InputProfile.bf_rate_expo, "bf_rate_expo")
	_add_setting(rate_row, "OUTPUT", 0.2, 0.8, 0.01, InputProfile.motor_output_limit, "motor_output_limit")
	var close := Button.new()
	close.text = "保存并返回训练"
	close.custom_minimum_size.y = 48
	close.pressed.connect(close_ui)
	column.add_child(close)
func _add_channel_row(parent: VBoxContainer, index: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var channel := Label.new()
	channel.text = LABELS[index]
	channel.custom_minimum_size.x = 115
	row.add_child(channel)
	var bar := ProgressBar.new()
	bar.min_value = -100
	bar.max_value = 100
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(350, 34)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bar)
	row_bars.append(bar)
	var value_label := Label.new()
	value_label.custom_minimum_size.x = 130
	row.add_child(value_label)
	row_values.append(value_label)
	var button := Button.new()
	button.text = "单独校准"
	button.custom_minimum_size = Vector2(105, 38)
	button.pressed.connect(_start_sample.bind(index))
	row.add_child(button)
	row_buttons.append(button)
func _add_setting(parent: HBoxContainer, caption: String, minimum: float, maximum: float, step: float, value: float, property: String) -> void:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	var label := Label.new()
	label.text = caption
	box.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.value = value
	spin.value_changed.connect(_setting_changed.bind(property))
	box.add_child(spin)
func open() -> void:
	visible = true
	game.set_input_blocked(true)
	_refresh_devices()
	hint.text = "通道条实时显示 -100% 到 +100%。点击右侧按钮可单独校准任意通道。"
	sample_progress.value = 0
func close_ui() -> void:
	sampling = false
	visible = false
	InputProfile.save_profile()
	game.set_input_blocked(false)
	game.set_status("遥控器与 BF Rate 参数已保存")
func _refresh_devices() -> void:
	device.clear()
	var ids := InputProfile.connected_devices()
	if ids.is_empty():
		device.add_item("未检测到 USB 遥控器", -1)
		for button in row_buttons: button.disabled = true
		return
	for button in row_buttons: button.disabled = false
	for id in ids:
		device.add_item(Input.get_joy_name(id), id)
		if id == InputProfile.device_id: device.select(device.item_count - 1)
func _select_device(index: int) -> void:
	InputProfile.device_id = device.get_item_id(index)
	InputProfile.save_profile()
func _update_live_rows() -> void:
	if not visible: return
	for i in CONTROLS.size():
		var map: Dictionary = InputProfile.mappings[String(CONTROLS[i])]
		row_bars[i].value = InputProfile.value(CONTROLS[i]) * 100.0
		row_values[i].text = "轴 %d  %+.0f%%" % [int(map.axis), row_bars[i].value]
func _start_sample(index: int) -> void:
	if sampling: return
	current = index
	sampling = true
	sample_time = 0.0
	sample_progress.value = 0
	baseline.resize(8)
	minima.resize(8)
	maxima.resize(8)
	for axis in 8:
		baseline[axis] = InputProfile.raw_axis(axis)
		minima[axis] = baseline[axis]
		maxima[axis] = baseline[axis]
	for button in row_buttons: button.disabled = true
	var motion := "最低 → 最高 → 最低" if index == 0 else "两端完整移动，然后回到中位"
	hint.text = "正在校准【%s】：%s。此时不要动其他通道。" % [LABELS[index], motion]
func _finish_sample() -> void:
	sampling = false
	var best_axis := 0
	var best_range := 0.0
	for axis in 8:
		var travel := maxima[axis] - minima[axis]
		if travel > best_range:
			best_range = travel
			best_axis = axis
	for button in row_buttons: button.disabled = false
	if best_range < 0.65:
		hint.text = "【%s】行程不足，请重新校准并推满两端。" % LABELS[current]
		return
	var center := InputProfile.raw_axis(best_axis)
	var invert := current in [0, 2]
	if current == 0:
		center = (minima[best_axis] + maxima[best_axis]) * 0.5
		invert = baseline[best_axis] > center
	InputProfile.set_mapping(CONTROLS[current], best_axis, minima[best_axis], center, maxima[best_axis], invert)
	hint.text = "【%s】完成：轴 %d，检测到 %.0f%% 完整行程。" % [LABELS[current], best_axis, best_range * 50.0]
func _setting_changed(value: float, property: String) -> void:
	InputProfile.set(property, value)
	InputProfile.save_profile()
