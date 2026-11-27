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
	if is_rolling: return
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
	btn_awaken.disabled = false
	rolled_talent = TalentData.roll_talent()
	
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
	
	btn_awaken.text = "THỨC TỈNH LẠI (TEST ROLL)"
	btn_start.disabled = false
	btn_start.text = "BẮT ĐẦU SINH TỒN VỚI THIÊN PHÚ [" + rank_str + "]"

func _on_btn_start_pressed() -> void:
	if rolled_talent.is_empty():
		return
		
	var char_name = input_name.text.strip_edges()
	if char_name.is_empty():
		char_name = "Kẻ Xuyên Không #" + str(randi() % 900 + 100)
		
	# Save new character
	SaveSystem.create_new_character(char_name, rolled_talent)
	GameState.init_new_game(rolled_talent, 1)
	
	# Load main game scene
	get_tree().change_scene_to_file("res://src/world/Main.tscn")

func _on_btn_resume_pressed() -> void:
	if not SaveSystem.has_active_character():
		return
		
	var char_data = SaveSystem.character_data
	var talent = char_data.get("talent", {})
	var day = char_data.get("day", 1)
	
	GameState.init_new_game(talent, day)
	get_tree().change_scene_to_file("res://src/world/Main.tscn")
