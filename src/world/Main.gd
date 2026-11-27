extends Node2D
## Main — scene thế giới mở. Nối các hệ thống (map, player, ngày/đêm, thú triều,
## xây dựng, phó bản) và đẩy dữ liệu lên HUD. Không chứa công thức gameplay
## (nằm ở GameState) hay lưu trữ (SaveSystem).

const DroppedItemScene = preload("res://src/world/DroppedItem.tscn")
const DungeonEntranceScene = preload("res://src/dungeon/DungeonEntrance.tscn")
const OutpostScene = preload("res://src/world/outpost/Outpost.tscn")

const AUTOSAVE_INTERVAL: float = 30.0

@onready var map_gen: Node2D = $MapGenerator
@onready var player: CharacterBody2D = $Player
@onready var day_night: CanvasModulate = $DayNightCycle
@onready var hud: CanvasLayer = $HUD
@onready var campfire: Area2D = $Campfire
@onready var building_mgr: Node2D = $BuildingManager
@onready var raid_mgr: Node2D = $RaidManager

var current_biome_temp: float = 28.0
var base_pos: Vector2 = Vector2.ZERO
var dungeon_nodes: Array[Node2D] = []
var autosave_timer: float = 0.0
var outpost_node: Node2D = null

var tex_wood_icon: Texture2D
var tex_stone_icon: Texture2D
var tex_iron_icon: Texture2D
var tex_meat_icon: Texture2D
var tex_bone_icon: Texture2D
var tex_pill_icon: Texture2D

func _ready() -> void:
	# Không có nhân vật sống → quay về màn hình tạo nhân vật
	if not SaveSystem.has_active_character():
		get_tree().change_scene_to_file.call_deferred("res://src/ui/CharacterCreationUI.tscn")
		return
	if GameState.active_talent.is_empty() or GameState.is_dead:
		GameState.load_from_character()

	tex_wood_icon = load("res://assets/ui_icons/rpg_icons_32x32/wood_01a.png")
	tex_stone_icon = load("res://assets/ui_icons/rpg_icons_32x32/stoneblock_01a.png")
	tex_iron_icon = load("res://assets/ui_icons/rpg_icons_32x32/ingot_01a.png")
	tex_meat_icon = load("res://assets/map/Resources/Meat/Meat Resource/Meat Resource.png")
	tex_bone_icon = load("res://assets/ui_icons/rpg_icons_32x32/bone01a.png")
	tex_pill_icon = load("res://assets/ui_icons/rpg_icons_32x32/potion_01a.png")

	if map_gen:
		map_gen.biome_changed.connect(_on_biome_changed)
		map_gen.resource_dropped.connect(_on_resource_dropped)
		# MapGenerator sinh thế giới trong _ready (trước Main) nên đọc trực tiếp
		_place_base(map_gen.spawn_location)

	if player:
		var stats = player.get_node_or_null("SurvivalStats")
		var inv = player.get_node_or_null("Inventory")
		if stats:
			stats.health_changed.connect(_on_health_changed)
			stats.stamina_changed.connect(_on_stamina_changed)
			stats.temperature_changed.connect(_on_temperature_changed)
			stats.hunger_changed.connect(_on_hunger_changed)
			stats.player_died.connect(_on_player_died)
		if inv and hud:
			inv.resources_updated.connect(func(_w, _s, _i): _push_inventory())
			inv.item_collected.connect(func(_n, _a): _push_inventory())
		GameState.apply_player(player)
		if player.has_signal("tool_changed") and hud and hud.has_method("update_tool"):
			player.tool_changed.connect(hud.update_tool)
			hud.update_tool(player.current_tool)
		if stats:
			_on_health_changed(stats.current_health, stats.max_health)
			_on_stamina_changed(stats.current_stamina, stats.max_stamina)
			_on_temperature_changed(stats.body_temperature)
			_on_hunger_changed(stats.hunger)
		_push_inventory()

	if building_mgr:
		building_mgr.setup(player, hud)
		building_mgr.restore_structures(SaveSystem.character_data.get("structures", []))

	if raid_mgr:
		raid_mgr.setup(player, campfire, day_night, hud)

	if day_night:
		day_night.time_changed.connect(_on_time_changed)
		day_night.phase_changed.connect(_on_phase_changed)

	if campfire:
		campfire.body_entered.connect(_on_campfire_entered)
		campfire.body_exited.connect(_on_campfire_exited)

	# Rương cuối ngày chưa nhận (lần trước tắt game khi popup đang mở)
	var leftover := GameState.take_unclaimed_rewards()
	if not leftover.is_empty() and player:
		var inv_node = player.get_node("Inventory")
		GameState.granting_rewards = true
		for it in leftover:
			inv_node.add_resource(str(it.get("name", "")), int(it.get("amount", 1)))
		GameState.granting_rewards = false
		if hud and hud.has_method("show_toast"):
			hud.show_toast("Đã nhận rương thưởng cuối ngày còn tồn", Color(1, 0.85, 0.3))

	EventBus.day_started.connect(func(_d): _spawn_today_dungeons())
	EventBus.dungeon_entered.connect(func(_n): save_world())
	if hud and hud.has_signal("reroll_requested"):
		hud.reroll_requested.connect(_on_reroll_requested)
	_spawn_today_dungeons()

