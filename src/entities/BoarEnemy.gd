extends CharacterBody2D

signal boar_died(pos: Vector2)

enum BoarState {
	IDLE,
	CHASE,
	ATTACK,
	HURT,
	DEATH
}

@export var max_health: int = 35
var current_health: int = 35
@export var move_speed: float = 110.0
@export var attack_damage: int = 12

var state: BoarState = BoarState.IDLE
var target_entity: Node2D = null

var tex_idle: Texture2D
var tex_walk: Texture2D
var tex_attack: Texture2D
var tex_hurt: Texture2D
var tex_death: Texture2D

@onready var sprite: Sprite2D = $Sprite2D

var anim_timer: float = 0.0
var current_frame: int = 0
var anim_fps: float = 8.0
var state_timer: float = 0.0

func _ready() -> void:
	current_health = max_health
	_ensure_textures()
	if not sprite:
		sprite = get_node_or_null("Sprite2D")
	_set_anim(tex_idle, 3, 5.0)

func _ensure_textures() -> void:
	if not tex_idle:
		tex_idle = load("res://assets/enemies/boar/BoarIdle-Sheet.png")
		tex_walk = load("res://assets/enemies/boar/BoarWalk-Sheet.png")
		tex_attack = load("res://assets/enemies/boar/BoarAttack-Sheet.png")
		tex_hurt = load("res://assets/enemies/boar/BoarHurt-Sheet.png")
		tex_death = load("res://assets/enemies/boar/BoarDeath-Sheet.png")

func _physics_process(delta: float) -> void:
	if state == BoarState.DEATH:
		_update_animation(delta)
		return
		
	state_timer -= delta
	match state:
		BoarState.IDLE:
			velocity = Vector2.ZERO
			_find_target()
			if target_entity:
				state = BoarState.CHASE
				_set_anim(tex_walk, 4, 8.0)
		BoarState.CHASE:
			_chase_target(delta)
		BoarState.ATTACK:
			velocity = Vector2.ZERO
			if state_timer <= 0.0:
				state = BoarState.CHASE
				_set_anim(tex_walk, 4, 8.0)
		BoarState.HURT:
			velocity = Vector2.ZERO
			if state_timer <= 0.0:
				state = BoarState.CHASE
				_set_anim(tex_walk, 4, 8.0)

	move_and_slide()
	_update_animation(delta)

func _find_target() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target_entity = players[0]

func _chase_target(_delta: float) -> void:
	if not target_entity:
		_find_target()
		return
		
	var dist = global_position.distance_to(target_entity.global_position)
	if dist <= 38.0:
		_start_attack()
		return
		
	var dir = (target_entity.global_position - global_position).normalized()
	velocity = dir * move_speed
	sprite.flip_h = dir.x < 0

func _start_attack() -> void:
	state = BoarState.ATTACK
	state_timer = 0.5
	_set_anim(tex_attack, 7, 14.0)
	
	get_tree().create_timer(0.2).timeout.connect(func():
		if state == BoarState.ATTACK and target_entity:
			var d = global_position.distance_to(target_entity.global_position)
			if d <= 48.0:
				var stats = target_entity.get_node_or_null("SurvivalStats")
				if stats and stats.has_method("take_damage"):
					stats.take_damage(attack_damage)
	)

func take_hit(tool_id: int = 2) -> void:
	if state == BoarState.DEATH:
		return
		
	_ensure_textures()
	var dmg = 15 if tool_id == 2 else 5
	current_health -= dmg
	_play_flash()
	
	if current_health <= 0:
		_die()
	else:
		state = BoarState.HURT
		state_timer = 0.25
		_set_anim(tex_hurt, 3, 10.0)

func _die() -> void:
	state = BoarState.DEATH
	velocity = Vector2.ZERO
	_ensure_textures()
	_set_anim(tex_death, 9, 14.0)
	var col = get_node_or_null("CollisionShape2D")
	if col:
		col.set_deferred("disabled", true)
		
	boar_died.emit(global_position)
	if is_inside_tree():
		get_tree().create_timer(1.0).timeout.connect(queue_free)
	else:
		queue_free()

func _play_flash() -> void:
	if not sprite:
		sprite = get_node_or_null("Sprite2D")
	if not sprite or not is_inside_tree():
		return
	var tween = create_tween()
	if tween:
		tween.tween_property(sprite, "modulate", Color(2.0, 0.4, 0.4), 0.05)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.08)

func _set_anim(tex: Texture2D, h_frames: int, fps: float) -> void:
	if not sprite:
		sprite = get_node_or_null("Sprite2D")
	if not sprite or not tex:
		return
	if sprite.texture != tex:
		sprite.texture = tex
		sprite.hframes = h_frames
	anim_fps = fps
	current_frame = 0
	sprite.frame = 0
	anim_timer = 0.0

func _update_animation(delta: float) -> void:
	if sprite.hframes <= 1:
		return
	anim_timer += delta
	var frame_dur = 1.0 / anim_fps
	if anim_timer >= frame_dur:
		anim_timer -= frame_dur
		if state == BoarState.DEATH:
			current_frame = min(sprite.hframes - 1, current_frame + 1)
		else:
			current_frame = (current_frame + 1) % sprite.hframes
		sprite.frame = current_frame
