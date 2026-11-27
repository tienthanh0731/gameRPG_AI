extends Area2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var light: PointLight2D = $PointLight2D

var anim_timer: float = 0.0
var current_frame: int = 0
var base_energy: float = 1.6

func _ready() -> void:
	if sprite:
		sprite.hframes = 3
		sprite.frame = 0

func _process(delta: float) -> void:
	anim_timer += delta
	if anim_timer >= 0.16:
		anim_timer -= 0.16
		current_frame = (current_frame + 1) % 3
		if sprite:
			sprite.frame = current_frame
			
	if light:
		light.energy = base_energy + sin(Time.get_ticks_msec() * 0.008) * 0.18
