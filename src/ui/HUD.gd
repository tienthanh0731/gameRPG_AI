extends CanvasLayer
const EquipmentData = preload("res://src/data/EquipmentData.gd") # preload: không phụ thuộc cache class_name
## HUD — chỉ hiển thị. Nhận dữ liệu từ Main (call down) và EventBus.

signal reroll_requested()

@onready var health_label: Label = $LeftPanel/MarginContainer/VBoxContainer/HealthLabel
@onready var health_bar: ProgressBar = $LeftPanel/MarginContainer/VBoxContainer/HealthBar
@onready var stamina_label: Label = $LeftPanel/MarginContainer/VBoxContainer/StaminaLabel
@onready var stamina_bar: ProgressBar = $LeftPanel/MarginContainer/VBoxContainer/StaminaBar
@onready var temp_label: Label = $LeftPanel/MarginContainer/VBoxContainer/TempLabel
@onready var left_vbox: VBoxContainer = $LeftPanel/MarginContainer/VBoxContainer

@onready var wood_label: Label = $RightPanel/MarginContainer/VBoxContainer/WoodLabel
@onready var stone_label: Label = $RightPanel/MarginContainer/VBoxContainer/StoneLabel
@onready var iron_label: Label = $RightPanel/MarginContainer/VBoxContainer/IronLabel
@onready var meat_label: Label = $RightPanel/MarginContainer/VBoxContainer/MeatLabel
@onready var bone_label: Label = $RightPanel/MarginContainer/VBoxContainer/BoneLabel
@onready var pill_label: Label = $RightPanel/MarginContainer/VBoxContainer/PillLabel
@onready var sp_label: Label = $RightPanel/MarginContainer/VBoxContainer/SPLabel
@onready var talent_label: Label = $RightPanel/MarginContainer/VBoxContainer/TalentLabel
@onready var btn_leaderboard: Button = $RightPanel/MarginContainer/VBoxContainer/BtnLeaderboard
@onready var right_vbox: VBoxContainer = $RightPanel/MarginContainer/VBoxContainer
@onready var btn_crafting: Button = $RightPanel/MarginContainer/VBoxContainer/BtnCrafting
@onready var btn_map: Button = $RightPanel/MarginContainer/VBoxContainer/BtnMap

@onready var day_label: Label = $TopPanel/MarginContainer/VBoxContainer/DayLabel
@onready var biome_label: Label = $TopPanel/MarginContainer/VBoxContainer/BiomeLabel
@onready var time_label: Label = $TopPanel/MarginContainer/VBoxContainer/TimeLabel
@onready var phase_label: Label = $TopPanel/MarginContainer/VBoxContainer/PhaseLabel
@onready var top_vbox: VBoxContainer = $TopPanel/MarginContainer/VBoxContainer

@onready var tool_label: Label = $BottomPanel/ToolLabel

@onready var day_summary_ui: Control = $DaySummaryUI
@onready var permadeath_ui: Control = $PermadeathUI
@onready var leaderboard_ui: Control = $LeaderboardUI
@onready var crafting_ui: Control = $CraftingUI
@onready var world_map_ui: Control = $WorldMapUI

var hunger_label: Label
var hunger_bar: ProgressBar
var tide_label: Label

func _ready() -> void:
	day_summary_ui.visible = false
	permadeath_ui.visible = false
	leaderboard_ui.visible = false
	btn_leaderboard.pressed.connect(toggle_leaderboard)
	day_summary_ui.open_leaderboard_requested.connect(toggle_leaderboard)
	EventBus.score_updated.connect(_on_score_updated)
	EventBus.day_summary_ready.connect(_on_day_summary)
	EventBus.talent_changed.connect(func(_t): update_talent_display())
	EventBus.sp_added.connect(func(a, r): show_toast("+%d SP • %s" % [a, r], Color(1.0, 0.85, 0.3)))
	_build_extra_widgets()
	crafting_ui.visible = false
	world_map_ui.visible = false
	btn_crafting.pressed.connect(toggle_crafting)
	btn_map.pressed.connect(toggle_map)
	update_talent_display()
	update_day_display(GameState.current_day)
	_on_score_updated(GameState.today_sp, GameState.character_total_sp)

