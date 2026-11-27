class_name FX
extends RefCounted
## Quản lý hiệu ứng hình ảnh (VFX), hiệu ứng va chạm (Hit), công cụ gãy và âm thanh.

const StructureVisuals = preload("res://src/fx/StructureVisuals.gd")

static var _chip_tex: Texture2D = null
static var _snd_broken: AudioStream = null
static var _snd_hit_wood: AudioStream = null
static var _snd_hit_stone: AudioStream = null

static func _init_resources() -> void:
	if not _chip_tex:
		var p = "res://assets/vfx/particle_chip.png"
		if ResourceLoader.exists(p):
			_chip_tex = load(p)
		elif FileAccess.file_exists(p) or FileAccess.file_exists(ProjectSettings.globalize_path(p)):
			var img = Image.load_from_file(p if FileAccess.file_exists(p) else ProjectSettings.globalize_path(p))
			if img and not img.is_empty():
				_chip_tex = ImageTexture.create_from_image(img)
	if not _snd_broken and ResourceLoader.exists("res://assets/audio/tool_broken.wav"):
		_snd_broken = load("res://assets/audio/tool_broken.wav")
	if not _snd_hit_wood and ResourceLoader.exists("res://assets/audio/hit_wood.wav"):
		_snd_hit_wood = load("res://assets/audio/hit_wood.wav")
	if not _snd_hit_stone and ResourceLoader.exists("res://assets/audio/hit_stone.wav"):
		_snd_hit_stone = load("res://assets/audio/hit_stone.wav")

static func _find_parent_node(custom_parent: Node = null) -> Node:
	if is_instance_valid(custom_parent):
		return custom_parent
	var main_loop = Engine.get_main_loop()
	if main_loop is SceneTree:
		var st = main_loop as SceneTree
		if st.current_scene:
			return st.current_scene
		elif st.root:
			return st.root
	return null

## ==================================================================
## VIỆC 2: HIỆU ỨNG MẢNH VỠ KHI CHẶT CÂY / ĐẬP ĐÁ (spawn_hit)
## ==================================================================
static func spawn_hit(pos: Vector2, material_kind: String = "wood", parent: Node = null) -> Node2D:
	_init_resources()
	var host = _find_parent_node(parent)
	if not host:
		return null

	var container = Node2D.new()
	container.global_position = pos
	container.z_index = 10
	host.add_child(container)

	# 1. Particles
	var p = CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 16
	p.lifetime = 0.38
	p.direction = Vector2(0, -1)
	p.spread = 150.0
	p.gravity = Vector2(0, 340)
	p.initial_velocity_min = 70.0
	p.initial_velocity_max = 140.0
	p.angular_velocity_min = -240.0
	p.angular_velocity_max = 240.0
	p.scale_amount_min = 1.2
	p.scale_amount_max = 2.4
	if _chip_tex:
		p.texture = _chip_tex

	var sfx_to_play: AudioStream = null

	match material_kind.to_lower():
		"wood", "cây", "gỗ":
			p.color = Color(0.76, 0.52, 0.28, 1.0)
			sfx_to_play = _snd_hit_wood
		"stone", "đá":
			p.color = Color(0.74, 0.76, 0.80, 1.0)
			sfx_to_play = _snd_hit_stone
		"metal", "iron", "sắt":
			p.color = Color(1.0, 0.85, 0.25, 1.0)
			p.initial_velocity_max = 180.0
			sfx_to_play = _snd_hit_stone
		_:
			p.color = Color(0.85, 0.2, 0.2, 1.0)

	container.add_child(p)
	p.emitting = true

	# 2. Sound
	if sfx_to_play:
		var asp = AudioStreamPlayer2D.new()
		asp.stream = sfx_to_play
		asp.volume_db = -4.0
		asp.bus = "Master"
		container.add_child(asp)
		asp.play()

	# 3. Auto clean
	var tw = container.create_tween()
	tw.tween_interval(0.5)
	tw.tween_callback(container.queue_free)

	return container

## ==================================================================
## VIỆC 2: HIỆU ỨNG + ÂM THANH KHI CÔNG CỤ GÃY (tool_broken)
## ==================================================================
static func tool_broken(pos: Vector2, parent: Node = null) -> Node2D:
	_init_resources()
	var host = _find_parent_node(parent)
	if not host:
		return null

	var container = Node2D.new()
	container.global_position = pos
	container.z_index = 15
	host.add_child(container)

	# 1. Shard Particles Burst
	var p = CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 26
	p.lifetime = 0.55
	p.spread = 180.0
	p.gravity = Vector2(0, 360)
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 240.0
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.scale_amount_min = 1.6
	p.scale_amount_max = 3.2
	p.color = Color(1.0, 0.35, 0.2, 1.0)
	if _chip_tex:
		p.texture = _chip_tex
	container.add_child(p)
	p.emitting = true

	# 2. Shockwave flash ring
	var flash = Line2D.new()
	flash.width = 3.0
	flash.default_color = Color(1.0, 0.85, 0.3, 0.9)
	var pts: PackedVector2Array = []
	for i in range(17):
		var a = (float(i) / 16.0) * TAU
		pts.append(Vector2(cos(a), sin(a)) * 14.0)
	flash.points = pts
	container.add_child(flash)

	var ring_tw = flash.create_tween()
	ring_tw.tween_property(flash, "scale", Vector2(2.5, 2.5), 0.35)
	ring_tw.parallel().tween_property(flash, "modulate:a", 0.0, 0.35)

	# 3. Floating label [CÔNG CỤ ĐÃ GÃY!]
	var label = Label.new()
	label.text = "💥 CÔNG CỤ ĐÃ GÃY!"
	label.top_level = true
	label.global_position = pos + Vector2(-65, -35)
	label.modulate = Color(1.0, 0.25, 0.2, 1.0)
	label.add_theme_font_size_override("font_size", 13)
	container.add_child(label)

	var lbl_tw = label.create_tween().set_parallel(true)
	lbl_tw.tween_property(label, "position:y", label.position.y - 30.0, 0.75)
	lbl_tw.tween_property(label, "modulate:a", 0.0, 0.75)

	# 4. Audio stream player
	if _snd_broken:
		var asp = AudioStreamPlayer2D.new()
		asp.stream = _snd_broken
		asp.volume_db = 0.0
		container.add_child(asp)
		asp.play()

	# 5. Clean up
	var tw = container.create_tween()
	tw.tween_interval(0.85)
	tw.tween_callback(container.queue_free)

	return container

## ==================================================================
## VIỆC 2: GET TIER TEXTURE CHO CÔNG TRÌNH (Claude gọi ở Structure.set_tier)
## ==================================================================
static func get_tier_texture(structure_type: int, tier: int, is_open: bool = false) -> Texture2D:
	return StructureVisuals.get_tier_texture(structure_type, tier, is_open)
