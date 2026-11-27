class_name Player
extends CharacterBody2D

@export var move_speed: float = 140.0
@export var sprint_speed: float = 210.0
@export var dodge_speed: float = 350.0

@onready var survival_stats: SurvivalStats = $SurvivalStats
@onready var sprite: Sprite2D = $Sprite2D

var is_dodging: bool = false
var dodge_timer: float = 0.0
var dodge_duration: float = 0.25
var dodge_direction: Vector2 = Vector2.DOWN

var is_attacking: bool = false
var attack_timer: float = 0.0

func _physics_process(delta: float) -> void:
	if is_dodging:
		_process_dodge(delta)
	elif is_attacking:
		_process_attack(delta)
	else:
		_process_movement(delta)

func _process_movement(delta: float) -> void:
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_vector.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	input_vector = input_vector.normalized()
	
	if Input.is_action_just_pressed("dodge") and input_vector != Vector2.ZERO:
		if survival_stats.use_stamina(20.0):
			_start_dodge(input_vector)
			return
			
	if Input.is_action_just_pressed("attack"):
		if survival_stats.use_stamina(10.0):
			_start_attack()
			return

	var is_sprinting = Input.is_key_pressed(KEY_SHIFT) and input_vector != Vector2.ZERO
	var current_speed = move_speed
	
	if is_sprinting and survival_stats.use_stamina(12.0 * delta):
		current_speed = sprint_speed

	velocity = input_vector * current_speed
	move_and_slide()
	
	if velocity.x != 0:
		sprite.flip_h = velocity.x < 0

func _start_dodge(direction: Vector2) -> void:
	is_dodging = true
	dodge_direction = direction
	dodge_timer = dodge_duration

func _process_dodge(delta: float) -> void:
	dodge_timer -= delta
	velocity = dodge_direction * dodge_speed
	move_and_slide()
	if dodge_timer <= 0.0:
		is_dodging = false

func _start_attack() -> void:
	is_attacking = true
	attack_timer = 0.3
	velocity = Vector2.ZERO

func _process_attack(delta: float) -> void:
	attack_timer -= delta
	if attack_timer <= 0.0:
		is_attacking = false
