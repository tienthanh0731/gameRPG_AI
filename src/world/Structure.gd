extends StaticBody2D

signal structure_destroyed()

enum StructureType {
	WALL,
	DOOR,
	SPIKE
}

@export var structure_type: StructureType = StructureType.WALL
@export var structure_name: String = "Tường Gỗ"
@export var max_health: int = 60
var current_health: int = 60

var is_open: bool = false
var tex_closed: Texture2D
var tex_open: Texture2D

func _ready() -> void:
	current_health = max_health
	if structure_type == StructureType.DOOR:
		tex_closed = load("res://assets/buildings/structures/door_wood_closed.png")
		tex_open = load("res://assets/buildings/structures/door_wood_open.png")
	elif structure_type == StructureType.SPIKE:
		var trap_area = get_node_or_null("TrapArea")
		if trap_area:
			trap_area.body_entered.connect(_on_trap_body_entered)

func _on_trap_body_entered(body: Node2D) -> void:
	if structure_type == StructureType.SPIKE and body.is_in_group("enemy"):
		if body.has_method("take_hit"):
			body.take_hit(2)
			take_damage(10)

func take_damage(amount: int) -> void:
	current_health -= amount
	_play_shake_effect()
	if current_health <= 0:
		_destroy()

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
