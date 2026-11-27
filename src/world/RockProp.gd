extends StaticBody2D

signal rock_mined(stone_amount: int, iron_amount: int, drop_pos: Vector2)

@export var max_health: int = 3
var current_health: int = 3
var is_destroyed: bool = false

func _ready() -> void:
	current_health = max_health

func take_hit(tool_id: int = 1) -> void:
	if is_destroyed:
		return
		
	if tool_id != 1: # 1 is PICKAXE
		_spawn_hint_text("Cần Cuốc Đào Mỏ (Phím 2)!")
		_play_clink_effect()
		return

	current_health -= 1
	_play_shake_effect()
	
	if current_health <= 0:
		_break_apart()

func _play_shake_effect() -> void:
	var spr = get_node_or_null("Sprite2D")
	if spr:
		var orig_scale = spr.scale
		var tween = create_tween()
		tween.tween_property(spr, "scale", orig_scale * 1.15, 0.04)
		tween.tween_property(spr, "scale", orig_scale * 0.9, 0.04)
		tween.tween_property(spr, "scale", orig_scale, 0.04)

func _play_clink_effect() -> void:
	var spr = get_node_or_null("Sprite2D")
	if spr:
		var tween = create_tween()
		tween.tween_property(spr, "modulate", Color(1.5, 0.8, 0.8), 0.05)
		tween.tween_property(spr, "modulate", Color.WHITE, 0.08)

func _break_apart() -> void:
	is_destroyed = true
	var col = get_node_or_null("CollisionShape2D")
	if col:
		col.set_deferred("disabled", true)
		
	var stone_amount = randi_range(2, 4)
	var iron_amount = 1 if randf() < 0.35 else 0
	rock_mined.emit(stone_amount, iron_amount, global_position)
	
	var spr = get_node_or_null("Sprite2D")
	if spr:
		var tween = create_tween()
		tween.tween_property(spr, "modulate:a", 0.0, 0.15)
		tween.tween_callback(queue_free)
	else:
		queue_free()

func _spawn_hint_text(text: String) -> void:
	var label = Label.new()
	label.text = text
	label.top_level = true
	label.global_position = global_position + Vector2(-40, -40)
	label.modulate = Color(1.0, 0.4, 0.4)
	label.add_theme_font_size_override("font_size", 12)
	var parent_node = get_parent()
	if parent_node:
		parent_node.add_child(label)
		var tween = label.create_tween().set_parallel(true)
		tween.tween_property(label, "position:y", label.position.y - 20.0, 0.5)
		tween.tween_property(label, "modulate:a", 0.0, 0.5)
		tween.chain().tween_callback(label.queue_free)
