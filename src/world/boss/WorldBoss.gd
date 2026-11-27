extends CharacterBody2D

signal boss_spawned(boss_name: String, max_hp: int, pos: Vector2)
signal boss_damaged(current_hp: int, max_hp: int, player_dmg: int)
signal world_boss_defeated(summary_data: Dictionary)

enum BossState {
	IDLE,
	CHASE,
	SLAM_ATTACK,
	STOMP_SHOCKWAVE,
	HURT,
	DEATH
}

@export var boss_name: String = "Thái Cổ Ma Hùng"
@export var base_health: int = 450
@export var base_damage: int = 25
@export var move_speed: float = 85.0

var current_health: int = 450
var max_health: int = 450
var attack_damage: int = 25
var spawned_day: int = 3
var state: BossState = BossState.IDLE

var state_timer: float = 0.0
var stomp_cooldown: float = 6.0
var anim_timer: float = 0.0
var current_frame: int = 0
var anim_fps: float = 6.0

# Damage tracking for Alliance / Liên Minh contribution (§8)
var player_damage_map: Dictionary = {}

var target_player: CharacterBody2D = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var boss_hud: CanvasLayer = $BossHUD
@onready var hp_bar: ProgressBar = $BossHUD/BossBarPanel/VBox/ProgressBar
@onready var label_boss_title: Label = $BossHUD/BossBarPanel/VBox/LabelTitle
@onready var label_contrib: Label = $BossHUD/BossBarPanel/VBox/LabelContribution

var tex_idle: Texture2D
var tex_walk: Texture2D
var tex_attack: Texture2D
var tex_hurt: Texture2D
var tex_death: Texture2D

func _ready() -> void:
	add_to_group("boss")
	add_to_group("enemy")
	
	_load_textures()
	_update_hud()
	_set_anim(tex_idle, 3, 4.0)

# ==========================================
# FACTORY METHOD CHO CLAUDE GỌI (SPEC §8)
# ==========================================
static func spawn_for_day(day: int, base_pos: Vector2) -> Node2D:
	var boss_scene = load("res://src/world/boss/WorldBoss.tscn")
	if not boss_scene:
		push_error("Cannot load WorldBoss.tscn")
		return null
		
	var boss = boss_scene.instantiate()
	boss.spawned_day = day
	
	# Scaling formula from Spec §5: M(d) = 1 + 0.15·√d + 0.01·d
	var m_d = 1.0 + 0.15 * sqrt(float(day)) + 0.01 * float(day)
	boss.max_health = int(boss.base_health * m_d)
	boss.current_health = boss.max_health
	boss.attack_damage = int(boss.base_damage * m_d)
	
	# Position far from base (600 - 850 px)
	var angle = randf() * TAU
	var dist = randf_range(620.0, 850.0)
	boss.global_position = base_pos + Vector2(cos(angle), sin(angle)) * dist
	
	return boss

func _load_textures() -> void:
	tex_idle = load("res://assets/enemies/boar/BoarIdle-Sheet.png")
	tex_walk = load("res://assets/enemies/boar/BoarWalk-Sheet.png")
	tex_attack = load("res://assets/enemies/boar/BoarAttack-Sheet.png")
	tex_hurt = load("res://assets/enemies/boar/BoarHurt-Sheet.png")
	tex_death = load("res://assets/enemies/boar/BoarDeath-Sheet.png")

func _physics_process(delta: float) -> void:
	if state == BossState.DEATH:
		_update_animation(delta)
		return
		
	state_timer -= delta
	stomp_cooldown -= delta
	
	_find_player()
	
	match state:
		BossState.IDLE:
			velocity = Vector2.ZERO
			if target_player:
				state = BossState.CHASE
				_set_anim(tex_walk, 4, 6.0)
		BossState.CHASE:
			_process_chase(delta)
		BossState.SLAM_ATTACK:
			velocity = Vector2.ZERO
			if state_timer <= 0.0:
				state = BossState.CHASE
				_set_anim(tex_walk, 4, 6.0)
		BossState.STOMP_SHOCKWAVE:
			velocity = Vector2.ZERO
			if state_timer <= 0.0:
				state = BossState.CHASE
				_set_anim(tex_walk, 4, 6.0)
		BossState.HURT:
			velocity = Vector2.ZERO
			if state_timer <= 0.0:
				state = BossState.CHASE
				_set_anim(tex_walk, 4, 6.0)
				
	move_and_slide()
	_update_animation(delta)

