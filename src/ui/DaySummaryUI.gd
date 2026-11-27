extends Control

signal summary_closed()
signal open_leaderboard_requested()

@onready var label_title: Label = $Panel/VBox/LabelTitle
@onready var label_sp: Label = $Panel/VBox/LabelSP
@onready var label_tier: Label = $Panel/VBox/LabelTier
@onready var label_rewards: Label = $Panel/VBox/LabelRewards
@onready var btn_continue: Button = $Panel/VBox/HBoxButtons/BtnContinue
@onready var btn_leaderboard: Button = $Panel/VBox/HBoxButtons/BtnLeaderboard

var cached_rewards: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	btn_continue.pressed.connect(_on_btn_continue_pressed)
	btn_leaderboard.pressed.connect(_on_btn_leaderboard_pressed)

func setup(summary_data: Dictionary) -> void:
	var day = summary_data.get("day", 1)
	var sp = summary_data.get("today_sp", 0)
	var rank_tier = summary_data.get("rank_tier", "Top 50%")
	var chest = summary_data.get("chest", {})
	cached_rewards = chest.get("items", [])
	
	label_title.text = "✦ TỔNG KẾT SINH TỒN NGÀY %d ✦" % day
	label_sp.text = "• Điểm Sinh Tồn (SP) kiếm được hôm nay: +%d SP\n• Tiêu diệt quái vật: %d dã thú" % [
		sp, summary_data.get("monsters_killed", 0)
	]
	
	label_tier.text = "XẾP HẠNG TOÀN SERVER: [%s]" % rank_tier
	if "Top 1%" in rank_tier:
		label_tier.modulate = Color(1.0, 0.85, 0.2)
	elif "Top 10%" in rank_tier:
		label_tier.modulate = Color(0.8, 0.4, 1.0)
	elif "Top 50%" in rank_tier:
		label_tier.modulate = Color(0.3, 0.8, 1.0)
	else:
		label_tier.modulate = Color(0.6, 1.0, 0.6)
		
	var reward_text = "Phần thưởng rương nhận được:\n"
	if cached_rewards.is_empty():
		reward_text += "(Không có hoạt động trong ngày - Không nhận thưởng)"
	else:
		for item in cached_rewards:
			reward_text += " • +%d %s\n" % [item.get("amount", 1), item.get("name", "Vật phẩm")]
	label_rewards.text = reward_text

func _on_btn_continue_pressed() -> void:
	# Add rewards to player's inventory
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var inv = player.get_node_or_null("Inventory")
		if inv:
			for item in cached_rewards:
				inv.add_resource(item.get("name", ""), item.get("amount", 1))
				
	visible = false
	get_tree().paused = false
	summary_closed.emit()

func _on_btn_leaderboard_pressed() -> void:
	open_leaderboard_requested.emit()
