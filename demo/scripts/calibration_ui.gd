extends CanvasLayer

const CONTROLS := [&"throttle", &"yaw", &"pitch", &"roll"]
const LABELS := ["油门", "偏航", "俯仰", "横滚"]

@export var game_path: NodePath
var game: Node
var panel: PanelContainer
var title: Label
var hint: Label
var device: OptionButton
var progress: ProgressBar
var primary: Button
var current := -1
var sampling := false
var sample_time := 0.0
var baseline: Array[float] = []
var minima: Array[float] = []
var maxima: Array[float] = []
var finished := false


func _ready() -> void:
	game = get_node(game_path)
	layer = 20
	_build_ui()
	visible = false


func _process(delta: float) -> void:
	if not sampling:
		return
	sample_time += delta
	for axis in 8:
		var raw := InputProfile.raw_axis(axis)
		minima[axis] = min(minima[axis], raw)
		maxima[axis] = max(maxima[axis], raw)
	progress.value = sample_time
	if sample_time >= 3.5:
		_finish_sample()


func _build_ui() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.025, 0.045, 0.06, 0.94)
	add_child(shade)
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-330, -240)
	panel.size = Vector2(660, 480)
	shade.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 38)
	margin.add_theme_constant_override("margin_right", 38)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_bottom", 34)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 22)
	margin.add_child(column)
	title = Label.new()
	title.text = "遥控器校准"
	title.add_theme_font_size_override("font_size", 32)
	column.add_child(title)
	device = OptionButton.new()
	device.item_selected.connect(_select_device)
	column.add_child(device)
	hint = Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.y = 150
	hint.add_theme_font_size_override("font_size", 20)
	column.add_child(hint)
	progress = ProgressBar.new()
	progress.max_value = 3.5
	progress.show_percentage = false
	column.add_child(progress)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	column.add_child(buttons)
	var close := Button.new()
	close.text = "稍后校准"
	close.pressed.connect(close_ui)
	buttons.add_child(close)
	primary = Button.new()
	primary.text = "开始校准"
	primary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	primary.pressed.connect(_next)
	buttons.add_child(primary)


func open() -> void:
	visible = true
	game.set_input_blocked(true)
	current = -1
	finished = false
	_refresh_devices()
	hint.text = "请将遥控器通过 USB 连接电脑，并确认系统将它识别为游戏控制器。校准会依次识别四个主通道。"
	primary.text = "开始校准"
	primary.disabled = false
	progress.value = 0


func close_ui() -> void:
	sampling = false
	visible = false
	game.set_input_blocked(false)
	game.set_status("遥控器配置已保存")


func _refresh_devices() -> void:
	device.clear()
	var ids := InputProfile.connected_devices()
	if ids.is_empty():
		device.add_item("未检测到 USB 遥控器", -1)
		primary.disabled = true
		return
	primary.disabled = false
	for id in ids:
		device.add_item(Input.get_joy_name(id), id)
		if id == InputProfile.device_id:
			device.select(device.item_count - 1)


func _select_device(index: int) -> void:
	InputProfile.device_id = device.get_item_id(index)
	InputProfile.save_profile()


func _next() -> void:
	if finished:
		close_ui()
		return
	if sampling:
		return
	current += 1
	if current >= CONTROLS.size():
		hint.text = "四个主通道已经完成校准。配置会自动保存在本机，下次启动直接使用。"
		primary.text = "完成并进入训练"
		finished = true
		return
	_start_sample()


func _start_sample() -> void:
	sampling = true
	sample_time = 0.0
	progress.value = 0
	baseline.resize(8)
	minima.resize(8)
	maxima.resize(8)
	for axis in 8:
		baseline[axis] = InputProfile.raw_axis(axis)
		minima[axis] = baseline[axis]
		maxima[axis] = baseline[axis]
	hint.text = "正在识别【%s】通道：请在 3 秒内把对应摇杆从最小推到最大，再回到中位。只移动这一个方向。" % LABELS[current]
	primary.disabled = true


func _finish_sample() -> void:
	sampling = false
	var best_axis := 0
	var best_range := 0.0
	for axis in 8:
		var axis_range := maxima[axis] - minima[axis]
		if axis_range > best_range:
			best_range = axis_range
			best_axis = axis
	if best_range < 0.65:
		hint.text = "没有检测到足够的摇杆运动，请重新移动【%s】通道的完整行程。" % LABELS[current]
		current -= 1
	else:
		var center := InputProfile.raw_axis(best_axis)
		var invert := current in [0, 2]
		if current == 0:
			center = (minima[best_axis] + maxima[best_axis]) * 0.5
			invert = baseline[best_axis] > center
		InputProfile.set_mapping(
			CONTROLS[current], best_axis, minima[best_axis], center, maxima[best_axis], invert
		)
		hint.text = "已识别【%s】为轴 %d，行程 %.2f。点击继续。" % [LABELS[current], best_axis, best_range]
	primary.disabled = false
	primary.text = "继续"