func _build_extra_widgets() -> void:
	hunger_label = Label.new()
	hunger_label.text = "Đói (No): 100"
	left_vbox.add_child(hunger_label)
	left_vbox.move_child(hunger_label, temp_label.get_index())
	hunger_bar = ProgressBar.new()
	hunger_bar.max_value = 100
	hunger_bar.show_percentage = false
	hunger_bar.custom_minimum_size = Vector2(0, 10)
	left_vbox.add_child(hunger_bar)
	left_vbox.move_child(hunger_bar, temp_label.get_index())

	tide_label = Label.new()
	tide_label.add_theme_font_size_override("font_size", 13)
	top_vbox.add_child(tide_label)

	var hint := Label.new()
	hint.text = "[F] Ăn • [T] Đan Reroll • [K] Thiên phú • [P] Mùa giải • [L] BXH • [I] Chế tạo • [M] Bản đồ"
	hint.add_theme_font_size_override("font_size", 11)
	right_vbox.add_child(hint)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T:
			reroll_requested.emit()
		elif event.keycode == KEY_L:
			toggle_leaderboard()

func update_talent_display() -> void:
	var t := GameState.active_talent
	if t.is_empty():
		talent_label.text = "✦ (không có thiên phú)"
		return
	talent_label.text = "✦ [%s] %s" % [t.get("rank_str", "F"), t.get("name", "")]
	talent_label.modulate = Color.from_string(t.get("color_hex", "ffffff"), Color.WHITE)
	talent_label.tooltip_text = t.get("desc", "")

func update_day_display(day_num: int) -> void:
	day_label.text = "NGÀY SINH TỒN: %d (%s)" % [day_num, GameState.get_difficulty_phase_name(day_num)]

func _on_score_updated(today_sp: int, total_sp: int) -> void:
	sp_label.text = "⭐ SP Hôm Nay: %d (Nhân vật: %d)" % [today_sp, total_sp]

func _on_day_summary(summary: Dictionary) -> void:
	day_summary_ui.setup(summary)
	day_summary_ui.visible = true
	get_tree().paused = true
	update_day_display(GameState.current_day)

func show_permadeath(summary: Dictionary) -> void:
	permadeath_ui.setup(summary)
	permadeath_ui.visible = true
	get_tree().paused = true

func toggle_leaderboard() -> void:
	leaderboard_ui.visible = not leaderboard_ui.visible
	if leaderboard_ui.visible and leaderboard_ui.has_method("refresh"):
		leaderboard_ui.refresh()

func toggle_crafting() -> void:
	if crafting_ui:
		if crafting_ui.has_method("toggle_ui"):
			crafting_ui.toggle_ui()
		else:
			crafting_ui.visible = not crafting_ui.visible

func toggle_map() -> void:
	if world_map_ui:
		if world_map_ui.has_method("toggle_map"):
			world_map_ui.toggle_map()
		else:
			world_map_ui.visible = not world_map_ui.visible

func update_tool(tool_id: int) -> void:
	match tool_id:
		0: tool_label.text = "[1] RÌU (chặt cây / phá công trình) | [2] Cuốc | [3] Kiếm | [B] Xây dựng | [E] Phó bản / cổng"
		1: tool_label.text = "[2] CUỐC (đập đá, quặng / phá công trình) | [1] Rìu | [3] Kiếm | [B] Xây dựng"
		2: tool_label.text = "[3] KIẾM (chiến đấu) | [1] Rìu | [2] Cuốc | [Space] Lướt né | [B] Xây dựng"
		3: tool_label.text = "[XÂY DỰNG] Trái: Đặt | Phải: Phá dỡ | [4] Tường [5] Cổng [6] Chông [7] Nhà Gỗ | [U] Nâng cấp | [B] Đóng"
	if tool_id <= 2 and not last_equipment.is_empty():
		tool_label.text += "   •   " + _equipment_text(last_equipment, tool_id)

var last_equipment: Dictionary = {}

## Hiển thị bậc + độ bền công cụ đang cầm (Player.equipment_changed).
func update_equipment(equipment: Dictionary, current_tool: int) -> void:
	last_equipment = equipment
	update_tool(current_tool)

func _equipment_text(equipment: Dictionary, slot: int) -> String:
	var item: Dictionary = equipment.get(EquipmentData.SLOT_KEYS[slot], {})
	if item.is_empty():
		return ""
	if EquipmentData.is_broken(item):
		tool_label.modulate = Color(1, 0.4, 0.35)
		return "⚠ %s ĐÃ GÃY (tay không) — sửa ở [I]" % EquipmentData.item_name(slot, int(item.tier))
	var mx := EquipmentData.max_durability(int(item.tier))
	tool_label.modulate = Color(1, 0.8, 0.4) if int(item.durability) * 4 < mx else Color.WHITE
	return "%s — Độ bền %d/%d" % [EquipmentData.item_name(slot, int(item.tier)), int(item.durability), mx]

