extends CanvasLayer

signal tutorial_step_completed(step_index: int, step_id: String)
signal tutorial_finished()

@onready var panel_root: Control = $Control
@onready var panel: Panel = $Control/Panel
@onready var label_step_badge: Label = $Control/Panel/VBox/HeaderHBox/StepBadge
@onready var label_title: Label = $Control/Panel/VBox/HeaderHBox/Title
@onready var label_desc: Label = $Control/Panel/VBox/Desc
@onready var progress_bar: ProgressBar = $Control/Panel/VBox/ProgressBar
@onready var label_progress: Label = $Control/Panel/VBox/ProgressLabel
@onready var btn_skip: Button = $Control/Panel/VBox/BottomHBox/SkipButton
@onready var btn_toggle_mini: Button = $Control/Panel/VBox/HeaderHBox/MiniButton

var current_step_idx: int = 0
var is_minimized: bool = false
var step_progress: int = 0

var STEPS = [
	{
		"id": "gather_wood",
		"badge": "[1/6]",
		"title": "CHẶT CÂY THU THẬP GỖ",
		"desc": "Cầm Rìu [Phím 1] và click chuột trái vào cây rừng để đốn củi.",
		"target": 5,
		"target_unit": "Gỗ"
	},
	{
		"id": "gather_stone",
		"badge": "[2/6]",
		"title": "ĐẬP ĐÁ KHAI KHOÁNG",
		"desc": "Cầm Cuốc [Phím 2] và click chuột trái vào tảng đá để đập đá.",
		"target": 4,
		"target_unit": "Đá"
	},
	{
		"id": "build_wall",
		"badge": "[3/6]",
		"title": "XÂY DỰNG CHIẾN LŨY",
		"desc": "Bấm [Phím B] vào Chế độ Xây dựng, bấm [Phím 4] và click chuột để đặt 1 Tường Gỗ.",
		"target": 1,
		"target_unit": "Công trình"
	},
	{
		"id": "craft_axe",
		"badge": "[4/6]",
		"title": "RÈN RÌU ĐÁ NÂNG CẤP",
		"desc": "Bấm [Phím I] mở Bàn Chế Tạo, rèn Rìu Đá (4 Gỗ + 6 Đá) để chặt được Cổ Thụ.",
		"target": 1,
		"target_unit": "Rìu Đá"
	},
	{
		"id": "explore_dungeon",
		"badge": "[5/6]",
		"title": "KHÁM PHÁ PHÓ BẢN TÀN TÍCH",
		"desc": "Di chuyển về phía Đông Bắc căn cứ, bước vào cổng phó bản để săn Boss & lấy rương.",
		"target": 1,
		"target_unit": "Phó bản"
	},
	{
		"id": "survive_night",
		"badge": "[6/6]",
		"title": "CHUẨN BỊ ĐÓN THÚ TRIỀU",
		"desc": "Hoàng hôn đến xem la bàn cảnh báo. Đốt lửa giữ ấm và rút Kiếm [Phím 3] chiến đấu qua đêm!",
		"target": 1,
		"target_unit": "Đêm"
	}
]

func _ready() -> void:
	if not _should_show_tutorial():
		visible = false
		set_process(false)
		return
		
	visible = true
	if btn_skip:
		btn_skip.pressed.connect(_on_skip_pressed)
	if btn_toggle_mini:
		btn_toggle_mini.pressed.connect(_on_toggle_mini_pressed)
		
	_connect_event_bus()
	_update_step_ui()

func _should_show_tutorial() -> bool:
	# Chỉ hiện cho nhân vật đầu tiên của tài khoản (total_games_played == 0)
	var games_played = 0
	if ClassDB.class_exists("SaveSystem") or has_node("/root/SaveSystem"):
		var ss = get_node_or_null("/root/SaveSystem")
		if ss and "account_data" in ss and ss.account_data is Dictionary:
			games_played = int(ss.account_data.get("total_games_played", 0))
	return games_played == 0

