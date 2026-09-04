extends CanvasLayer
const CONTROLS := [&"roll", &"pitch", &"yaw", &"throttle"]
const LABELS := ["ROLL 横滚", "PITCH 俯仰", "YAW 偏航", "THROTTLE 油门"]
const SAMPLE_SECONDS := 4.0
@export var game_path: NodePath
var game: Node
var device: OptionButton
var hint: Label
var progress: ProgressBar
var bars: Array[ProgressBar] = []
var values: Array[Label] = []
var buttons: Array[Button] = []
var curve: Control
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
	if visible: _update_live()
	if not sampling: return
	sample_time += delta
	for axis in 8:
		var raw: float = InputProfile.raw_axis(axis)
		minima[axis] = minf(minima[axis], raw)
		maxima[axis] = maxf(maxima[axis], raw)
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
	panel.size = Vector2(1140, 780)
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
	tabs.add_child(_rate_page())
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
	page.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)
	return page

func _content(page: VBoxContainer) -> VBoxContainer:
	return page.get_child(0).get_child(0) as VBoxContainer

func _controller_page() -> VBoxContainer:
	var page := _page("遥控器")
	var body := _content(page)
	device = OptionButton.new()
	device.custom_minimum_size.y = 46
	device.item_selected.connect(_select_device)
	body.add_child(device)
	hint = Label.new()
	hint.text = "实时查看通道行程；每个通道可单独识别。校准时只移动指定摇杆。"
	hint.custom_minimum_size.y = 42
	body.add_child(hint)
	for i in CONTROLS.size(): _add_channel(body, i)
	progress = ProgressBar.new()
	progress.max_value = SAMPLE_SECONDS
	progress.show_percentage = false
	body.add_child(progress)
	var raw_title := Label.new()
	raw_title.text = "控制器原始输入（AXIS 0—7）"
	raw_title.add_theme_font_size_override("font_size", 18)
	body.add_child(raw_title)
	var raw_grid := GridContainer.new()
	raw_grid.name = "RawGrid"
	raw_grid.columns = 4
	body.add_child(raw_grid)
	for axis in 8:
		var label := Label.new()
		label.name = "Axis%d" % axis
		label.text = "AXIS-%d   0.000" % axis
		label.custom_minimum_size.x = 230
		raw_grid.add_child(label)
	return page

func _add_channel(parent: VBoxContainer, index: int) -> void:
	var card := HBoxContainer.new()
	card.add_theme_constant_override("separation", 12)
	parent.add_child(card)
	var label := Label.new()
	label.text = LABELS[index]
	label.custom_minimum_size.x = 155
	card.add_child(label)
	var bar := ProgressBar.new()
	bar.min_value = -100
	bar.max_value = 100
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(430, 38)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(bar)
	bars.append(bar)
	var value := Label.new()
	value.custom_minimum_size.x = 145
	card.add_child(value)
	values.append(value)
	var invert := CheckButton.new()
	invert.text = "反向"
	invert.button_pressed = bool(InputProfile.mappings[String(CONTROLS[index])].invert)
	invert.toggled.connect(_invert_changed.bind(index))
	card.add_child(invert)
	var identify := Button.new()
	identify.text = "识别/校准"
	identify.custom_minimum_size.x = 115
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
	help.add_theme_font_size_override("font_size", 22)
	body.add_child(help)
	_add_profile_slider(body, "FPV 镜头仰角", "camera", "angle", -10, 55, float(InputProfile.camera.angle), "°")
	_add_profile_slider(body, "FPV 视野 FOV", "camera", "fov", 70, 150, float(InputProfile.camera.fov), "°")
	_add_profile_slider(body, "跟随距离", "camera", "follow_distance", 4, 18, float(InputProfile.camera.follow_distance), " m")
	_add_profile_slider(body, "跟随高度", "camera", "follow_height", 1.5, 10, float(InputProfile.camera.follow_height), " m")
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
	var grid := device.get_parent().get_node("RawGrid") as GridContainer
	for axis in 8:
		var label := grid.get_node("Axis%d" % axis) as Label
		label.text = "AXIS-%d   %+.3f" % [axis, InputProfile.raw_axis(axis)]
func _start_sample(index: int) -> void:
	if sampling: return
	current = index
	sampling = true
	sample_time = 0.0
	progress.value = 0
	baseline.resize(8); minima.resize(8); maxima.resize(8)
	for axis in 8:
		baseline[axis] = InputProfile.raw_axis(axis)
		minima[axis] = baseline[axis]
		maxima[axis] = baseline[axis]
	for button in buttons: button.disabled = true
	hint.text = "识别【%s】：请推满两端并返回中位；油门请最低→最高→最低。" % LABELS[index]
func _finish_sample() -> void:
	sampling = false
	var best_axis := 0
	var best_range := 0.0
	for axis in 8:
		var travel: float = maxima[axis] - minima[axis]
		if travel > best_range: best_range = travel; best_axis = axis
	for button in buttons: button.disabled = false
	if best_range < 0.65:
		hint.text = "行程不足，请重新识别并推满。"
		return
	var center: float = InputProfile.raw_axis(best_axis)
	var invert: bool = bool(InputProfile.mappings[String(CONTROLS[current])].invert)
	if CONTROLS[current] == &"throttle":
		center = (minima[best_axis] + maxima[best_axis]) * 0.5
		invert = baseline[best_axis] > center
	InputProfile.set_mapping(CONTROLS[current], best_axis, minima[best_axis], center, maxima[best_axis], invert)
	hint.text = "完成：%s = AXIS-%d，检测行程 %.0f%%。" % [LABELS[current], best_axis, best_range * 50.0]
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
func _profile_changed(value: float, group: String, key: String, number: Label, suffix: String) -> void:
	number.text = "%.2f%s" % [value, suffix]
	if group == "physics": InputProfile.set_physics_value(key, value)
	elif group == "camera": InputProfile.set_camera_value(key, value)
	else:
		InputProfile.set(key, value)
		InputProfile.save_profile()
		InputProfile.profile_changed.emit()
