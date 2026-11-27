extends Node2D

const DroppedItemScene = preload("res://src/world/DroppedItem.tscn")
const DungeonEntranceScene = preload("res://src/dungeon/DungeonEntrance.tscn")
const TalentData = preload("res://src/data/TalentData.gd")

var OutpostScene = load("res://src/world/outpost/Outpost.tscn")

@onready var map_gen: Node2D = $MapGenerator
@onready var player: CharacterBody2D = $Player
@onready var day_night: CanvasModulate = $DayNightCycle
@onready var hud: CanvasLayer = $HUD
@onready var campfire: Area2D = $Campfire
@onready var building_mgr: Node2D = $BuildingManager
@onready var raid_mgr: Node2D = $RaidManager

var current_biome_temp: float = 28.0
var dungeon_entrance_node: Node2D = null
var outpost_node: Node2D = null

var tex_wood_icon: Texture2D
var tex_stone_icon: Texture2D
var tex_iron_icon: Texture2D
var tex_meat_icon: Texture2D
var tex_bone_icon: Texture2D

func _ready() -> void:
	tex_wood_icon = load("res://assets/ui_icons/rpg_icons_32x32/wood_01a.png")
	tex_stone_icon = load("res://assets/ui_icons/rpg_icons_32x32/stoneblock_01a.png")
	tex_iron_icon = load("res://assets/ui_icons/rpg_icons_32x32/ingot_01a.png")
	tex_meat_icon = load("res://assets/map/Resources/Meat/Meat Resource/Meat Resource.png")
	tex_bone_icon = load("res://assets/ui_icons/rpg_icons_32x32/bone01a.png")

	# Ensure GameState has talent & character data loaded
	if GameState.active_talent.is_empty():
		if SaveSystem.has_active_character():
			GameState.init_new_game(SaveSystem.character_data.get("talent", {}), SaveSystem.character_data.get("day", 1))
		else:
			var default_talent = TalentData.roll_talent()
			GameState.init_new_game(default_talent, 1)

	if map_gen:
		map_gen.player_spawn_found.connect(_on_player_spawn_found)
		map_gen.biome_changed.connect(_on_biome_changed)
		map_gen.resource_dropped.connect(_on_resource_dropped)
		if map_gen.get("spawn_location") != null:
			_on_player_spawn_found(map_gen.spawn_location)
		
	if player:
		if player.has_signal("tool_changed") and hud and hud.has_method("update_tool"):
			player.tool_changed.connect(hud.update_tool)
			hud.update_tool(player.current_tool)
			
		var stats = player.get_node_or_null("SurvivalStats")
		if stats:
			# Apply Talent Multipliers
			if not GameState.active_talent.is_empty():
				stats.max_health *= GameState.active_talent.get("hp_mult", 1.0)
				stats.current_health = stats.max_health
				if player.get("speed"):
					player.speed *= GameState.active_talent.get("speed_mult", 1.0)
			
			stats.health_changed.connect(_on_health_changed)
			stats.stamina_changed.connect(_on_stamina_changed)
			stats.temperature_changed.connect(_on_temperature_changed)
			if stats.has_signal("player_died"):
				stats.player_died.connect(_on_player_died)
				
			# Immediately push initial values to HUD
			_on_health_changed(stats.current_health, stats.max_health)
			_on_stamina_changed(stats.current_stamina, stats.max_stamina)
			_on_temperature_changed(stats.body_temperature)

		var inv = player.get_node_or_null("Inventory")
		if inv:
			if SaveSystem.has_active_character() and SaveSystem.character_data.has("inventory"):
				inv.load_inventory_dict(SaveSystem.character_data["inventory"])
				
			if hud and hud.has_method("update_inventory"):
				inv.inventory_updated.connect(hud.update_inventory)
				hud.update_inventory(inv.get_inventory_dict())
			elif hud and hud.has_method("update_resources"):
				inv.resources_updated.connect(hud.update_resources)
				hud.update_resources(inv.wood, inv.stone, inv.iron)
			
	if building_mgr and building_mgr.has_method("setup"):
		building_mgr.setup(player, hud)
		
	if raid_mgr and raid_mgr.has_method("setup"):
		raid_mgr.setup(player, campfire, day_night, hud)
		
	if day_night:
		day_night.time_changed.connect(_on_time_changed)
		day_night.phase_changed.connect(_on_phase_changed)
		
	if campfire:
		campfire.body_entered.connect(_on_campfire_entered)
		campfire.body_exited.connect(_on_campfire_exited)