func _connect_event_bus() -> void:
	var eb = get_node_or_null("/root/EventBus")
	if not eb:
		return
		
	if eb.has_signal("resource_gathered"):
		eb.resource_gathered.connect(_on_resource_gathered)
	if eb.has_signal("structure_placed"):
		eb.structure_placed.connect(_on_structure_placed)
	if eb.has_signal("dungeon_cleared"):
		eb.dungeon_cleared.connect(_on_dungeon_cleared)
	if eb.has_signal("night_started"):
		eb.night_started.connect(_on_night_started)

func _process(_delta: float) -> void:
	# Check step 4 (Stone Axe) dynamically from Player equipment if available
	if current_step_idx == 3:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			var p = players[0]
			var equip = p.get("equipment") if "equipment" in p else {}
			if equip is Dictionary:
				var axe = equip.get("axe", {})
				if int(axe.get("tier", 0)) >= 1:
					_advance_step()

func _update_step_ui() -> void:
	if current_step_idx >= STEPS.size():
		_finish_tutorial()
		return
		
	var s = STEPS[current_step_idx]
	if label_step_badge: label_step_badge.text = s["badge"]
	if label_title: label_title.text = s["title"]
	if label_desc: label_desc.text = s["desc"]
	
	if progress_bar:
		progress_bar.max_value = s["target"]
		progress_bar.value = step_progress
		
	if label_progress:
		label_progress.text = "%d / %d %s" % [step_progress, s["target"], s["target_unit"]]

func _advance_step() -> void:
	if current_step_idx >= STEPS.size():
		return
		
	var completed_step = STEPS[current_step_idx]
	tutorial_step_completed.emit(current_step_idx, completed_step["id"])
	
	_play_step_complete_anim()
	
	current_step_idx += 1
	step_progress = 0
	
	if current_step_idx < STEPS.size():
		_update_step_ui()
	else:
		_finish_tutorial()

func _play_step_complete_anim() -> void:
	if panel:
		var tw = panel.create_tween()
		tw.tween_property(panel, "modulate", Color(0.4, 1.2, 0.4), 0.12)
		tw.tween_property(panel, "modulate", Color.WHITE, 0.25)

func _finish_tutorial() -> void:
	if label_title: label_title.text = "🎉 HOÀN THÀNH TÂN THỦ!"
	if label_desc: label_desc.text = "Bạn đã nắm vững toàn bộ kỹ năng sinh tồn cơ bản thời Hoang Cổ. Chúc bạn sống sót thật lâu!"
	if progress_bar: progress_bar.visible = false
	if label_progress: label_progress.visible = false
	if btn_skip: btn_skip.text = "Đóng"
	tutorial_finished.emit()
	
	var tw = panel_root.create_tween()
	tw.tween_interval(5.0)
	tw.tween_property(panel_root, "modulate:a", 0.0, 1.0)
	tw.tween_callback(func(): visible = false)

# ==================================================================
# EVENTBUS LISTENERS
# ==================================================================
func _on_resource_gathered(key: String, amount: int) -> void:
	if current_step_idx == 0 and key == "wood":
		step_progress += amount
		if step_progress >= STEPS[0]["target"]:
			_advance_step()
		else:
			_update_step_ui()
	elif current_step_idx == 1 and key == "stone":
		step_progress += amount
		if step_progress >= STEPS[1]["target"]:
			_advance_step()
		else:
			_update_step_ui()

func _on_structure_placed(_struct_type: int, _pos: Vector2) -> void:
	if current_step_idx == 2:
		step_progress += 1
		if step_progress >= STEPS[2]["target"]:
			_advance_step()
		else:
			_update_step_ui()

func _on_dungeon_cleared(_dungeon_name: String, _reward_data: Dictionary) -> void:
	if current_step_idx == 4:
		_advance_step()

func _on_night_started(_wave_size: int) -> void:
	if current_step_idx == 5:
		_advance_step()

func _on_skip_pressed() -> void:
	visible = false
	set_process(false)

func _on_toggle_mini_pressed() -> void:
	is_minimized = not is_minimized
	if label_desc: label_desc.visible = not is_minimized
	if progress_bar: progress_bar.visible = not is_minimized
	if label_progress: label_progress.visible = not is_minimized
	if btn_skip: btn_skip.visible = not is_minimized
	if btn_toggle_mini: btn_toggle_mini.text = "+" if is_minimized else "-"
	if panel:
		panel.custom_minimum_size = Vector2(300, 40 if is_minimized else 145)
