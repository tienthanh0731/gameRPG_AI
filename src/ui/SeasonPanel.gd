extends CanvasLayer
## Bảng Mùa Giải [P]: thông tin mùa, Season Pass (nhận thưởng), nhiệm vụ tuần, Tái Sinh.
## Chỉ hiển thị + gọi SeasonSystem / QuestSystem; không chứa logic.

var root: Control
var label_header: Label
var pass_list: VBoxContainer
var weekly_list: VBoxContainer
var label_prestige: Label
var btn_prestige: Button
var confirm: ConfirmationDialog

func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	root.visible = false
	EventBus.weekly_quest_updated.connect(func(_q): if root.visible: refresh())
	EventBus.score_updated.connect(func(_a, _b): if root.visible: refresh())

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_P:
			toggle()
		elif event.keycode == KEY_ESCAPE and root.visible:
			root.visible = false

func toggle() -> void:
	root.visible = not root.visible
	if root.visible:
		refresh()

func _build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var panel := PanelContainer.new()
	panel.position = Vector2(240, 50)
	panel.custom_minimum_size = Vector2(800, 620)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.07, 0.08, 0.11, 0.97)
	st.set_corner_radius_all(10)
	st.set_content_margin_all(14)
	st.border_color = Color(0.85, 0.65, 0.25)
	st.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", st)
	root.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)

	label_header = Label.new()
	label_header.add_theme_font_size_override("font_size", 18)
	label_header.modulate = Color(1, 0.85, 0.4)
	vb.add_child(label_header)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(cols)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(440, 0)
	cols.add_child(left)
	left.add_child(_title("🎖 SEASON PASS (mỗi %d Điểm Mùa = 1 bậc)" % SeasonSystem.PASS_POINTS_PER_TIER))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(440, 430)
	left.add_child(scroll)
	pass_list = VBoxContainer.new()
	pass_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pass_list)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(310, 0)
	cols.add_child(right)
	right.add_child(_title("📅 NHIỆM VỤ TUẦN (+%d Điểm Mùa)" % QuestSystem.WEEKLY_SEASON_POINTS))
	weekly_list = VBoxContainer.new()
	right.add_child(weekly_list)
	right.add_child(HSeparator.new())
	right.add_child(_title("♻ TÁI SINH (tự nguyện)"))
	label_prestige = Label.new()
	label_prestige.autowrap_mode = TextServer.AUTOWRAP_WORD
	label_prestige.custom_minimum_size = Vector2(300, 0)
	label_prestige.add_theme_font_size_override("font_size", 12)
	right.add_child(label_prestige)
	btn_prestige = Button.new()
	btn_prestige.text = "TÁI SINH NHÂN VẬT"
	btn_prestige.pressed.connect(func(): confirm.popup_centered())
	right.add_child(btn_prestige)

	var close := Button.new()
	close.text = "Đóng [P]"
	close.pressed.connect(func(): root.visible = false)
	vb.add_child(close)

	confirm = ConfirmationDialog.new()
	confirm.title = "Xác nhận Tái Sinh"
	confirm.dialog_text = "Nhân vật hiện tại sẽ KẾT THÚC VĨNH VIỄN (căn cứ, túi đồ, thiên phú biến mất).\nĐổi lại Account +1 cấp Tái Sinh: nhân vật sau thu thập & nhận rương nhanh hơn +10%.\nTiếp tục?"
	confirm.ok_button_text = "Tái Sinh"
	confirm.confirmed.connect(_do_prestige)
	root.add_child(confirm)

func _title(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 14)
	l.modulate = Color(0.8, 0.9, 1.0)
	return l

func refresh() -> void:
	var acc := SaveSystem.account_data
	var left_s := SeasonSystem.seconds_left_in_season()
	label_header.text = "✦ MÙA GIẢI %d • Tuần %d/%d • còn %d ngày %d giờ • Điểm Mùa: %d • Bậc Pass: %d/%d ✦" % [
		SeasonSystem.season_id(), SeasonSystem.week_in_season(), SeasonSystem.WEEKS_PER_SEASON,
		left_s / 86400, (left_s % 86400) / 3600, int(acc.get("season_sp", 0)),
		SeasonSystem.pass_tier(), SeasonSystem.PASS_REWARDS.size()]

	for ch in pass_list.get_children():
		ch.queue_free()
	for tier in range(1, SeasonSystem.PASS_REWARDS.size() + 1):
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.custom_minimum_size = Vector2(320, 0)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.text = "Bậc %d (%d điểm): %s" % [tier, tier * SeasonSystem.PASS_POINTS_PER_TIER, SeasonSystem.describe_reward(tier)]
		row.add_child(lbl)
		var btn := Button.new()
		if SeasonSystem.is_claimed(tier):
			btn.text = "Đã nhận"
			btn.disabled = true
			lbl.modulate = Color(0.6, 0.6, 0.6)
		elif SeasonSystem.can_claim(tier):
			btn.text = "NHẬN"
			lbl.modulate = Color(0.5, 1.0, 0.5)
			btn.pressed.connect(_claim.bind(tier))
		else:
			btn.text = "Khóa"
			btn.disabled = true
		row.add_child(btn)
		pass_list.add_child(row)

	for ch in weekly_list.get_children():
		ch.queue_free()
	for q in QuestSystem.get_weekly_quests():
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 12)
		l.text = ("✔ " if q.done else "• ") + "%s (%d/%d)" % [q.desc, q.progress, q.target]
		l.modulate = Color(0.5, 1, 0.5) if q.done else Color.WHITE
		weekly_list.add_child(l)

	var reason := SeasonSystem.can_prestige()
	label_prestige.text = "Cấp Tái Sinh hiện tại: %d/%d (hệ số tăng trưởng x%.2f).\nYêu cầu: nhân vật sống tới ngày %d.%s" % [
		SeasonSystem.prestige_level(), SeasonSystem.MAX_PRESTIGE, SeasonSystem.growth_mult(),
		SeasonSystem.PRESTIGE_MIN_DAY, ("\n⚠ " + reason) if reason != "" else ""]
	btn_prestige.disabled = reason != ""

func _claim(tier: int) -> void:
	var player = get_tree().get_first_node_in_group("player")
	var inv = player.get_node_or_null("Inventory") if player else null
	SeasonSystem.claim(tier, inv)
	refresh()

func _do_prestige() -> void:
	var main = get_tree().current_scene
	if main and main.has_method("save_world"):
		main.save_world()
	if SeasonSystem.prestige().is_empty():
		return
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred("res://src/ui/CharacterCreationUI.tscn")
