extends Control

const TalentData = preload("res://src/data/TalentData.gd")

@onready var input_name: LineEdit = $Panel/VBox/HBoxName/LineEditName
@onready var btn_awaken: Button = $Panel/VBox/TalentCard/BtnAwaken
@onready var btn_start: Button = $Panel/VBox/BtnStart
@onready var btn_resume: Button = $Panel/VBox/BtnResume
@onready var label_rank: Label = $Panel/VBox/TalentCard/LabelRank
@onready var label_name: Label = $Panel/VBox/TalentCard/LabelTalentName
@onready var label_desc: Label = $Panel/VBox/TalentCard/LabelDesc
@onready var talent_card: PanelContainer = $Panel/VBox/TalentCard
@onready var label_account_record: Label = $Panel/AccountHeader/LabelRecord

var rolled_talent: Dictionary = {}
var is_rolling: bool = false
var roll_timer: float = 0.0
var roll_ticks: int = 0

func _ready() -> void:
	btn_start.disabled = true
	btn_awaken.pressed.connect(_on_btn_awaken_pressed)
	btn_start.pressed.connect(_on_btn_start_pressed)
	btn_resume.pressed.connect(_on_btn_resume_pressed)
	
	_update_account_display()
	
	# Check if character already exists
	if SaveSystem.has_active_character():
		var char_data = SaveSystem.character_data
		btn_resume.visible = true
		btn_resume.text = "TIẾP TỤC SINH TỒN [NGÀY %d] (%s - BẬC %s)" % [
			char_data.get("day", 1),
			char_data.get("name", "Người chơi"),
			char_data.get("talent", {}).get("rank_str", "F")
		]
	else:
		btn_resume.visible = false
		
	_build_profile_button()
	# Thiên phú đã roll trước đó (chưa dùng) → hiển thị lại, KHÔNG roll mới
	if ServerSim.has_pending_talent():
		rolled_talent = ServerSim.get_or_roll_pending_talent()
		_show_talent(rolled_talent)
	# Random initial default name
	if input_name.text.is_empty():
		input_name.text = "Xuyên Không Giả #" + str(randi() % 900 + 100)

func _update_account_display() -> void:
	var acc = SaveSystem.account_data
	var highest_day = acc.get("highest_day_record", 0)
	var season_sp = acc.get("season_sp", 0)
	var active_title = acc.get("active_title", "Tân Thủ Hoang Cổ")
	label_account_record.text = "Tài khoản: [%s] | Kỷ lục: %d Ngày | Điểm Mùa Giải: %d SP" % [
		active_title, highest_day, season_sp
	]

func _on_btn_awaken_pressed() -> void:
	if is_rolling or not rolled_talent.is_empty(): return
	is_rolling = true
	btn_awaken.disabled = true
	btn_start.disabled = true
	roll_ticks = 0
	
	# Animated roll effect
	var tween = create_tween()
	for i in range(12):
		tween.tween_callback(_roll_tick_preview)
		tween.tween_interval(0.08)
	tween.chain().tween_callback(_finish_roll)

func _roll_tick_preview() -> void:
	var ranks = ["F", "D", "C", "B", "A", "S", "SSS"]
	var r = ranks[randi() % ranks.size()]
	label_rank.text = "[BẬC " + r + "]"
	label_name.text = "Đang kết nối ý chí nguyên thủy..."
	label_desc.text = "Thiên địa sơ khai, linh khí hỗn độn..."
	
	# Flash color
	var rand_col = Color(randf(), randf(), randf())
	label_rank.modulate = rand_col

func _finish_roll() -> void:
	is_rolling = false
	# Roll do "server" thực hiện và lưu ngay → không thể roll lại bằng cách bấm lại/thoát game
	rolled_talent = ServerSim.get_or_roll_pending_talent()
	_show_talent(rolled_talent)

func _show_talent(t: Dictionary) -> void:
	rolled_talent = t
	
	# Display final awakened talent
	var rank_str = rolled_talent.get("rank_str", "F")
	var talent_name = rolled_talent.get("name", "Vô Danh")
	var desc = rolled_talent.get("desc", "")
	var col = Color.from_string(rolled_talent.get("color_hex", "ffffff"), Color.WHITE)
	
	label_rank.text = "✦ [BẬC " + rank_str + "] ✦"
	label_rank.modulate = col
	label_name.text = talent_name
	label_name.modulate = col
	label_desc.text = desc
	
	btn_awaken.text = "ĐÃ THỨC TỈNH (chỉ Đan Reroll mới đổi được)"
	btn_awaken.disabled = true
	btn_start.disabled = false
	btn_start.text = "BẮT ĐẦU SINH TỒN VỚI THIÊN PHÚ [" + rank_str + "]"

