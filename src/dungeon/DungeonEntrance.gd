extends Area2D

@onready var prompt_label: Label = $PromptLabel
@onready var portal_sprite: Sprite2D = $PortalSprite

var is_player_nearby: bool = false
var player_ref: CharacterBody2D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	prompt_label.visible = false
	
	# Load portal / cave icon
	var tex = load("res://assets/buildings/structures/door_wood_closed.png")
	if tex and portal_sprite:
		portal_sprite.texture = tex
		portal_sprite.modulate = Color(0.4, 0.7, 1.2, 0.9) # Mysterious blue glow

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player" or (body is CharacterBody2D and body.get_node_or_null("Inventory") != null):
		is_player_nearby = true
		player_ref = body as CharacterBody2D
		prompt_label.visible = true
		prompt_label.text = "[E] BƯỚC VÀO TÀN TÍCH CỔ SƠN ĐỘNG\n(Phó bản ngẫu nhiên • Thưởng: Đan Reroll & +30 SP)"

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player" or body == player_ref:
		is_player_nearby = false
		prompt_label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if is_player_nearby and event is InputEventKey and event.pressed and event.keycode == KEY_E:
		_enter_dungeon()

func _enter_dungeon() -> void:
	if not player_ref: return
	
	# Save current player stats & inventory before entering dungeon
	var inv = player_ref.get_node_or_null("Inventory")
	var stats = player_ref.get_node_or_null("SurvivalStats")
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
		
	GameState.is_in_dungeon = true
	EventBus.dungeon_entered.emit("Tàn Tích Cổ Sơn Động")
	get_tree().change_scene_to_file("res://src/dungeon/DungeonScene.tscn")
