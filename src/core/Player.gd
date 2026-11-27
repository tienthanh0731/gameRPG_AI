extends CharacterBody2D

signal tool_changed(tool_mode: int)

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

@export var move_speed: float = 160.0
@export var sprint_speed: float = 230.0
@export var dodge_speed: float = 380.0

@onready var survival_stats: Node = $SurvivalStats
@onready var inventory: Node = $Inventory
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
	tool_changed.emit(current_tool)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_trigger_action()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			current_tool = ToolMode.AXE
			tool_changed.emit(current_tool)
		elif event.keycode == KEY_2:
			current_tool = ToolMode.PICKAXE
			tool_changed.emit(current_tool)
		elif event.keycode == KEY_3:
			current_tool = ToolMode.SWORD
			tool_changed.emit(current_tool)

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
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) or Input.is_action_pressed("move_left"):
		input_vec.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or Input.is_action_pressed("move_right"):
		input_vec.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or Input.is_action_pressed("move_up"):
		input_vec.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN) or Input.is_action_pressed("move_down"):
		input_vec.y += 1.0
	input_vec = input_vec.normalized()

	if Input.is_action_just_pressed("dodge") and input_vec != Vector2.ZERO:
		if survival_stats and survival_stats.has_method("use_stamina") and survival_stats.use_stamina(18.0):
			_start_dodge(input_vec)
			return

	var is_sprinting = Input.is_key_pressed(KEY_SHIFT) and input_vec != Vector2.ZERO
	var speed = move_speed
	if is_sprinting and survival_stats and survival_stats.has_method("use_stamina") and survival_stats.use_stamina(10.0 * delta):
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
		_trigger_action()

func _trigger_action() -> void:
	if state != PlayerState.IDLE and state != PlayerState.WALK:
		return

	var parent_node = get_parent()
	if parent_node:
		var bm = parent_node.get_node_or_null("BuildingManager")
		if bm and bm.get("is_building") == true:
			return

	var mouse_p = get_global_mouse_position()
	sprite.flip_h = mouse_p.x < global_position.x

	match current_tool:
		ToolMode.AXE:
			if _can_use_stamina(8.0):
				_start_tool_action(PlayerState.ACTION_AXE, tex_axe, 5, 12.0, 0.35)
				_try_hit_interactable()
		ToolMode.PICKAXE:
			if _can_use_stamina(8.0):
				_start_tool_action(PlayerState.ACTION_MINE, tex_mining, 5, 12.0, 0.35)
				_try_hit_interactable()
		ToolMode.SWORD:
			if _can_use_stamina(12.0):
				_start_tool_action(PlayerState.ACTION_ATTACK, tex_attack, 9, 16.0, 0.4)
				_try_hit_interactable()

func _can_use_stamina(amount: float) -> bool:
	if survival_stats and survival_stats.has_method("use_stamina"):
		return survival_stats.use_stamina(amount)
	return true

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

func _try_hit_interactable() -> void:
	if not interaction_area:
		return
		
	var mouse_pos = get_global_mouse_position()
	var candidates: Array = []
	for body in interaction_area.get_overlapping_bodies():
		if body.has_method("take_hit"):
			candidates.append(body)

	if candidates.is_empty():
		return

	# Sort by distance to mouse position so aimed resource is prioritized
	candidates.sort_custom(func(a, b): 
		return a.global_position.distance_squared_to(mouse_pos) < b.global_position.distance_squared_to(mouse_pos)
	)

	var target = candidates[0]
	target.take_hit(current_tool)