func _place_base(spawn_pos: Vector2) -> void:
	base_pos = spawn_pos
	if campfire:
		campfire.global_position = spawn_pos + Vector2(60, 0)
	if player:
		var c := SaveSystem.character_data
		if c.has("pos_x"):
			player.global_position = Vector2(float(c.pos_x), float(c.pos_y))
		else:
			player.global_position = spawn_pos
	_spawn_outpost(spawn_pos)

## Cứ điểm Truyền Tống (module của agy). Trạng thái chiếm được lưu trong nhân vật
## để thoát game / vào phó bản không chiếm lại được (tránh cày +25 SP).
func _spawn_outpost(spawn_pos: Vector2) -> void:
	if outpost_node:
		return
	outpost_node = OutpostScene.instantiate()
	outpost_node.name = "Outpost"
	outpost_node.global_position = spawn_pos + Vector2(-340, 220)
	add_child(outpost_node)
	var captured: Array = SaveSystem.character_data.get("captured_outposts", [])
	if outpost_node.outpost_name in captured and outpost_node.has_method("restore_captured"):
		outpost_node.restore_captured()
	outpost_node.outpost_captured.connect(_on_outpost_captured)

func _on_outpost_captured(outpost_name: String, _pos: Vector2) -> void:
	var c := SaveSystem.character_data
	var captured: Array = c.get("captured_outposts", [])
	if not outpost_name in captured:
		captured.append(outpost_name)
	c["captured_outposts"] = captured
	c["outposts"] = captured.size() # BXH Lãnh Thổ
	save_world()


func _process(delta: float) -> void:
	if GameState.is_dead:
		return
	if player and map_gen and map_gen.has_method("update_player_biome"):
		map_gen.update_player_biome(player.global_position)

	autosave_timer += delta
	if autosave_timer >= AUTOSAVE_INTERVAL:
		autosave_timer = 0.0
		save_world()

	if hud and hud.has_method("update_minimap") and player:
		hud.update_minimap(player.global_position, campfire.global_position if campfire else base_pos, _dungeon_markers())

	if player and day_night:
		var stats = player.get_node_or_null("SurvivalStats")
		if stats:
			if stats.is_near_fire:
				stats.target_temperature = 37.2
			else:
				var biome_offset = -6.0 if current_biome_temp < 15.0 else 0.0
				var time_offset = 0.0
				match day_night.current_phase:
					"Night": time_offset = -8.0
					"Dusk": time_offset = -2.0
					"Dawn": time_offset = -3.0
				# Thiên phú kháng lạnh
				if GameState.active_talent.get("id") in ["a_wood_spirit", "s_phoenix_rebirth"]:
					time_offset = 0.0
					biome_offset = 0.0
				stats.target_temperature = clamp(37.0 + biome_offset + time_offset, 28.0, 37.2)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_world()

## Ghi toàn bộ trạng thái nhân vật (vị trí, chỉ số, túi đồ, căn cứ, thời gian).
func save_world() -> void:
	if GameState.is_dead or not SaveSystem.has_active_character():
		return
	var c := SaveSystem.character_data
	if player:
		GameState.capture_player(player)
		c["pos_x"] = player.global_position.x
		c["pos_y"] = player.global_position.y
	if building_mgr:
		c["structures"] = building_mgr.serialize_structures()
	GameState.autosave()

