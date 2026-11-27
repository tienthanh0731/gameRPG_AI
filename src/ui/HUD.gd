extends CanvasLayer

@onready var health_label: Label = $LeftPanel/MarginContainer/VBoxContainer/HealthLabel
@onready var health_bar: ProgressBar = $LeftPanel/MarginContainer/VBoxContainer/HealthBar
@onready var stamina_label: Label = $LeftPanel/MarginContainer/VBoxContainer/StaminaLabel
@onready var stamina_bar: ProgressBar = $LeftPanel/MarginContainer/VBoxContainer/StaminaBar
@onready var temp_label: Label = $LeftPanel/MarginContainer/VBoxContainer/TempLabel

@onready var wood_label: Label = $RightPanel/MarginContainer/VBoxContainer/WoodLabel
@onready var stone_label: Label = $RightPanel/MarginContainer/VBoxContainer/StoneLabel
@onready var iron_label: Label = $RightPanel/MarginContainer/VBoxContainer/IronLabel
@onready var sp_label: Label = $RightPanel/MarginContainer/VBoxContainer/SPLabel
@onready var talent_label: Label = $RightPanel/MarginContainer/VBoxContainer/TalentLabel
@onready var btn_leaderboard: Button = $RightPanel/MarginContainer/VBoxContainer/BtnLeaderboard

@onready var day_label: Label = $TopPanel/MarginContainer/VBoxContainer/DayLabel
@onready var biome_label: Label = $TopPanel/MarginContainer/VBoxContainer/BiomeLabel
@onready var time_label: Label = $TopPanel/MarginContainer/VBoxContainer/TimeLabel
@onready var phase_label: Label = $TopPanel/MarginContainer/VBoxContainer/PhaseLabel

@onready var tool_label: Label = $BottomPanel/ToolLabel

@onready var day_summary_ui: Control = $DaySummaryUI
@onready var permadeath_ui: Control = $PermadeathUI
@onready var leaderboard_ui: Control = $LeaderboardUI

func _ready() -> void:
	if day_summary_ui: day_summary_ui.visible = false
	if permadeath_ui: permadeath_ui.visible = false
	if leaderboard_ui: leaderboard_ui.visible = false
	
	if btn_leaderboard:
		btn_leaderboard.pressed.connect(toggle_leaderboard)
		
	if day_summary_ui and day_summary_ui.has_signal("open_leaderboard_requested"):
		day_summary_ui.open_leaderboard_requested.connect(toggle_leaderboard)
		
	if EventBus:
		EventBus.score_updated.connect(_on_score_updated)
		EventBus.day_ended.connect(_on_day_ended)
		
	update_talent_display()
	update_day_display(GameState.current_day)

func update_talent_display() -> void:
	if talent_label:
		if GameState and not GameState.active_talent.is_empty():
			var t = GameState.active_talent
			var rank_str = t.get("rank_str", "F")
			var name_str = t.get("name", "Vô Thiên Phú")
			var col = Color.from_string(t.get("color_hex", "ffffff"), Color.WHITE)
			talent_label.text = "✦ [%s] %s" % [rank_str, name_str]
			talent_label.modulate = col
		else:
			talent_label.text = "✦ [F] Cần Cù Bù Thông Minh"
			talent_label.modulate = Color(0.7, 0.7, 0.7)

func update_day_display(day_num: int) -> void:
	if day_label:
		var phase_desc = GameState.get_difficulty_phase_name(day_num) if GameState else "Tân Thủ"
		day_label.text = "NGÀY SINH TỒN: %d (%s)" % [day_num, phase_desc]

func _on_score_updated(today_sp: int, total_sp: int) -> void:
	if sp_label:
		sp_label.text = "⭐ SP Hôm Nay: +%d (Mùa: %d)" % [today_sp, total_sp]

func _on_day_ended(day_num: int, sp_today: int, rank_tier: String, chest: Dictionary) -> void:
	if day_summary_ui:
		day_summary_ui.setup({
			"day": day_num,
			"today_sp": sp_today,
			"rank_tier": rank_tier,
			"chest": chest,
			"monsters_killed": GameState.monsters_killed_today if GameState else 0
		})
		day_summary_ui.visible = true
		get_tree().paused = true
	update_day_display(day_num + 1)

func show_permadeath(summary: Dictionary) -> void:
	if permadeath_ui:
		permadeath_ui.setup(summary)
		permadeath_ui.visible = true
		get_tree().paused = true

func toggle_leaderboard() -> void:
	if leaderboard_ui:
		leaderboard_ui.visible = not leaderboard_ui.visible

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
			"Day": phase_label.text = "[BAN NGÀY] Khám phá, Thu thập & Tìm Phó bản"
			"Dusk": phase_label.text = "[HOÀNG HÔN] CẢNH BÁO: Thú triều sắp tới! Hãy gia cố tường!"
			"Night": phase_label.text = "[BAN ĐÊM] THÚ TRIỀU TẤN CÔNG CĂN CỨ!"
			"Dawn": phase_label.text = "[RẠNG ĐÔNG] Sống sót qua đêm thành công (+50 SP)"
