extends StaticBody2D
const EquipmentData = preload("res://src/data/EquipmentData.gd") # preload: không phụ thuộc cache class_name

signal tree_chopped(wood_amount: int, drop_pos: Vector2)

@export var max_health: int = 3
var current_health: int = 3
var is_stump: bool = false
var stump_texture: Texture2D
## Loại cây (độ cứng vật liệu) — xem EquipmentData.TREE_KINDS
var kind: Dictionary = {}
var bonus_yield: int = 0

func _ready() -> void:
	# Loại cây cố định theo vị trí (cùng seed map → cùng loại cây)
	var r := float(absi(hash(Vector2i(position))) % 1000) / 1000.0
	kind = EquipmentData.pick_tree_kind(r)
	max_health = int(kind.toughness)
	current_health = max_health
	var spr = get_node_or_null("Sprite2D")
	if spr:
		spr.scale *= float(kind.scale)
		if int(kind.min_tier) > 0:
			spr.modulate = Color(0.8, 0.95, 0.75)
	if not stump_texture:
		var stump_path = "res://assets/raw_packs/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Resources/Wood/Trees/Stump 1.png"
		if ResourceLoader.exists(stump_path):
			stump_texture = load(stump_path)

func take_hit(tool_id: int = 0) -> void:
	harvest_hit(tool_id, int(EquipmentData.TIER_STATS[0].power), 0, 0)

## Một nhát khai thác. Trả về bậc cứng của vật liệu nếu nhát được tính
## (để Player trừ độ bền), hoặc -1 nếu sai công cụ / công cụ quá yếu.
func harvest_hit(tool_id: int, power: int, tool_tier: int, yield_bonus: int) -> int:
	if is_stump:
		return -1
	if tool_id != 0: # 0 is AXE
		_spawn_hint_text("Cần Rìu Đốn Củi (Phím 1)!")
		_play_clink_effect()
		return -1
	if tool_tier < int(kind.min_tier):
		_spawn_hint_text("%s quá cứng — cần Rìu %s trở lên!" % [kind.name, EquipmentData.TIER_NAMES[int(kind.min_tier)]])
		_play_clink_effect()
		return -1
	current_health -= power
	bonus_yield = yield_bonus
	_play_shake_effect()
	if current_health <= 0:
		_fall_down()
	return int(kind.hardness)

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
		
	var wood_amount = randi_range(int(kind.wood[0]), int(kind.wood[1])) + bonus_yield
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