func _on_btn_start_pressed() -> void:
	if rolled_talent.is_empty():
		return
		
	var char_name = input_name.text.strip_edges()
	if char_name.is_empty():
		char_name = "Kẻ Xuyên Không #" + str(randi() % 900 + 100)
		
	# Save new character (thiên phú lấy từ "server", không từ UI)
	var talent := ServerSim.consume_pending_talent()
	if talent.is_empty():
		return
	SaveSystem.create_new_character(char_name, talent)
	GameState.load_from_character()
	
	# Load main game scene
	get_tree().change_scene_to_file("res://src/world/Main.tscn")

func _on_btn_resume_pressed() -> void:
	if not SaveSystem.has_active_character():
		return
		
	GameState.load_from_character()
	get_tree().change_scene_to_file("res://src/world/Main.tscn")

# ==========================================
# HỒ SƠ ACCOUNT (tách biệt khỏi nhân vật)
# ==========================================
var profile_panel: PanelContainer

func _build_profile_button() -> void:
	var btn := Button.new()
	btn.text = "📜 HỒ SƠ TÀI KHOẢN"
	btn.position = Vector2(20, 20)
	btn.pressed.connect(_toggle_profile)
	add_child(btn)

func _toggle_profile() -> void:
	if profile_panel and is_instance_valid(profile_panel):
		profile_panel.queue_free()
		profile_panel = null
		return
	var acc := SaveSystem.account_data
	profile_panel = PanelContainer.new()
	profile_panel.set_anchors_preset(Control.PRESET_CENTER)
	profile_panel.custom_minimum_size = Vector2(640, 460)
	profile_panel.position = Vector2(320, 120)
	var vb := VBoxContainer.new()
	profile_panel.add_child(vb)
	var head := Label.new()
	head.text = "HỒ SƠ TÀI KHOẢN %s  (vĩnh viễn — không mất khi nhân vật chết)" % acc.get("account_id", "")
	head.add_theme_font_size_override("font_size", 16)
	vb.add_child(head)
	var info := Label.new()
	info.text = "Kỷ lục ngày sống sót: %d  •  Điểm mùa: %d SP  •  Số lần chơi: %d  •  Tổng quái hạ: %d\nDanh hiệu: %s\nCosmetic: %s" % [
		acc.get("highest_day_record", 0), acc.get("season_sp", 0), acc.get("total_games_played", 0),
		acc.get("total_monsters_killed", 0), ", ".join(acc.get("titles", [])),
		"(chưa mở khóa)" if acc.get("cosmetics", []).is_empty() else ", ".join(acc.get("cosmetics", []))]
	vb.add_child(info)
	var season_info := Label.new()
	var sh: Array = acc.get("season_history", [])
	season_info.text = "Mùa giải %d • Kỷ lục mùa: %d ngày • Cấp Tái Sinh: %d (x%.2f tăng trưởng) • Mùa trước: %s" % [
		SeasonSystem.season_id(), acc.get("season_best_day", 0), SeasonSystem.prestige_level(),
		SeasonSystem.growth_mult(), ("Mùa %d — %d điểm" % [sh[0].season, sh[0].season_sp]) if not sh.is_empty() else "chưa có"]
	vb.add_child(season_info)
	var hist := ItemList.new()
	hist.custom_minimum_size = Vector2(600, 300)
	var logs: Array = acc.get("history_logs", [])
	if logs.is_empty():
		hist.add_item("Chưa có lần chơi nào kết thúc.")
	for l in logs:
		hist.add_item("%s  |  %s  |  %d ngày  |  %d SP  |  [%s] %s%s" % [
			l.get("date", ""), l.get("char_name", ""), l.get("day_survived", 0), l.get("sp_earned", 0),
			l.get("talent_rank", "F"), l.get("talent_name", ""),
			("  ★KỶ LỤC" if l.get("record", false) else "") + ("  ♻TÁI SINH" if l.get("reason", "") == "prestige" else "")])
	vb.add_child(hist)
	var close := Button.new()
	close.text = "Đóng"
	close.pressed.connect(_toggle_profile)
	vb.add_child(close)
	add_child(profile_panel)
