extends Node2D
## DungeonScene — phó bản "Tàn Tích Cổ Sơn Động".
## Layout (số quái, vị trí, chướng ngại) sinh từ seed của phó bản hôm nay,
## nên mỗi cửa/mỗi ngày khác nhau nhưng vào lại thì giữ nguyên.

const BoarScene = preload("res://src/entities/BoarEnemy.tscn")
const DroppedItemScene = preload("res://src/world/DroppedItem.tscn")
const PermadeathScene = preload("res://src/ui/PermadeathUI.tscn")

const ARENA_HALF := Vector2(480, 380)

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
var rng := RandomNumberGenerator.new()
var dungeon: Dictionary = {}

func _ready() -> void:
	if not SaveSystem.has_active_character():
		get_tree().change_scene_to_file.call_deferred("res://src/ui/CharacterCreationUI.tscn")
		return
	dungeon = GameState.active_dungeon
	rng.seed = int(dungeon.get("seed", 12345))

	exit_label.visible = false
	victory_banner.visible = false
	boss_hud.visible = true
	exit_portal.body_entered.connect(_on_exit_portal_entered)
	exit_portal.body_exited.connect(_on_exit_portal_exited)

	if player:
		GameState.apply_player(player)
		var stats = player.get_node_or_null("SurvivalStats")
		if stats:
			stats.player_died.connect(_on_player_died)

	_build_layout()
	_spawn_dungeon_enemies()

func _stars() -> int:
	return int(dungeon.get("stars", 1))

## Chướng ngại đá ngẫu nhiên theo seed.
func _build_layout() -> void:
	var rock_tex: Texture2D = load("res://assets/ui_icons/rpg_icons_32x32/stoneblock_01a.png")
	var count := rng.randi_range(4, 9)
	for i in count:
		var pos := Vector2(rng.randf_range(-ARENA_HALF.x + 60, ARENA_HALF.x - 60), rng.randf_range(-ARENA_HALF.y + 60, 40))
		if pos.distance_to(Vector2(0, 120)) < 120.0 or pos.distance_to(Vector2(0, -180)) < 90.0:
			continue
		var body := StaticBody2D.new()
		body.position = pos
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(44, 44)
		shape.shape = rect
		body.add_child(shape)
		var spr := Sprite2D.new()
		spr.texture = rock_tex
		spr.scale = Vector2(1.5, 1.5)
		spr.modulate = Color(0.6, 0.55, 0.5)
		body.add_child(spr)
		add_child(body)

func _spawn_dungeon_enemies() -> void:
	# Boss: Cổ Thú Thống Lĩnh (quái tinh anh), mạnh hơn theo số sao
	boss_instance = BoarScene.instantiate()
	boss_instance.is_elite = true
	boss_instance.position = Vector2(rng.randf_range(-200, 200), -200)
	boss_instance.max_health = int(boss_instance.max_health * (1.0 + 0.25 * (_stars() - 1)))
	add_child(boss_instance)
	boss_hp_bar.max_value = boss_instance.max_health
	boss_hp_bar.value = boss_instance.current_health
	boss_instance.boar_died.connect(func(_p): _on_boss_killed())

	var minions := 2 + _stars() + rng.randi_range(0, 2)
	for i in minions:
		var m = BoarScene.instantiate()
		m.position = Vector2(rng.randf_range(-ARENA_HALF.x + 80, ARENA_HALF.x - 80), rng.randf_range(-ARENA_HALF.y + 60, -40))
		add_child(m)

func _process(_delta: float) -> void:
	if is_instance_valid(boss_instance) and not is_dungeon_cleared:
		boss_hp_bar.value = boss_instance.current_health
		boss_name_label.text = "✦ [TINH ANH] CỔ THÚ THỐNG LĨNH %s (MÁU: %d / %d) ✦" % [
			"★".repeat(_stars()), maxi(0, boss_instance.current_health), boss_instance.max_health]

func _on_boss_killed() -> void:
	if is_dungeon_cleared:
		return
	is_dungeon_cleared = true
	boss_hud.visible = false
	victory_banner.visible = true

	# Loot: đan reroll hiếm (10% + 5%/sao)
	_spawn_loot(Vector2(0, -50), "Quặng Sắt", 4 + 3 * _stars())
	_spawn_loot(Vector2(30, -50), "Thịt Rừng", 2 + _stars())
	if rng.randf() < 0.10 + 0.05 * _stars():
		_spawn_loot(Vector2(-30, -50), "Đan Reroll Thiên Phú", 1)

	# SP chỉ được cộng trong GameState (1 lần/phó bản)
	GameState.mark_dungeon_cleared(str(dungeon.get("id", "")))
	EventBus.dungeon_cleared.emit("Tàn Tích Cổ Sơn Động", { "sp": 30, "stars": _stars() })
	exit_portal.modulate = Color(0.4, 1.2, 0.5)

func _spawn_loot(pos: Vector2, item_name: String, amount: int) -> void:
	var item = DroppedItemScene.instantiate()
	item.position = pos
	var tex = load("res://assets/ui_icons/rpg_icons_32x32/ingot_01a.png")
	if item_name.begins_with("Đan"):
		tex = load("res://assets/ui_icons/rpg_icons_32x32/potion_01a.png")
	elif item_name == "Thịt Rừng":
		tex = load("res://assets/map/Resources/Meat/Meat Resource/Meat Resource.png")
	add_child(item)
	item.setup(item_name, amount, tex)

func _on_exit_portal_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player" or (body is CharacterBody2D and body.get_node_or_null("Inventory") != null):
		can_exit = true
		exit_label.visible = true
		exit_label.text = "[E] TRUYỀN TỐNG VỀ CĂN CỨ" if is_dungeon_cleared else "[E] RÚT LUI KHỎI PHÓ BẢN"

func _on_exit_portal_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		can_exit = false
		exit_label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if can_exit and not GameState.is_dead and event is InputEventKey and event.pressed and event.keycode == KEY_E:
		_return_to_surface()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and player:
		GameState.capture_player(player)
		GameState.autosave()

func _return_to_surface() -> void:
	if player:
		GameState.capture_player(player)
	GameState.autosave()
	GameState.is_in_dungeon = false
	GameState.active_dungeon = {}
	EventBus.dungeon_exited.emit()
	get_tree().change_scene_to_file.call_deferred("res://src/world/Main.tscn")

func _on_player_died() -> void:
	if GameState.is_dead:
		return
	var result := GameState.handle_player_death()
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var ui = PermadeathScene.instantiate()
	layer.add_child(ui)
	ui.setup(result)
	ui.visible = true
	get_tree().paused = true
