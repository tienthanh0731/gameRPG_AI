extends StaticBody2D
## Công trình căn cứ (tường / cổng / bẫy) với 3 bậc vật liệu: Gỗ → Đá → Sắt.
## Mỗi bậc nhân máu tối đa; thanh máu hiện ra khi công trình bị đánh.

signal structure_destroyed()
signal health_changed(current: int, max_hp: int)

enum StructureType {
	WALL,
	DOOR,
	SPIKE
}

const TIER_NAMES: Array[String] = ["Gỗ", "Đá", "Sắt"]
const TIER_HP_MULT: Array[float] = [1.0, 2.5, 5.0]
const TIER_TINT: Array[Color] = [Color(1, 1, 1), Color(0.72, 0.74, 0.78), Color(0.55, 0.62, 0.85)]
const MAX_TIER: int = 2

@export var structure_type: StructureType = StructureType.WALL
@export var structure_name: String = "Tường Gỗ"
@export var max_health: int = 60
var current_health: int = 60
var base_max_health: int = 60
var tier: int = 0

var is_open: bool = false
var tex_closed: Texture2D
var tex_open: Texture2D

func _ready() -> void:
	base_max_health = max_health
	_recalc_max_health()
	current_health = max_health
	if structure_type == StructureType.DOOR:
		tex_closed = load("res://assets/buildings/structures/door_wood_closed.png")
		tex_open = load("res://assets/buildings/structures/door_wood_open.png")
	elif structure_type == StructureType.SPIKE:
		var trap_area = get_node_or_null("TrapArea")
		if trap_area:
			trap_area.body_entered.connect(_on_trap_body_entered)

func _recalc_max_health() -> void:
	var talent_mult := 1.0
	if GameState and GameState.has_method("get_structure_hp_mult"):
		talent_mult = GameState.get_structure_hp_mult()
	max_health = int(round(base_max_health * TIER_HP_MULT[tier] * talent_mult))

## Đặt bậc vật liệu. keep_ratio=true giữ nguyên % máu (dùng khi nâng cấp).
func set_tier(new_tier: int, keep_ratio: bool = true) -> void:
	var ratio := float(current_health) / maxf(1.0, float(max_health))
	tier = clampi(new_tier, 0, MAX_TIER)
	_recalc_max_health()
	current_health = max_health if not keep_ratio else maxi(1, int(round(max_health * ratio)))
	var spr = get_node_or_null("Sprite2D")
	if spr:
		spr.self_modulate = TIER_TINT[tier]
	health_changed.emit(current_health, max_health)
	queue_redraw()

func get_display_name() -> String:
	var base := ["Tường", "Cổng", "Bẫy Chông"][int(structure_type)] as String
	return "%s %s" % [base, TIER_NAMES[tier]]

## Chi phí lên bậc tiếp theo {wood, stone, iron}; {} nếu đã tối đa.
func get_upgrade_cost() -> Dictionary:
	match tier:
		0: return { "wood": 0, "stone": 6, "iron": 0 }
		1: return { "wood": 0, "stone": 4, "iron": 4 }
	return {}

func can_upgrade() -> bool:
	return tier < MAX_TIER

func _on_trap_body_entered(body: Node2D) -> void:
	if structure_type == StructureType.SPIKE and body.is_in_group("enemy"):
		if body.has_method("take_hit"):
			body.take_hit(2)
			take_damage(10)

func take_damage(amount: int) -> void:
	current_health -= amount
	health_changed.emit(maxi(current_health, 0), max_health)
	EventBus.structure_damaged.emit(get_instance_id(), maxi(current_health, 0), max_health)
	queue_redraw()
	_play_shake_effect()
	if current_health <= 0:
		_destroy()

func _draw() -> void:
	# Thanh máu công trình (chỉ khi bị thương)
	if current_health >= max_health or current_health <= 0:
		return
	var w := 44.0
	var pos := Vector2(-w / 2.0, -52.0)
	var ratio := float(current_health) / float(max_health)
	draw_rect(Rect2(pos, Vector2(w, 5)), Color(0, 0, 0, 0.7))
	var col := Color(0.3, 0.9, 0.3) if ratio > 0.5 else (Color(1, 0.75, 0.2) if ratio > 0.25 else Color(1, 0.3, 0.25))
	draw_rect(Rect2(pos, Vector2(w * ratio, 5)), col)

func toggle_door() -> void:
	if structure_type != StructureType.DOOR:
		return
	is_open = not is_open
	var col = get_node_or_null("CollisionShape2D")
	if col:
		col.set_deferred("disabled", is_open)
	var spr = get_node_or_null("Sprite2D")
	if spr:
		spr.texture = tex_open if is_open else tex_closed

	var hint = "CỔNG ĐÃ MỞ (E để đóng)" if is_open else "CỔNG ĐÃ ĐÓNG (E để mở)"
	_spawn_hint_text(hint)

func _play_shake_effect() -> void:
	var spr = get_node_or_null("Sprite2D")
	if spr:
		var tween = create_tween()
		tween.tween_property(spr, "rotation_degrees", 5.0, 0.04)
		tween.tween_property(spr, "rotation_degrees", -5.0, 0.04)
		tween.tween_property(spr, "rotation_degrees", 0.0, 0.04)

func _destroy() -> void:
	structure_destroyed.emit()
	var col = get_node_or_null("CollisionShape2D")
	if col:
		col.set_deferred("disabled", true)
	var spr = get_node_or_null("Sprite2D")
	if spr:
		var tween = create_tween()
		tween.tween_property(spr, "modulate:a", 0.0, 0.2)
		tween.tween_callback(queue_free)
	else:
		queue_free()

func _spawn_hint_text(text: String) -> void:
	var label = Label.new()
	label.text = text
	label.top_level = true
	label.global_position = global_position + Vector2(-40, -35)
	label.modulate = Color(1.0, 0.9, 0.3)
	label.add_theme_font_size_override("font_size", 12)
	var parent_node = get_parent()
	if parent_node:
		parent_node.add_child(label)
		var tween = label.create_tween().set_parallel(true)
		tween.tween_property(label, "position:y", label.position.y - 20.0, 0.6)
		tween.tween_property(label, "modulate:a", 0.0, 0.6)
		tween.chain().tween_callback(label.queue_free)
