extends Node2D

const BoarScene = preload("res://src/entities/BoarEnemy.tscn")
const DroppedItemScene = preload("res://src/world/DroppedItem.tscn")
const PlayerScene = preload("res://src/core/Player.tscn")

@onready var player: CharacterBody2D = $Player
@onready var exit_portal: Area2D = $ExitPortal
@onready var exit_label: Label = $ExitPortal/ExitLabel
@onready var boss_hud: PanelContainer = $CanvasLayer/BossHUD
@onready var boss_hp_bar: ProgressBar = $CanvasLayer/BossHUD/VBox/ProgressBar
@onready var boss_name_label: Label = $CanvasLayer/BossHUD/VBox/LabelBossName
@onready var victory_banner: PanelContainer = $CanvasLayer/VictoryBanner

var boss_instance: CharacterBody2D = null
var is_dungeon_cleared: bool = false
var can_exit: bool = false

func _ready() -> void:
	exit_label.visible = false
	victory_banner.visible = false
	boss_hud.visible = true
	
	exit_portal.body_entered.connect(_on_exit_portal_entered)
	exit_portal.body_exited.connect(_on_exit_portal_exited)
	
	# Setup Player in Dungeon
	if player:
		var stats = player.get_node_or_null("SurvivalStats")
		if stats:
			stats.player_died.connect(_on_player_died)
			# Apply active talent buffs if any
			if not GameState.active_talent.is_empty():
				stats.max_health *= GameState.active_talent.get("hp_mult", 1.0)
				stats.current_health = stats.max_health
				
		var inv = player.get_node_or_null("Inventory")
		if inv and SaveSystem.character_data.has("inventory"):
			var saved_inv = SaveSystem.character_data["inventory"]
			inv.wood = saved_inv.get("wood", 0)
			inv.stone = saved_inv.get("stone", 0)
			inv.iron = saved_inv.get("iron", 0)
			inv.meat = saved_inv.get("meat", 0)
			inv.bone = saved_inv.get("bone", 0)

	_spawn_dungeon_enemies()

func _spawn_dungeon_enemies() -> void:
	# 1. Spawn Alpha Elite Boar (Boss)
	boss_instance = BoarScene.instantiate()
	boss_instance.is_elite = true
	boss_instance.position = Vector2(0, -180)
	add_child(boss_instance)
	
	boss_hp_bar.max_value = boss_instance.max_health
	boss_hp_bar.value = boss_instance.current_health
	boss_name_label.text = "✦ [QUÁI TINH ANH] CỔ THÚ THỐNG LĨNH (MÁU: %d) ✦" % boss_instance.max_health
	
	# Connect death
	boss_instance.tree_exited.connect(_on_boss_killed)
	
	# 2. Spawn 3 Minion Boars
	var offsets = [Vector2(-120, -100), Vector2(120, -100), Vector2(0, -280)]
	for off in offsets:
		var minion = BoarScene.instantiate()
		minion.position = off
		add_child(minion)

func _process(_delta: float) -> void:
	if is_instance_valid(boss_instance):
		boss_hp_bar.value = boss_instance.current_health
		boss_name_label.text = "✦ [QUÁI TINH ANH] CỔ THÚ THỐNG LĨNH (MÁU: %d / %d) ✦" % [
			boss_instance.current_health, boss_instance.max_health
		]
	elif not is_dungeon_cleared and boss_instance != null:
		_on_boss_killed()

func _on_boss_killed() -> void:
	if is_dungeon_cleared: return
	is_dungeon_cleared = true
	boss_hud.visible = false
	victory_banner.visible = true
	
	# Drop rare dungeon loot at center
	_spawn_loot(Vector2(-30, -50), "Đan Reroll Thiên Phú", 1)
	_spawn_loot(Vector2(0, -50), "Quặng Sắt", 15)
	_spawn_loot(Vector2(30, -50), "Thịt Rừng", 10)
	
	# Award SP & Trigger Event
	GameState.add_sp(30, "Chinh phục Tàn Tích Cổ Sơn Động")
	EventBus.dungeon_cleared.emit("Tàn Tích Cổ Sơn Động", {
		"sp": 30,
		"reroll_pill": 1,
		"iron": 15
	})
	
	# Activate Exit Portal
	exit_portal.modulate = Color(0.4, 1.2, 0.5)

func _spawn_loot(pos: Vector2, item_name: String, amount: int) -> void:
	var item = DroppedItemScene.instantiate()
	item.position = pos
	var tex = load("res://assets/ui_icons/rpg_icons_32x32/ingot_01a.png")
	if item_name.begins_with("Đan"):
		tex = load("res://assets/ui_icons/rpg_icons_32x32/potion_01a.png")
	elif item_name == "Thịt Rừng":
		tex = load("res://assets/map/Resources/Meat/Meat Resource/Meat Resource.png")
	item.setup(item_name, amount, tex)
	add_child(item)

func _on_exit_portal_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		can_exit = true
		exit_label.visible = true
		if is_dungeon_cleared:
			exit_label.text = "[E] BƯỚC QUA TRUYỀN TỐNG VỀ LẠI CĂN CỨ"
		else:
			exit_label.text = "[E] RÚT LUI KHỎI PHÓ BẢN"

func _on_exit_portal_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		can_exit = false
		exit_label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if can_exit and event is InputEventKey and event.pressed and event.keycode == KEY_E:
		_return_to_surface()

func _return_to_surface() -> void:
	# Save updated player stats & inventory before exiting dungeon
	if player:
		var inv = player.get_node_or_null("Inventory")
		var stats = player.get_node_or_null("SurvivalStats")
		if inv and stats and SaveSystem.character_data:
			SaveSystem.character_data["health"] = stats.current_health
			SaveSystem.character_data["stamina"] = stats.current_stamina
			SaveSystem.character_data["inventory"] = {
				"wood": inv.wood,
				"stone": inv.stone,
				"iron": inv.iron,
				"meat": inv.meat,
				"bone": inv.bone
			}
			SaveSystem.save_character(SaveSystem.character_data)
			
	GameState.is_in_dungeon = false
	EventBus.dungeon_exited.emit()
	get_tree().change_scene_to_file("res://src/world/Main.tscn")

func _on_player_died() -> void:
	# Trigger Permadeath
	var talent = GameState.active_talent
	var day = GameState.current_day
	var sp = GameState.total_season_sp
	var result = SaveSystem.kill_character_atomic(day, sp, talent)
	EventBus.player_died.emit(day, sp, result.get("record_broken", false))
	get_tree().change_scene_to_file("res://src/ui/CharacterCreationUI.tscn")
