extends CanvasLayer

@onready var health_label: Label = $LeftPanel/MarginContainer/VBoxContainer/HealthLabel
@onready var health_bar: ProgressBar = $LeftPanel/MarginContainer/VBoxContainer/HealthBar
@onready var stamina_label: Label = $LeftPanel/MarginContainer/VBoxContainer/StaminaLabel
@onready var stamina_bar: ProgressBar = $LeftPanel/MarginContainer/VBoxContainer/StaminaBar
@onready var temp_label: Label = $LeftPanel/MarginContainer/VBoxContainer/TempLabel

@onready var wood_label: Label = $RightPanel/MarginContainer/VBoxContainer/WoodLabel
@onready var stone_label: Label = $RightPanel/MarginContainer/VBoxContainer/StoneLabel
@onready var iron_label: Label = $RightPanel/MarginContainer/VBoxContainer/IronLabel

@onready var biome_label: Label = $TopPanel/MarginContainer/VBoxContainer/BiomeLabel
@onready var time_label: Label = $TopPanel/MarginContainer/VBoxContainer/TimeLabel
@onready var phase_label: Label = $TopPanel/MarginContainer/VBoxContainer/PhaseLabel

@onready var tool_label: Label = $BottomPanel/ToolLabel

func update_tool(tool_id: int) -> void:
	if tool_label:
		match tool_id:
			0: tool_label.text = "[Phím 1] Đang cầm: RÌU ĐỐN CỦI (Click chuột để chặt) | [Phím B] Xây dựng"
			1: tool_label.text = "[Phím 2] Đang cầm: CUỐC ĐÀO MỎ (Click chuột để đập đá) | [Phím B] Xây dựng"
			2: tool_label.text = "[Phím 3] Đang cầm: KIẾM CHIẾN ĐẤU (Click chuột để chém) | [Phím B] Xây dựng"
			3: tool_label.text = "[CHẾ ĐỘ XÂY DỰNG] Phím 4: Tường (4 Gỗ) | Phím 5: Cổng (6 Gỗ) | Phím 6: Bẫy (3 Gỗ) | [B] Thoát"

func update_resources(wood: int, stone: int, iron: int) -> void:
	if wood_label:
		wood_label.text = "🪵 Gỗ: %d" % wood
	if stone_label:
		stone_label.text = "🪨 Đá: %d" % stone
	if iron_label:
		iron_label.text = "⛏️ Sắt: %d" % iron

func update_health(current: float, max_val: float) -> void:
	if health_bar:
		health_bar.max_value = max_val
		health_bar.value = current
	if health_label:
		health_label.text = "Máu (HP): %d / %d" % [int(current), int(max_val)]

func update_stamina(current: float, max_val: float) -> void:
	if stamina_bar:
		stamina_bar.max_value = max_val
		stamina_bar.value = current
	if stamina_label:
		stamina_label.text = "Thể lực: %d / %d" % [int(current), int(max_val)]

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
