extends StaticBody2D

signal tree_chopped(wood_amount: int, drop_pos: Vector2)

@export var max_health: int = 3
var current_health: int = 3
var is_stump: bool = false
var stump_texture: Texture2D

func _ready() -> void:
	current_health = max_health
	if not stump_texture:
		var stump_path = "res://assets/raw_packs/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Resources/Wood/Trees/Stump 1.png"
		if ResourceLoader.exists(stump_path):
			stump_texture = load(stump_path)

func take_hit(tool_id: int = 0) -> void:
	if is_stump:
		return
		
	if tool_id != 0: # 0 is AXE
		_spawn_hint_text("Cần Rìu Đốn Củi (Phím 1)!")
		_play_clink_effect()
		return

	current_health -= 1
	_play_shake_effect()
	
	if current_health <= 0:
		_fall_down()

func _play_shake_effect() -> void:
	var spr = get_node_or_null("Sprite2D")
	if spr:
		var tween = create_tween()
		tween.tween_property(spr, "rotation_degrees", 8.0, 0.04)
		tween.tween_property(spr, "rotation_degrees", -8.0, 0.04)
		tween.tween_property(spr, "rotation_degrees", 4.0, 0.04)
		tween.tween_property(spr, "rotation_degrees", 0.0, 0.04)

func _play_clink_effect() -> void:
	var spr = get_node_or_null("Sprite2D")
	if spr:
		var tween = create_tween()
		tween.tween_property(spr, "modulate", Color(1.5, 0.8, 0.8), 0.05)
		tween.tween_property(spr, "modulate", Color.WHITE, 0.08)

func _fall_down() -> void:
	is_stump = true
	var spr = get_node_or_null("Sprite2D")
	if spr:
		if stump_texture:
			spr.hframes = 1
			spr.frame = 0
			spr.texture = stump_texture
			spr.offset = Vector2(0, -96)
			spr.scale = Vector2(0.55, 0.55)
		else:
			spr.visible = false
			
	var col = get_node_or_null("CollisionShape2D")
	if col:
		col.set_deferred("disabled", true)
		
	var wood_amount = randi_range(3, 5)
	tree_chopped.emit(wood_amount, global_position)

func _spawn_hint_text(text: String) -> void:
	var label = Label.new()
	label.text = text
	label.top_level = true
	label.global_position = global_position + Vector2(-40, -60)
	label.modulate = Color(1.0, 0.4, 0.4)
	label.add_theme_font_size_override("font_size", 12)
	var parent_node = get_parent()
	if parent_node:
		parent_node.add_child(label)
		var tween = label.create_tween().set_parallel(true)
		tween.tween_property(label, "position:y", label.position.y - 20.0, 0.5)
		tween.tween_property(label, "modulate:a", 0.0, 0.5)
		tween.chain().tween_callback(label.queue_free)
