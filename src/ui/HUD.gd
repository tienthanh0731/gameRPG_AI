class_name HUD
extends CanvasLayer

@onready var health_bar: ProgressBar = $LeftPanel/MarginContainer/VBoxContainer/HealthBar
@onready var stamina_bar: ProgressBar = $LeftPanel/MarginContainer/VBoxContainer/StaminaBar
@onready var temp_label: Label = $LeftPanel/MarginContainer/VBoxContainer/TempLabel
@onready var biome_label: Label = $TopPanel/MarginContainer/VBoxContainer/BiomeLabel
@onready var time_label: Label = $TopPanel/MarginContainer/VBoxContainer/TimeLabel
@onready var phase_label: Label = $TopPanel/MarginContainer/VBoxContainer/PhaseLabel
@onready var tool_label: Label = $BottomPanel/ToolLabel

func _process(_delta: float) -> void:
	# Update active tool indicator from player if available
	var player = get_tree().get_first_node_in_group("player")
	if player and tool_label:
		match player.current_tool:
			0: tool_label.text = "[Phím 1] Đang cầm: RÌU ĐỐN CỦI (Click chuột trái để chặt cây)"
			1: tool_label.text = "[Phím 2] Đang cầm: CUỐC ĐÀO MỎ (Click chuột trái để đập đá)"
			2: tool_label.text = "[Phím 3] Đang cầm: KIẾM CHIẾN ĐẤU (Click chuột trái để chém)"

func update_health(current: float, max_val: float) -> void:
	if health_bar:
		health_bar.max_value = max_val
		health_bar.value = current

func update_stamina(current: float, max_val: float) -> void:
	if stamina_bar:
		stamina_bar.max_value = max_val
		stamina_bar.value = current

func update_temperature(temp: float) -> void:
	if temp_label:
		temp_label.text = "Thân nhiệt: %.1f°C" % temp
		if temp < 35.0:
			temp_label.modulate = Color(0.4, 0.75, 1.0)
		elif temp > 38.0:
			temp_label.modulate = Color(1.0, 0.45, 0.2)
		else:
			temp_label.modulate = Color.WHITE

func update_biome(biome_name: String) -> void:
	if biome_label:
		biome_label.text = "Địa hình: %s" % biome_name

func update_time(hour: int, minute: int) -> void:
	if time_label:
		time_label.text = "Thời gian: %02d:%02d" % [hour, minute]

func update_phase(phase_name: String) -> void:
	if phase_label:
		match phase_name:
			"Day": phase_label.text = "[BAN NGÀY] Khám phá & Thu thập"
			"Dusk": phase_label.text = "[HOÀNG HÔN] Chuẩn bị thú triều!"
			"Night": phase_label.text = "[BAN ĐÊM] THÚ TRIỀU TẤN CÔNG!"
			"Dawn": phase_label.text = "[RẠNG ĐÔNG] Sống sót an toàn"
