extends CanvasLayer

signal talent_updated(new_char_data: Dictionary)

const TalentData = preload("res://src/data/TalentData.gd")
const AwakeningData = preload("res://src/data/AwakeningData.gd")

@onready var panel_root: Control = $Control
@onready var label_main_name: Label = $Control/Panel/HBox/MainTalentCard/Name
@onready var label_main_rank: Label = $Control/Panel/HBox/MainTalentCard/RankBadge
@onready var label_main_desc: Label = $Control/Panel/HBox/MainTalentCard/Desc
@onready var progress_main_bar: ProgressBar = $Control/Panel/HBox/MainTalentCard/ProgressBar
@onready var label_main_chal: Label = $Control/Panel/HBox/MainTalentCard/ChallengeText
@onready var btn_main_promote: Button = $Control/Panel/HBox/MainTalentCard/PromoteButton

@onready var label_sub_status: Label = $Control/Panel/HBox/SubTalentCard/StatusText
@onready var container_sub_content: VBoxContainer = $Control/Panel/HBox/SubTalentCard/Content
@onready var label_sub_name: Label = $Control/Panel/HBox/SubTalentCard/Content/Name
@onready var label_sub_rank: Label = $Control/Panel/HBox/SubTalentCard/Content/RankBadge
@onready var label_sub_desc: Label = $Control/Panel/HBox/SubTalentCard/Content/Desc
@onready var btn_awaken_sub: Button = $Control/Panel/HBox/SubTalentCard/AwakenButton

var character_data: Dictionary = {}
var current_day: int = 1

func _ready() -> void:
	visible = false
	var btn_close = get_node_or_null("Control/Panel/CloseButton")
	if btn_close:
		btn_close.pressed.connect(hide_panel)
	if btn_main_promote:
		btn_main_promote.pressed.connect(_on_promote_main_pressed)
	if btn_awaken_sub:
		btn_awaken_sub.pressed.connect(_on_awaken_sub_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_K:
			toggle_panel()
		elif event.keycode == KEY_ESCAPE and visible:
			hide_panel()

func toggle_panel() -> void:
	if visible:
		hide_panel()
	else:
		show_panel()

func show_panel() -> void:
	_refresh_data_from_game()
	_update_ui()
	visible = true

func hide_panel() -> void:
	visible = false

func _refresh_data_from_game() -> void:
	# Pull from GameState and SaveSystem if available
	if has_node("/root/GameState"):
		var gs = get_node("/root/GameState")
		current_day = gs.get("current_day") if "current_day" in gs else 1
		character_data["day"] = current_day
		character_data["talent"] = gs.get("active_talent") if "active_talent" in gs else {}
		character_data["sub_talent"] = gs.get("sub_talent") if "sub_talent" in gs else {}
		character_data["monsters_killed"] = gs.get("total_monsters_killed") if "total_monsters_killed" in gs else 0
		character_data["dungeons_cleared"] = gs.get("dungeons_cleared") if "dungeons_cleared" in gs else 0
		character_data["world_bosses_defeated"] = gs.get("world_bosses_defeated") if "world_bosses_defeated" in gs else 0

func _update_ui() -> void:
	# 1. Main Talent UI
	var main_t = character_data.get("talent", {})
	if main_t.is_empty():
		label_main_name.text = "Chưa có Thiên Phú"
		label_main_rank.text = "-"
		label_main_desc.text = "Hãy tạo nhân vật mới để roll thiên phú."
		btn_main_promote.disabled = true
	else:
		label_main_name.text = main_t.get("name", "Vô Danh")
		var r_str = main_t.get("rank_str", "F")
		label_main_rank.text = "[BẬC %s]" % r_str
		label_main_desc.text = main_t.get("desc", "")
		
		# Check Enlightenment Progress
		var prog = AwakeningData.check_enlightenment_progress(character_data, "talent")
		if prog.get("is_maxed", false):
			label_main_chal.text = "✨ Đã đạt cảnh giới cực hạn Bất Diệt (SSS)"
			progress_main_bar.value = 100
			btn_main_promote.visible = false
		else:
			var chal = prog.get("challenge", {})
			label_main_chal.text = "Thử thách Đột Phá (%s ➔ %s):\n%s (%d / %d)" % [
				r_str, chal.get("next_rank_str", ""), chal.get("desc", ""), prog["progress"], prog["target"]
			]
			progress_main_bar.value = prog["percent"] * 100.0
			btn_main_promote.visible = true
			btn_main_promote.disabled = not prog["completed"]
			btn_main_promote.text = "⚡ ĐỘT PHÁ GIÁC NGỘ" if prog["completed"] else "Chưa hoàn thành thử thách"

	# 2. Sub-Talent UI
	var can_awaken = AwakeningData.can_awaken_sub_talent(character_data, current_day)
	var sub_t = character_data.get("sub_talent", {})
	
	if current_day < 15 and sub_t.is_empty():
		label_sub_status.text = "🔒 THIÊN PHÚ PHỤ KHÓA\n(Mở khóa khi sống sót tới Ngày 15. Hiện tại: Ngày %d/15)" % current_day
		label_sub_status.visible = true
		container_sub_content.visible = false
		btn_awaken_sub.visible = false
	elif can_awaken:
		label_sub_status.text = "⚡ ĐẠT MỐC NGÀY 15: THỨC TỈNH THIÊN PHÚ PHỤ ĐÃ MỞ!"
		label_sub_status.visible = true
		container_sub_content.visible = false
		btn_awaken_sub.visible = true
		btn_awaken_sub.text = "🎲 THỨC TỈNH THIÊN PHÚ PHỤ"
	else:
		label_sub_status.visible = false
		btn_awaken_sub.visible = false
		container_sub_content.visible = true
		label_sub_name.text = sub_t.get("name", "Vô Danh")
		label_sub_rank.text = "[BẬC %s]" % sub_t.get("rank_str", "F")
		label_sub_desc.text = sub_t.get("desc", "")

func _on_promote_main_pressed() -> void:
	var next_char = AwakeningData.promote_talent(character_data, "talent")
	character_data = next_char
	_sync_back_to_game()
	_update_ui()

func _on_awaken_sub_pressed() -> void:
	var next_char = AwakeningData.awaken_sub_talent(character_data, current_day)
	character_data = next_char
	_sync_back_to_game()
	_update_ui()

func _sync_back_to_game() -> void:
	if has_node("/root/GameState"):
		var gs = get_node("/root/GameState")
		if "active_talent" in gs:
			gs.active_talent = character_data.get("talent", {})
		if "sub_talent" in gs:
			gs.sub_talent = character_data.get("sub_talent", {})
	talent_updated.emit(character_data)