# ==========================================
# PHÓ BẢN NGẪU NHIÊN HÔM NAY
# ==========================================
func _spawn_today_dungeons() -> void:
	for n in dungeon_nodes:
		if is_instance_valid(n):
			n.queue_free()
	dungeon_nodes.clear()
	for d in GameState.get_today_dungeons(base_pos):
		if d.get("cleared", false):
			continue
		var node = DungeonEntranceScene.instantiate()
		node.global_position = Vector2(float(d.x), float(d.y))
		add_child(node)
		node.setup(d)
		dungeon_nodes.append(node)

func _dungeon_markers() -> Array:
	var out: Array = []
	for n in dungeon_nodes:
		if is_instance_valid(n):
			out.append(n.global_position)
	return out

# ==========================================
# ĐAN REROLL (1 lần / nhân vật)
# ==========================================
func _on_reroll_requested() -> void:
	save_world()
	var t := ServerSim.use_reroll_pill()
	if t.is_empty():
		if hud and hud.has_method("show_toast"):
			var why := "Nhân vật đã reroll 1 lần rồi!" if SaveSystem.character_data.get("rerolled", false) else "Không có Đan Reroll Thiên Phú!"
			hud.show_toast(why, Color(1, 0.4, 0.4))
		return
	GameState.active_talent = t
	GameState.apply_player(player)
	EventBus.talent_changed.emit(t)
	if hud and hud.has_method("show_toast"):
		hud.show_toast("Thiên phú mới: [%s] %s" % [t.rank_str, t.name], Color.from_string(t.color_hex, Color.WHITE))

# ==========================================
# PERMADEATH: NHÂN VẬT CHẾT LÀ MẤT VĨNH VIỄN
# ==========================================
func _on_player_died() -> void:
	if GameState.is_dead:
		return
	var result := GameState.handle_player_death()
	if hud and hud.has_method("show_permadeath"):
		hud.show_permadeath(result)

# ==========================================
# TÀI NGUYÊN & HUD
# ==========================================
func _on_resource_dropped(item_name: String, amount: int, pos: Vector2) -> void:
	var item = DroppedItemScene.instantiate()
	item.position = pos
	var tex = tex_wood_icon
	match item_name:
		"Đá": tex = tex_stone_icon
		"Quặng Sắt": tex = tex_iron_icon
		"Thịt Rừng": tex = tex_meat_icon
		"Da Thú", "Xương Thú": tex = tex_bone_icon
		"Đan Reroll Thiên Phú": tex = tex_pill_icon
	# Thiên phú tăng tốc độ thu thập (gỗ/đá/quặng)
	if item_name in ["Gỗ", "Đá", "Quặng Sắt"]:
		amount = maxi(1, int(round(amount * GameState.get_gather_mult())))
	add_child(item)
	item.setup(item_name, amount, tex)

func _push_inventory() -> void:
	var inv = player.get_node_or_null("Inventory") if player else null
	if inv and hud and hud.has_method("update_inventory"):
		hud.update_inventory(inv.to_dict())

func _on_biome_changed(biome_name: String, ambient_temp: float) -> void:
	current_biome_temp = ambient_temp
	if hud: hud.update_biome(biome_name)

func _on_health_changed(hp: float, max_hp: float) -> void:
	if hud: hud.update_health(hp, max_hp)

func _on_stamina_changed(stamina: float, max_stamina: float) -> void:
	if hud: hud.update_stamina(stamina, max_stamina)

func _on_temperature_changed(temp: float) -> void:
	if hud: hud.update_temperature(temp)

func _on_hunger_changed(hunger: float) -> void:
	if hud and hud.has_method("update_hunger"): hud.update_hunger(hunger)

func _on_time_changed(hour: int, minute: int) -> void:
	if hud: hud.update_time(hour, minute)

func _on_phase_changed(phase_name: String) -> void:
	if hud: hud.update_phase(phase_name)

func _on_campfire_entered(body: Node2D) -> void:
	if body == player:
		player.get_node("SurvivalStats").is_near_fire = true

func _on_campfire_exited(body: Node2D) -> void:
	if body == player:
		player.get_node("SurvivalStats").is_near_fire = false
