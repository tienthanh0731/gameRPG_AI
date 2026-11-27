extends CanvasLayer
## Bảng theo dõi nhiệm vụ ngày. Autoload UI: tự hiện khi đang chơi (Main / phó bản),
## chỉ đọc dữ liệu từ QuestSystem qua EventBus — không chứa logic.

const SHOWN_IN_SCENES: Array[String] = ["Main", "DungeonScene"]

var panel: PanelContainer
var list_box: VBoxContainer
var check_timer: float = 0.0

func _ready() -> void:
	layer = 4
	panel = PanelContainer.new()
	panel.position = Vector2(16, 300)
	panel.custom_minimum_size = Vector2(250, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.08, 0.72)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	var title := Label.new()
	title.text = "📜 NHIỆM VỤ NGÀY (+20 SP mỗi cái)"
	title.add_theme_font_size_override("font_size", 13)
	title.modulate = Color(1, 0.85, 0.4)
	vb.add_child(title)
	list_box = VBoxContainer.new()
	vb.add_child(list_box)
	add_child(panel)
	panel.visible = false
	EventBus.quest_updated.connect(_render)
	EventBus.day_started.connect(func(_d): _refresh())

func _process(delta: float) -> void:
	check_timer -= delta
	if check_timer > 0.0:
		return
	check_timer = 0.5
	var scene := get_tree().current_scene
	var should_show := scene != null and scene.name in SHOWN_IN_SCENES and SaveSystem.has_active_character() and not GameState.is_dead
	if should_show and not panel.visible:
		_refresh()
	panel.visible = should_show

func _refresh() -> void:
	_render(QuestSystem.get_today_quests())

func _render(quests: Array) -> void:
	for ch in list_box.get_children():
		ch.queue_free()
	for q in quests:
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 12)
		if q.get("done", false):
			lbl.text = "✔ %s" % q.desc
			lbl.modulate = Color(0.5, 1.0, 0.5)
		else:
			lbl.text = "• %s  (%d/%d)" % [q.desc, q.progress, q.target]
		list_box.add_child(lbl)
