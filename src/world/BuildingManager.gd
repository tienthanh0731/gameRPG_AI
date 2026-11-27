extends Node2D

const WallScene = preload("res://src/world/structures/WoodenWall.tscn")
const DoorScene = preload("res://src/world/structures/WoodenDoor.tscn")
const SpikeScene = preload("res://src/world/structures/SpikeTrap.tscn")

enum BuildType {
	NONE,
	WALL,
	DOOR,
	SPIKE
}

@export var is_building: bool = false
var current_build: BuildType = BuildType.WALL

var preview_sprite: Sprite2D
var tex_wall: Texture2D
var tex_door: Texture2D
var tex_spike: Texture2D

var player: CharacterBody2D
var inventory: Node
var hud: CanvasLayer

func _ready() -> void:
	_init_preview_sprite()

func _init_preview_sprite() -> void:
	if not preview_sprite:
		preview_sprite = Sprite2D.new()
		preview_sprite.modulate = Color(1.0, 1.0, 1.0, 0.6)
		preview_sprite.visible = false
		preview_sprite.z_index = 5
		add_child(preview_sprite)
		
	var p_wall = "res://assets/buildings/structures/wall_wood.png"
	var p_door = "res://assets/buildings/structures/door_wood_closed.png"
	var p_spike = "res://assets/buildings/structures/spike_trap.png"
	if ResourceLoader.exists(p_wall): tex_wall = load(p_wall)
	if ResourceLoader.exists(p_door): tex_door = load(p_door)
	if ResourceLoader.exists(p_spike): tex_spike = load(p_spike)

func setup(p_player: CharacterBody2D, p_hud: CanvasLayer) -> void:
	player = p_player
	hud = p_hud
	if player:
		inventory = player.get_node_or_null("Inventory")

func _ensure_references() -> void:
	if not player and get_parent():
		player = get_parent().get_node_or_null("Player")
	if player and not inventory:
		inventory = player.get_node_or_null("Inventory")
	if not hud and get_parent():
		hud = get_parent().get_node_or_null("HUD")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_B:
			toggle_building_mode()
		elif is_building:
			if event.keycode == KEY_4:
				select_build(BuildType.WALL)
			elif event.keycode == KEY_5:
				select_build(BuildType.DOOR)
			elif event.keycode == KEY_6:
				select_build(BuildType.SPIKE)
			elif event.keycode == KEY_U:
				_try_upgrade_structure()
		elif event.keycode == KEY_E:
			_try_interact_door()
			
	if is_building and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_try_place_structure()

func toggle_building_mode() -> void:
	_ensure_references()
	if not preview_sprite:
		_init_preview_sprite()
	is_building = not is_building
	if preview_sprite:
		preview_sprite.visible = is_building
	if is_building:
		select_build(BuildType.WALL)
		if hud and hud.has_method("update_tool"):
			hud.update_tool(3) # Building mode index
		_spawn_hint("[U] Nâng cấp công trình dưới chuột: Gỗ→Đá (6 Đá) → Sắt (4 Đá + 4 Sắt)", Color(0.8, 0.9, 1.0))
	else:
		if player and player.has_signal("tool_changed"):
			player.tool_changed.emit(player.current_tool)

func select_build(type: BuildType) -> void:
	current_build = type
	if not preview_sprite:
		_init_preview_sprite()
	match current_build:
		BuildType.WALL:
			preview_sprite.texture = tex_wall
			preview_sprite.offset = Vector2(0, -16)
		BuildType.DOOR:
			preview_sprite.texture = tex_door
			preview_sprite.offset = Vector2(0, -16)
		BuildType.SPIKE:
			preview_sprite.texture = tex_spike
			preview_sprite.offset = Vector2(0, -12)

func _process(_delta: float) -> void:
	_ensure_references()
	if not is_building or not player:
		return
		
	var mouse_pos = get_global_mouse_position()
	var grid_pos = Vector2(
		round(mouse_pos.x / 64.0) * 64.0,
		round(mouse_pos.y / 64.0) * 64.0
	)
	if preview_sprite:
		preview_sprite.global_position = grid_pos
	
	# Check distance to player and affordability
	var dist = grid_pos.distance_to(player.global_position)
	var can_afford = _can_afford_current()
	var in_range = dist <= 240.0
	
	if preview_sprite:
		if in_range and can_afford:
			preview_sprite.modulate = Color(0.4, 1.0, 0.4, 0.7)
		else:
			preview_sprite.modulate = Color(1.0, 0.3, 0.3, 0.7)

func _can_afford_current() -> bool:
	_ensure_references()
	if not inventory:
		return false
	match current_build:
		BuildType.WALL:
			return inventory.has_resources(4, 0)
		BuildType.DOOR:
			return inventory.has_resources(6, 2)
		BuildType.SPIKE:
			return inventory.has_resources(3, 1)
	return false

