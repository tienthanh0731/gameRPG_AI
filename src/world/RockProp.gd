class_name RockProp
extends StaticBody2D

signal rock_mined(stone_amount: int, iron_amount: int, drop_pos: Vector2)

@export var max_health: int = 3
var current_health: int = 3

@onready var sprite: Sprite2D = $Sprite2D

var is_destroyed: bool = false

func _ready() -> void:
	current_health = max_health

func take_hit() -> void:
	if is_destroyed:
		return
		
	current_health -= 1
	_play_shake_effect()
	
	if current_health <= 0:
		_break_apart()

func _play_shake_effect() -> void:
	var tween = create_tween()
	tween.tween_property(sprite, "scale", sprite.scale * 1.15, 0.05)
	tween.tween_property(sprite, "scale", sprite.scale, 0.05)

func _break_apart() -> void:
	is_destroyed = true
	var stone_amount = randi_range(2, 4)
	var iron_amount = 1 if randf() < 0.35 else 0
	rock_mined.emit(stone_amount, iron_amount, global_position)
	queue_free()
