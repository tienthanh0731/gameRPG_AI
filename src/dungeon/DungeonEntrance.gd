extends Area2D

@onready var prompt_label: Label = $PromptLabel
@onready var portal_sprite: Sprite2D = $PortalSprite

var is_player_nearby: bool = false
var player_ref: CharacterBody2D = null
var dungeon_data: Dictionary = {}

## Gán dữ liệu phó bản (id, seed, stars) do GameState sinh cho hôm nay.
func setup(data: Dictionary) -> void:
	dungeon_data = data

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
	if body.is_in_group("player"):
		is_player_nearby = true
		player_ref = body as CharacterBody2D
		prompt_label.visible = true
		var stars := int(dungeon_data.get("stars", 1))
		prompt_label.text = "[E] TÀN TÍCH CỔ SƠN ĐỘNG  %s\n(Phó bản hôm nay • +30 SP • cơ hội rơi Đan Reroll)" % "★".repeat(stars)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_nearby = false
		prompt_label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if is_player_nearby and event is InputEventKey and event.pressed and event.keycode == KEY_E:
		_enter_dungeon()

func _enter_dungeon() -> void:
	if not player_ref or GameState.is_dead:
		return
	GameState.active_dungeon = dungeon_data
	GameState.is_in_dungeon = true
	# Main nghe dungeon_entered để lưu toàn bộ thế giới trước khi đổi scene
	EventBus.dungeon_entered.emit("Tàn Tích Cổ Sơn Động")
	get_tree().change_scene_to_file.call_deferred("res://src/dungeon/DungeonScene.tscn")