func _find_player() -> void:
	if is_instance_valid(target_player): return
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target_player = players[0] as CharacterBody2D

func _process_chase(_delta: float) -> void:
	if not is_instance_valid(target_player):
		state = BossState.IDLE
		return
		
	var dist = global_position.distance_to(target_player.global_position)
	
	# Trigger AoE Stomp Shockwave if ready
	if stomp_cooldown <= 0.0 and dist <= 120.0:
		_trigger_stomp_shockwave()
		return
		
	# Trigger Melee Slam
	if dist <= 55.0:
		_trigger_slam_attack()
		return
		
	var dir = (target_player.global_position - global_position).normalized()
	velocity = dir * move_speed
	sprite.flip_h = dir.x < 0

func _trigger_slam_attack() -> void:
	state = BossState.SLAM_ATTACK
	state_timer = 0.65
	_set_anim(tex_attack, 7, 12.0)
	
	# Delayed impact
	if is_inside_tree():
		get_tree().create_timer(0.3).timeout.connect(func():
			if state == BossState.SLAM_ATTACK and is_instance_valid(target_player):
				var d = global_position.distance_to(target_player.global_position)
				if d <= 70.0:
					var stats = target_player.get_node_or_null("SurvivalStats")
					if stats and stats.has_method("take_damage"):
						stats.take_damage(attack_damage)
		)

func _trigger_stomp_shockwave() -> void:
	state = BossState.STOMP_SHOCKWAVE
	state_timer = 0.8
	stomp_cooldown = 7.0
	_set_anim(tex_attack, 7, 10.0)
	
	# Camera shake and AoE blast
	if is_inside_tree():
		get_tree().create_timer(0.35).timeout.connect(func():
			_spawn_shockwave_visual()
			if is_instance_valid(target_player):
				var d = global_position.distance_to(target_player.global_position)
				if d <= 130.0:
					var stats = target_player.get_node_or_null("SurvivalStats")
					if stats and stats.has_method("take_damage"):
						stats.take_damage(int(attack_damage * 0.7))
		)

func _spawn_shockwave_visual() -> void:
	var fx = Line2D.new()
	fx.width = 3.0
	fx.default_color = Color(1.0, 0.4, 0.1, 0.8)
	var pts: PackedVector2Array = []
	for i in range(17):
		var a = (float(i) / 16.0) * TAU
		pts.append(Vector2(cos(a), sin(a)) * 120.0)
	fx.points = pts
	fx.global_position = global_position
	get_parent().add_child(fx)
	var tween = fx.create_tween()
	tween.tween_property(fx, "scale", Vector2(1.5, 1.5), 0.35)
	tween.tween_property(fx, "modulate:a", 0.0, 0.35)
	tween.chain().tween_callback(fx.queue_free)

# ==========================================
# DAMAGE TRACKING & CONTRIBUTIONS
# ==========================================
## power > 0: sát thương theo bậc vũ khí (Player/EquipmentData), giống BoarEnemy.
func take_hit(tool_id: int = 2, power: int = -1, attacker_id: String = "local_player") -> void:
	if state == BossState.DEATH: return
	
	var dmg = 25
	if tool_id == 2: # SWORD
		dmg = 40
	elif tool_id == 1: # PICKAXE
		dmg = 20
	elif tool_id == 0: # AXE
		dmg = 20
	if power > 0:
		dmg = power
	dmg = int(round(dmg * GameState.get_player_damage_mult()))
		
	current_health -= dmg
	
	# Record damage contribution
	player_damage_map[attacker_id] = player_damage_map.get(attacker_id, 0) + dmg
	
	boss_damaged.emit(current_health, max_health, dmg)
	_update_hud()
	_play_flash()
	
	if current_health <= 0:
		_die()
	else:
		if state != BossState.SLAM_ATTACK and state != BossState.STOMP_SHOCKWAVE:
			state = BossState.HURT
			state_timer = 0.2
			_set_anim(tex_hurt, 3, 10.0)

