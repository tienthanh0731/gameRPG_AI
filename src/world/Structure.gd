extends StaticBody2D

signal structure_destroyed()

enum StructureType {
	WALL,
	DOOR,
	SPIKE,
	HOUSE
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

# ==========================================
# PHÁ BỎ CÔNG TRÌNH BẰNG CÔNG CỤ (RÌU, CUỐC)
# ==========================================
func take_hit(tool_id: int = 0) -> void:
	var dmg = 20
	var tool_name = "Công cụ"
	if tool_id == 0: # AXE - Rìu chuyên chặt gỗ & dỡ công trình gỗ
		dmg = 35
		tool_name = "Rìu"
	elif tool_id == 1: # PICKAXE
		dmg = 25
		tool_name = "Cuốc"
	elif tool_id == 2: # SWORD
		dmg = 10
		tool_name = "Kiếm"
		
	current_health -= dmg
	_play_shake_effect()
	_spawn_hint_text("-%d HP (%d/%d)" % [dmg, max(0, current_health), max_health], Color(1.0, 0.4, 0.3))
	
	if current_health <= 0:
		demolish(true)

func demolish(refund: bool = true) -> void:
	if refund:
		_refund_resources()
		_spawn_hint_text("ĐÃ PHÁ DỠ %s (+Hoàn trả)!" % structure_name, Color(0.4, 1.0, 0.4))
	_destroy()

func _refund_resources() -> void:
	var parent_node = get_parent()
	if not parent_node: return
	
	var drops: Array = []
	match structure_type:
		StructureType.WALL:
			drops.append({"name": "Gỗ", "amount": 3})
		StructureType.DOOR:
			drops.append({"name": "Gỗ", "amount": 4})
			drops.append({"name": "Đá", "amount": 1})
		StructureType.SPIKE:
			drops.append({"name": "Gỗ", "amount": 2})
			drops.append({"name": "Đá", "amount": 1})
		StructureType.HOUSE:
			drops.append({"name": "Gỗ", "amount": 15})
			drops.append({"name": "Đá", "amount": 5})
			
	var item_scene = load("res://src/world/DroppedItem.tscn")
	var tex_wood = load("res://assets/ui_icons/rpg_icons_32x32/wood_01a.png") if ResourceLoader.exists("res://assets/ui_icons/rpg_icons_32x32/wood_01a.png") else null
	var tex_stone = load("res://assets/ui_icons/rpg_icons_32x32/stoneblock_01a.png") if ResourceLoader.exists("res://assets/ui_icons/rpg_icons_32x32/stoneblock_01a.png") else null
	
	for d in drops:
		if item_scene:
			var item = item_scene.instantiate()
			item.global_position = global_position + Vector2(randf_range(-16.0, 16.0), randf_range(-12.0, 12.0))
			parent_node.add_child(item)
			var tex = tex_wood if d["name"] == "Gỗ" else tex_stone
			item.setup(d["name"], d["amount"], tex)

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
		var orig_rot = spr.rotation_degrees
		var tween = create_tween()
		tween.tween_property(spr, "rotation_degrees", orig_rot + 5.0, 0.04)
		tween.tween_property(spr, "rotation_degrees", orig_rot - 5.0, 0.04)
		tween.tween_property(spr, "rotation_degrees", orig_rot, 0.04)

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

func _spawn_hint_text(text: String, col: Color = Color(1.0, 0.9, 0.3)) -> void:
	var label = Label.new()
	label.text = text
	label.top_level = true
	label.global_position = global_position + Vector2(-50, -40)
	label.modulate = col
	label.add_theme_font_size_override("font_size", 12)
	var parent_node = get_parent()
	if parent_node:
		parent_node.add_child(label)
		var tween = label.create_tween().set_parallel(true)
		tween.tween_property(label, "position:y", label.position.y - 22.0, 0.65)
		tween.tween_property(label, "modulate:a", 0.0, 0.65)
		tween.chain().tween_callback(label.queue_free)
