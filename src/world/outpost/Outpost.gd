extends Node2D

signal outpost_captured(outpost_name: String, pos: Vector2)

@export var outpost_name: String = "Trạm Gác Cổ Rừng Sâu"
@export var passive_wood: int = 8
@export var passive_stone: int = 5
@export var passive_iron: int = 2

enum OutpostState {
	ABANDONED,
	CAPTURING,
	CAPTURED
}

var state: OutpostState = OutpostState.ABANDONED
var capture_timer: float = 0.0
var capture_duration: float = 8.0 # 8 seconds to capture
var is_player_inside: bool = false
var player_ref: CharacterBody2D = null

@onready var capture_area: Area2D = $CaptureArea
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var label_status: Label = $LabelStatus
@onready var flag_sprite: Sprite2D = $FlagSprite
@onready var prompt_warp: Label = $PromptWarp

func _ready() -> void:
	progress_bar.max_value = capture_duration
	progress_bar.value = 0.0
	progress_bar.visible = false
	prompt_warp.visible = false
	label_status.text = "⚔ " + outpost_name + " (Chưa chiếm đóng)"
	label_status.modulate = Color(1.0, 0.4, 0.4)
	
	capture_area.body_entered.connect(_on_body_entered)
	capture_area.body_exited.connect(_on_body_exited)
	
	# Sản lượng thụ động được GameState cộng vào rương tổng kết cuối ngày
	# (xem GameState.get_outpost_income), không cộng trực tiếp ở đây nữa.

## Khôi phục trạng thái đã chiếm từ save (không cộng SP lại).
func restore_captured() -> void:
	state = OutpostState.CAPTURED
	progress_bar.visible = false
	label_status.text = "🏰 " + outpost_name + " (ĐÃ THU PHỤC)"
	label_status.modulate = Color(0.4, 1.0, 0.5)
	flag_sprite.modulate = Color(0.4, 1.2, 0.6)

func _process(delta: float) -> void:
	if state == OutpostState.CAPTURED:
		return
		
	if is_player_inside and state != OutpostState.CAPTURED:
		state = OutpostState.CAPTURING
		capture_timer += delta
		progress_bar.visible = true
		progress_bar.value = capture_timer
		label_status.text = "Đang cắm cờ chiếm cứ điểm... (%d%%)" % int((capture_timer / capture_duration) * 100.0)
		label_status.modulate = Color(1.0, 0.85, 0.3)
		
		if capture_timer >= capture_duration:
			_finish_capture()
	elif not is_player_inside and state == OutpostState.CAPTURING:
		capture_timer = max(0.0, capture_timer - delta * 2.0)
		progress_bar.value = capture_timer
		if capture_timer <= 0.0:
			state = OutpostState.ABANDONED
			progress_bar.visible = false
			label_status.text = "⚔ " + outpost_name + " (Chưa chiếm đóng)"
			label_status.modulate = Color(1.0, 0.4, 0.4)

func _finish_capture() -> void:
	state = OutpostState.CAPTURED
	progress_bar.visible = false
	label_status.text = "🏰 " + outpost_name + " (ĐÃ THU PHỤC)"
	label_status.modulate = Color(0.4, 1.0, 0.5)
	flag_sprite.modulate = Color(0.4, 1.2, 0.6)
	
	# Award SP and emit
	if GameState:
		GameState.add_sp(25, "Chiếm đóng " + outpost_name)
		
	outpost_captured.emit(outpost_name, global_position)
	_show_capture_banner()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		is_player_inside = true
		player_ref = body as CharacterBody2D
		if state == OutpostState.CAPTURED:
			prompt_warp.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		is_player_inside = false
		prompt_warp.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if is_player_inside and state == OutpostState.CAPTURED:
		if event is InputEventKey and event.pressed and event.keycode == KEY_E:
			_warp_to_campfire()

func _warp_to_campfire() -> void:
	if not player_ref: return
	var parent_world = get_parent()
	if parent_world:
		var fire = parent_world.get_node_or_null("Campfire")
		if fire:
			player_ref.global_position = fire.global_position + Vector2(20, 20)
			_spawn_warp_fx(player_ref.global_position)

func _spawn_warp_fx(pos: Vector2) -> void:
	var label = Label.new()
	label.text = "✦ TRUYỀN TỐNG VỀ CĂN CỨ THÀNH CÔNG! ✦"
	label.top_level = true
	label.global_position = pos + Vector2(-120, -50)
	label.modulate = Color(0.5, 0.9, 1.0)
	label.add_theme_font_size_override("font_size", 14)
	get_parent().add_child(label)
	var tween = label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 25.0, 1.2)
	tween.tween_property(label, "modulate:a", 0.0, 1.2)
	tween.chain().tween_callback(label.queue_free)

func _on_dawn_passive_production(_day_num: int) -> void:
	if state == OutpostState.CAPTURED and player_ref:
		var inv = player_ref.get_node_or_null("Inventory")
		if inv and inv.has_method("add_resource"):
			inv.add_resource("Gỗ", passive_wood)
			inv.add_resource("Đá", passive_stone)
			inv.add_resource("Quặng Sắt", passive_iron)

func _show_capture_banner() -> void:
	var canvas = CanvasLayer.new()
	var container = CenterContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	var vbox = VBoxContainer.new()
	var lbl = Label.new()
	lbl.text = "✦ THU PHỤC CỨ ĐIỂM TIỀN TIÊU THÀNH CÔNG! (+25 SP) ✦\nSáp nhập lãnh thổ • Cung cấp tài nguyên thụ động mỗi rạng đông"
	lbl.modulate = Color(0.4, 1.0, 0.5)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	vbox.add_child(lbl)
	container.add_child(vbox)
	canvas.add_child(container)
	get_parent().add_child(canvas)
	var tween = canvas.create_tween()
	tween.tween_property(container, "modulate:a", 1.0, 0.5).from(0.0)
	tween.tween_interval(2.5)
	tween.tween_property(container, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(canvas.queue_free)
