class_name TreeProp
extends StaticBody2D

signal tree_chopped(wood_amount: int, drop_pos: Vector2)

@export var max_health: int = 3
var current_health: int = 3

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

var is_stump: bool = false
var stump_texture: Texture2D

func _ready() -> void:
	current_health = max_health
	var stump_path = "res://assets/raw_packs/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Resources/Wood/Trees/Stump 1.png"
	if ResourceLoader.exists(stump_path):
		stump_texture = load(stump_path)

func take_hit() -> void:
	if is_stump:
		return
		
	current_health -= 1
	_play_shake_effect()
	
	if current_health <= 0:
		_fall_down()

func _play_shake_effect() -> void:
	var tween = create_tween()
	tween.tween_property(sprite, "rotation_degrees", 6.0, 0.05)
	tween.tween_property(sprite, "rotation_degrees", -6.0, 0.05)
	tween.tween_property(sprite, "rotation_degrees", 0.0, 0.05)

func _fall_down() -> void:
	is_stump = true
	if stump_texture:
		sprite.hframes = 1
		sprite.frame = 0
		sprite.texture = stump_texture
		sprite.offset = Vector2(0, -10)
		sprite.scale = Vector2(0.8, 0.8)
		
	var wood_amount = randi_range(3, 5)
	tree_chopped.emit(wood_amount, global_position)
