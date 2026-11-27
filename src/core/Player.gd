class_name Player
extends CharacterBody2D

enum ToolMode {
	AXE,       # Phím 1: Đốn Củi
	PICKAXE,   # Phím 2: Đào Khoáng / Đập Đá
	SWORD      # Phím 3: Kiếm Chiến Đấu
}

enum PlayerState {
	IDLE,
	WALK,
	DODGE,
	ACTION_AXE,
	ACTION_MINE,
	ACTION_ATTACK
}

@export var move_speed: float = 150.0
@export var sprint_speed: float = 220.0
@export var dodge_speed: float = 360.0

@onready var survival_stats: SurvivalStats = $SurvivalStats
@onready var sprite: Sprite2D = $Sprite2D
@onready var interaction_area: Area2D = $InteractionArea

# Textures
var tex_idle: Texture2D
var tex_walk: Texture2D
var tex_axe: Texture2D
var tex_mining: Texture2D
var tex_attack: Texture2D

var current_tool: ToolMode = ToolMode.AXE
var state: PlayerState = PlayerState.IDLE

var anim_timer: float = 0.0
var current_frame: int = 0
var anim_fps: float = 8.0

var dodge_timer: float = 0.0
var dodge_duration: float = 0.22
var dodge_dir: Vector2 = Vector2.DOWN

var action_timer: float = 0.0
var facing_dir: Vector2 = Vector2.RIGHT

func _ready() -> void:
	tex_idle = load("res://assets/characters/survivor_male/PlayerIdle-Sheet.png")
	tex_walk = load("res://assets/characters/survivor_male/PlayerWalk-Sheet.png")
	tex_axe = load("res://assets/characters/survivor_male/PlayerAxe-Sheet.png")
	tex_mining = load("res://assets/characters/survivor_male/PlayerMining-Sheet.png")
	tex_attack = load("res://assets/characters/survivor_male/PlayerAttack_1-Sheet.png")
	_set_anim(tex_idle, 3, 6.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			current_tool = ToolMode.AXE
		elif event.keycode == KEY_2:
			current_tool = ToolMode.PICKAXE
		elif event.keycode == KEY_3:
			current_tool = ToolMode.SWORD

func _physics_process(delta: float) -> void:
	match state:
		PlayerState.IDLE, PlayerState.WALK:
			_handle_movement(delta)
			_handle_action_input()
		PlayerState.DODGE:
			_process_dodge(delta)
		PlayerState.ACTION_AXE, PlayerState.ACTION_MINE, PlayerState.ACTION_ATTACK:
			_process_action(delta)

	_update_animation(delta)

func _handle_movement(delta: float) -> void:
	var input_vec = Vector2.ZERO
	input_vec.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_vec.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	input_vec = input_vec.normalized()

	if Input.is_action_just_pressed("dodge") and input_vec != Vector2.ZERO:
		if survival_stats.use_stamina(18.0):
			_start_dodge(input_vec)
			return

	var is_sprinting = Input.is_key_pressed(KEY_SHIFT) and input_vec != Vector2.ZERO
	var speed = move_speed
	if is_sprinting and survival_stats.use_stamina(10.0 * delta):
		speed = sprint_speed

	velocity = input_vec * speed
	move_and_slide()

	if input_vec != Vector2.ZERO:
		facing_dir = input_vec
		if input_vec.x != 0:
			sprite.flip_h = input_vec.x < 0
		if state != PlayerState.WALK:
			state = PlayerState.WALK
			_set_anim(tex_walk, 4, 8.0 if not is_sprinting else 12.0)
	else:
		if state != PlayerState.IDLE:
			state = PlayerState.IDLE
			_set_anim(tex_idle, 3, 5.0)

func _handle_action_input() -> void:
	if Input.is_action_just_pressed("attack"):
		match current_tool:
			ToolMode.AXE:
				if survival_stats.use_stamina(8.0):
					_start_tool_action(PlayerState.ACTION_AXE, tex_axe, 5, 10.0, 0.4)
					_try_hit_tree()
			ToolMode.PICKAXE:
				if survival_stats.use_stamina(8.0):
					_start_tool_action(PlayerState.ACTION_MINE, tex_mining, 5, 10.0, 0.4)
					_try_hit_rock()
			ToolMode.SWORD:
				if survival_stats.use_stamina(12.0):
					_start_tool_action(PlayerState.ACTION_ATTACK, tex_attack, 9, 16.0, 0.45)
					_try_hit_enemies()

func _start_tool_action(new_state: PlayerState, tex: Texture2D, frames: int, fps: float, duration: float) -> void:
	state = new_state
	action_timer = duration
	velocity = Vector2.ZERO
	_set_anim(tex, frames, fps)

func _process_action(delta: float) -> void:
	action_timer -= delta
	if action_timer <= 0.0:
		state = PlayerState.IDLE
		_set_anim(tex_idle, 3, 5.0)

func _start_dodge(dir: Vector2) -> void:
	state = PlayerState.DODGE
	dodge_dir = dir
	dodge_timer = dodge_duration

func _process_dodge(delta: float) -> void:
	dodge_timer -= delta
	velocity = dodge_dir * dodge_speed
	move_and_slide()
	if dodge_timer <= 0.0:
		state = PlayerState.IDLE
		_set_anim(tex_idle, 3, 5.0)

func _set_anim(tex: Texture2D, h_frames: int, fps: float) -> void:
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
	var frame_duration = 1.0 / anim_fps
	if anim_timer >= frame_duration:
		anim_timer -= frame_duration
		current_frame = (current_frame + 1) % sprite.hframes
		sprite.frame = current_frame

func _try_hit_tree() -> void:
	for body in interaction_area.get_overlapping_bodies():
		if body is TreeProp:
			body.take_hit()
			return

func _try_hit_rock() -> void:
	for body in interaction_area.get_overlapping_bodies():
		if body is RockProp:
			body.take_hit()
			return

func _try_hit_enemies() -> void:
	# Quet chem quai hoac cay/da xung quanh
	for body in interaction_area.get_overlapping_bodies():
		if body is TreeProp:
			body.take_hit()
		elif body is RockProp:
			body.take_hit()