func update_inventory(inv_dict: Dictionary) -> void:
	if wood_label: wood_label.text = "🪵 Gỗ: %d" % inv_dict.get("wood", 0)
	if stone_label: stone_label.text = "🪨 Đá: %d" % inv_dict.get("stone", 0)
	if iron_label: iron_label.text = "⛏️ Sắt: %d" % inv_dict.get("iron", 0)
	if meat_label: meat_label.text = "🍖 Thịt Rừng: %d" % inv_dict.get("meat", 0)
	if bone_label: bone_label.text = "🦴 Xương / Da: %d" % inv_dict.get("bone", 0)
	if pill_label: pill_label.text = "💊 Đan Reroll: %d" % inv_dict.get("reroll_pill", inv_dict.get("reroll_pills", 0))

func update_resources(wood: int, stone: int, iron: int) -> void:
	wood_label.text = "🪵 Gỗ: %d" % wood
	stone_label.text = "🪨 Đá: %d" % stone
	iron_label.text = "⛏️ Sắt: %d" % iron

func update_health(current: float, max_val: float) -> void:
	health_bar.max_value = max_val
	health_bar.value = current
	health_label.text = "Máu (HP): %d / %d" % [int(current), int(max_val)]

func update_stamina(current: float, max_val: float) -> void:
	stamina_bar.max_value = max_val
	stamina_bar.value = current
	stamina_label.text = "Thể lực: %d / %d" % [int(current), int(max_val)]

func update_hunger(value: float) -> void:
	if hunger_bar:
		hunger_bar.value = value
		hunger_label.text = "Đói (No): %d / 100%s" % [int(value), "  ⚠ ĐANG ĐÓI!" if value <= 0.0 else ""]
		hunger_label.modulate = Color(1, 0.4, 0.3) if value < 25.0 else Color.WHITE

func update_temperature(temp: float) -> void:
	temp_label.text = "Thân nhiệt: %.1f°C" % temp
	if temp < 35.0:
		temp_label.modulate = Color(0.4, 0.75, 1.0)
	elif temp > 38.0:
		temp_label.modulate = Color(1.0, 0.45, 0.2)
	else:
		temp_label.modulate = Color.WHITE

func update_biome(biome_name: String) -> void:
	biome_label.text = "Địa hình: %s" % biome_name

func update_time(hour: int, minute: int) -> void:
	time_label.text = "Thời gian: %02d:%02d" % [hour, minute]
	if tide_label:
		var p := GameState.get_tonight_preview()
		var kind := "Thú triều" if p.is_real else "Trinh sát"
		var h := GameState.hours_until_tide()
		if hour >= 20 or hour < 5 or (hour == 19 and minute >= 30):
			tide_label.text = "☠ %s đang tấn công! (%d quái, hướng %s)" % [kind, p.count, ", ".join(p.direction_names)]
			tide_label.modulate = Color(1, 0.35, 0.35)
		else:
			# 1 ngày game = 300 giây thật → 1 giờ game = 12.5 giây
			var real_sec := int(h * 300.0 / 24.0)
			tide_label.text = "⏳ %s sau %dh%02d (≈%ds) • %d quái" % [kind, int(h), int((h - int(h)) * 60), real_sec, p.count]
			tide_label.modulate = Color(1, 0.7, 0.3) if h < 3.0 else Color(0.85, 0.85, 0.85)

func update_phase(phase_name: String) -> void:
	match phase_name:
		"Day": phase_label.text = "[BAN NGÀY] Khai thác & dọn phó bản (%d cửa hôm nay)" % GameState.get_dungeon_count()
		"Dusk": phase_label.text = "[HOÀNG HÔN] Thú triều sắp tới! Gia cố tường, đặt bẫy!"
		"Night": phase_label.text = "[BAN ĐÊM] THÚ TRIỀU TẤN CÔNG CĂN CỨ!"
		"Dawn": phase_label.text = "[RẠNG ĐÔNG] Đã qua đêm"

func update_minimap(_player_pos: Vector2, _base_pos: Vector2, _dungeons: Array) -> void:
	pass # Minimap (src/ui/map) tự đọc vị trí trong _process

func show_toast(text: String, col: Color = Color.WHITE) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.modulate = col
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.position = Vector2(500, 560)
	add_child(lbl)
	var tw := lbl.create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", 520.0, 1.6)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.6).set_delay(0.6)
	tw.chain().tween_callback(lbl.queue_free)