func _try_place_structure() -> void:
	_ensure_references()
	if not player or not _can_afford_current():
		_spawn_hint("Không đủ tài nguyên xây dựng!", Color(1.0, 0.3, 0.3))
		return
		
	var mouse_pos = get_global_mouse_position()
	var grid_pos = Vector2(
		round(mouse_pos.x / 64.0) * 64.0,
		round(mouse_pos.y / 64.0) * 64.0
	)
	
	if grid_pos.distance_to(player.global_position) > 240.0:
		_spawn_hint("Vị trí quá xa!", Color(1.0, 0.4, 0.4))
		return

	var struct_instance: Node2D = null
	match current_build:
		BuildType.WALL:
			inventory.consume_resources(4, 0)
			struct_instance = WallScene.instantiate()
		BuildType.DOOR:
			inventory.consume_resources(6, 2)
			struct_instance = DoorScene.instantiate()
		BuildType.SPIKE:
			inventory.consume_resources(3, 1)
			struct_instance = SpikeScene.instantiate()
			
	if struct_instance:
		for existing in get_tree().get_nodes_in_group("structure"):
			if existing is Node2D and existing.global_position.distance_to(grid_pos) < 8.0:
				struct_instance.free()
				_spawn_hint("Ô này đã có công trình!", Color(1.0, 0.4, 0.4))
				return
		_add_structure(struct_instance, int(current_build), grid_pos, -1)
		EventBus.structure_placed.emit(int(current_build), grid_pos)
		_spawn_hint("XÂY DỰNG THÀNH CÔNG!", Color(0.4, 1.0, 0.4))

# ==========================================
# LƯU / KHÔI PHỤC CĂN CỨ (thuộc tầng Character, mất khi chết)
# ==========================================
func _add_structure(inst: Node2D, build_type: int, pos: Vector2, hp: int, tier: int = 0) -> void:
	inst.global_position = pos
	inst.set_meta("build_type", build_type)
	get_parent().add_child(inst)
	if tier > 0 and inst.has_method("set_tier"):
		inst.set_tier(tier, false)
	if hp > 0 and "current_health" in inst:
		inst.current_health = mini(hp, inst.max_health)
		inst.queue_redraw()
	if inst.has_signal("structure_destroyed"):
		inst.structure_destroyed.connect(func(): EventBus.structure_destroyed.emit(pos))

func _scene_for(build_type: int) -> PackedScene:
	match build_type:
		BuildType.DOOR: return DoorScene
		BuildType.SPIKE: return SpikeScene
	return WallScene

func serialize_structures() -> Array:
	var out: Array = []
	for st in get_tree().get_nodes_in_group("structure"):
		if st is Node2D and is_instance_valid(st) and not st.is_queued_for_deletion() and st.has_meta("build_type"):
			if "current_health" in st and st.current_health <= 0:
				continue
			out.append({
				"type": int(st.get_meta("build_type")),
				"x": st.global_position.x, "y": st.global_position.y,
				"hp": int(st.current_health) if "current_health" in st else -1,
				"tier": int(st.tier) if "tier" in st else 0,
			})
	return out

func restore_structures(list: Array) -> void:
	for d in list:
		var t := int(d.get("type", BuildType.WALL))
		_add_structure(_scene_for(t).instantiate(), t, Vector2(float(d.get("x", 0)), float(d.get("y", 0))), int(d.get("hp", -1)), int(d.get("tier", 0)))

# ==========================================
# NÂNG CẤP CÔNG TRÌNH (Gỗ → Đá → Sắt) — +15 SP mỗi lần
# ==========================================
func _structure_at(world_pos: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := 40.0
	for st in get_tree().get_nodes_in_group("structure"):
		if st is Node2D and is_instance_valid(st) and st.has_method("set_tier"):
			var d: float = st.global_position.distance_to(world_pos)
			if d < best_d:
				best_d = d
				best = st
	return best

func _try_upgrade_structure() -> void:
	_ensure_references()
	var mouse_pos := get_global_mouse_position()
	var grid_pos := Vector2(round(mouse_pos.x / 64.0) * 64.0, round(mouse_pos.y / 64.0) * 64.0)
	upgrade_structure(_structure_at(grid_pos))

## Trả về true nếu nâng cấp thành công. Tách riêng để test gọi trực tiếp.
func upgrade_structure(st: Node2D) -> bool:
	_ensure_references()
	if not st:
		_spawn_hint("Không có công trình dưới chuột!", Color(1.0, 0.4, 0.4))
		return false
	if not st.can_upgrade():
		_spawn_hint("%s đã ở bậc tối đa!" % st.get_display_name(), Color(1.0, 0.8, 0.3))
		return false
	if player and st.global_position.distance_to(player.global_position) > 240.0:
		_spawn_hint("Công trình quá xa!", Color(1.0, 0.4, 0.4))
		return false
	var cost: Dictionary = st.get_upgrade_cost()
	if not inventory or not inventory.consume_resources(int(cost.wood), int(cost.stone), int(cost.iron)):
		_spawn_hint("Thiếu nguyên liệu: cần %d Đá, %d Sắt" % [cost.stone, cost.iron], Color(1.0, 0.3, 0.3))
		return false
	st.set_tier(st.tier + 1, true)
	GameState.add_sp(15, "Nâng cấp công trình")
	EventBus.structure_upgraded.emit(int(st.tier), st.global_position)
	_spawn_hint("NÂNG CẤP: %s" % st.get_display_name(), Color(0.5, 0.9, 1.0))
	return true

func _try_interact_door() -> void:
	if not player:
		return
	var doors = get_tree().get_nodes_in_group("door")
	for door in doors:
		if door is Node2D and door.global_position.distance_to(player.global_position) <= 75.0:
			if door.has_method("toggle_door"):
				door.toggle_door()
				return

func _spawn_hint(text: String, col: Color) -> void:
	if not player: return
	var label = Label.new()
	label.text = text
	label.top_level = true
	label.global_position = player.global_position + Vector2(-60, -45)
	label.modulate = col
	label.add_theme_font_size_override("font_size", 13)
	get_parent().add_child(label)
	var tween = label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 25.0, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7)
	tween.chain().tween_callback(label.queue_free)