func _update_hud() -> void:
	if hp_bar:
		hp_bar.max_value = max_health
		hp_bar.value = max(0, current_health)
	if label_boss_title:
		label_boss_title.text = "👑 [THÚ VƯƠNG HOANG CỔ] %s (MÁU: %d / %d)" % [
			boss_name, max(0, current_health), max_health
		]
	if label_contrib:
		var my_dmg = player_damage_map.get("local_player", 0)
		var pct = (float(my_dmg) / float(max_health)) * 100.0 if max_health > 0 else 0.0
		var alliance_pts = int(pct * 10.0)
		label_contrib.text = "Đóng góp của bạn: %d Sát thương (%.1f%%) ➔ +%d Điểm Liên Minh" % [
			my_dmg, pct, alliance_pts
		]

func _die() -> void:
	state = BossState.DEATH
	velocity = Vector2.ZERO
	_set_anim(tex_death, 9, 12.0)
	
	var col = get_node_or_null("CollisionShape2D")
	if col: col.set_deferred("disabled", true)
	
	# Calculate final contribution results for Alliance leaderboard (§8)
	var contributions = {}
	for p_id in player_damage_map.keys():
		var dmg = player_damage_map[p_id]
		var pct = (float(dmg) / float(max_health)) * 100.0
		var alliance_pts = int(pct * 10.0) # 0 - 1000 Alliance points
		contributions[p_id] = {
			"damage_dealt": dmg,
			"percentage": pct,
			"alliance_points": alliance_pts
		}
		
	var summary_data = {
		"boss_name": boss_name,
		"day": spawned_day,
		"total_hp": max_health,
		"contributions": contributions,
		"drops": ["Ma Hạch Nguyên Sinh", "Rương Thú Vương", "Đan Reroll Thiên Phú"]
	}
	
	world_boss_defeated.emit(summary_data)
	_show_victory_banner(summary_data)
	
	if is_inside_tree():
		get_tree().create_timer(3.0).timeout.connect(queue_free)

func _show_victory_banner(summary: Dictionary) -> void:
	var canvas = CanvasLayer.new()
	var container = CenterContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	var vbox = VBoxContainer.new()
	
	var lbl_title = Label.new()
	lbl_title.text = "✦ THÚ VƯƠNG HOANG CỔ ĐÃ BỊ TIÊU DIỆT! ✦"
	lbl_title.modulate = Color(1.0, 0.85, 0.2)
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_title.add_theme_font_size_override("font_size", 22)
	
	var my_contrib = summary.contributions.get("local_player", {})
	var lbl_sub = Label.new()
	lbl_sub.text = "Bạn đã gây %d sát thương (%.1f%%) • Nhận: +%d Điểm Đóng Góp Liên Minh\nRơi ra: 1x Ma Hạch, 2x Đan Reroll, 30x Quặng Sắt" % [
		my_contrib.get("damage_dealt", 0),
		my_contrib.get("percentage", 0.0),
		my_contrib.get("alliance_points", 0)
	]
	lbl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sub.add_theme_font_size_override("font_size", 14)
	
	vbox.add_child(lbl_title)
	vbox.add_child(lbl_sub)
	container.add_child(vbox)
	canvas.add_child(container)
	get_parent().add_child(canvas)
	
	var tween = canvas.create_tween()
	tween.tween_property(container, "modulate:a", 1.0, 0.4).from(0.0)
	tween.tween_interval(3.5)
	tween.tween_property(container, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(canvas.queue_free)

func _play_flash() -> void:
	if not sprite or not is_inside_tree(): return
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(2.5, 0.3, 0.3), 0.06)
	tween.tween_property(sprite, "modulate", Color(1.8, 0.5, 0.2), 0.08)

func _set_anim(tex: Texture2D, h_frames: int, fps: float) -> void:
	if not sprite: sprite = get_node_or_null("Sprite2D")
	if not sprite or not tex: return
	if sprite.texture != tex:
		sprite.texture = tex
		sprite.hframes = h_frames
	anim_fps = fps
	current_frame = 0
	sprite.frame = 0
	anim_timer = 0.0

func _update_animation(delta: float) -> void:
	if not sprite or sprite.hframes <= 1: return
	anim_timer += delta
	var frame_dur = 1.0 / anim_fps
	if anim_timer >= frame_dur:
		anim_timer -= frame_dur
		current_frame = (current_frame + 1) % sprite.hframes
		sprite.frame = current_frame