func _process(_delta: float) -> void:
	if player and map_gen and map_gen.has_method("update_player_biome"):
		map_gen.update_player_biome(player.global_position)

	if player and day_night:
		var stats = player.get_node_or_null("SurvivalStats")
		if stats:
			if stats.is_near_fire:
				stats.target_temperature = 37.2
			else:
				var base_body = 37.0
				var biome_offset = 0.0
				if current_biome_temp < 15.0:
					biome_offset = -6.0
				
				var time_offset = 0.0
				match day_night.current_phase:
					"Night": time_offset = -8.0
					"Dusk": time_offset = -2.0
					"Dawn": time_offset = -3.0
					"Day": time_offset = 0.0
					
				# Talent protection against cold (e.g. Linh Mộc Dục Hỏa / Niết Bàn)
				if not GameState.active_talent.is_empty():
					if GameState.active_talent.get("id") in ["a_wood_spirit", "s_phoenix_rebirth"]:
						time_offset = 0.0
						biome_offset = 0.0
						
				stats.target_temperature = clamp(base_body + biome_offset + time_offset, 28.0, 37.2)

# ==========================================
# PERMADEATH: NHÂN VẬT CHẾT LÀ MẤT VĨNH VIỄN
# ==========================================
func _on_player_died() -> void:
	var talent = GameState.active_talent
	var day = GameState.current_day
	var sp = GameState.total_season_sp
	
	# 1. Atomic wipe of character & update account
	var result = SaveSystem.kill_character_atomic(day, sp, talent)
	EventBus.player_died.emit(day, sp, result.get("record_broken", false))
	
	# 2. Show dedicated Permadeath modal
	if hud and hud.has_method("show_permadeath"):
		hud.show_permadeath(result)

func _on_player_spawn_found(spawn_pos: Vector2) -> void:
	if player:
		player.global_position = spawn_pos
	if campfire:
		campfire.global_position = spawn_pos + Vector2(60, 0)
		
	# Spawn Dungeon Entrance Portal nearby
	if not dungeon_entrance_node:
		dungeon_entrance_node = DungeonEntranceScene.instantiate()
		dungeon_entrance_node.global_position = spawn_pos + Vector2(240, -140)
		add_child(dungeon_entrance_node)

	# Spawn Ancient Abandoned Outpost nearby (to the south-west)
	if not outpost_node:
		outpost_node = OutpostScene.instantiate()
		outpost_node.name = "Outpost"
		outpost_node.global_position = spawn_pos + Vector2(-340, 220)
		add_child(outpost_node)

func _on_resource_dropped(item_name: String, amount: int, pos: Vector2) -> void:
	var item = DroppedItemScene.instantiate()
	item.position = pos
	var tex = tex_wood_icon
	if item_name == "Đá":
		tex = tex_stone_icon
	elif item_name == "Quặng Sắt":
		tex = tex_iron_icon
	elif item_name == "Thịt Rừng":
		tex = tex_meat_icon
	elif item_name == "Da Thú" or item_name == "Xương Thú":
		tex = tex_bone_icon
		
	add_child(item)
	item.setup(item_name, amount, tex)

func _on_biome_changed(biome_name: String, ambient_temp: float) -> void:
	current_biome_temp = ambient_temp
	if hud and hud.has_method("update_biome"):
		hud.update_biome(biome_name)

func _on_health_changed(hp: float, max_hp: float) -> void:
	if hud and hud.has_method("update_health"):
		hud.update_health(hp, max_hp)

func _on_stamina_changed(stamina: float, max_stamina: float) -> void:
	if hud and hud.has_method("update_stamina"):
		hud.update_stamina(stamina, max_stamina)

func _on_temperature_changed(temp: float) -> void:
	if hud and hud.has_method("update_temperature"):
		hud.update_temperature(temp)

func _on_time_changed(hour: int, minute: int) -> void:
	if hud and hud.has_method("update_time"):
		hud.update_time(hour, minute)

func _on_phase_changed(phase_name: String) -> void:
	if hud and hud.has_method("update_phase"):
		hud.update_phase(phase_name)

func _on_campfire_entered(body: Node2D) -> void:
	if body == player:
		var stats = player.get_node_or_null("SurvivalStats")
		if stats:
			stats.is_near_fire = true

func _on_campfire_exited(body: Node2D) -> void:
	if body == player:
		var stats = player.get_node_or_null("SurvivalStats")
		if stats:
			stats.is_near_fire = false
