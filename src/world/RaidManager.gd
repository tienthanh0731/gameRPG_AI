extends Node2D

const BoarScene = preload("res://src/entities/BoarEnemy.tscn")

signal raid_started(wave_number: int)
signal raid_cleared(wave_number: int)

var current_wave: int = 0
var active_beasts: Array[Node2D] = []

var player: CharacterBody2D
var campfire: Area2D
var day_night: CanvasModulate
var hud: CanvasLayer

func setup(p_player: CharacterBody2D, p_campfire: Area2D, p_day_night: CanvasModulate, p_hud: CanvasLayer) -> void:
	player = p_player
	campfire = p_campfire
	day_night = p_day_night
	hud = p_hud
	
	if day_night and day_night.has_signal("phase_changed"):
		day_night.phase_changed.connect(_on_phase_changed)

func _on_phase_changed(phase: String) -> void:
	if phase == "Dusk":
		_announce_dusk_warning()
	elif phase == "Night":
		_start_night_raid()
	elif phase == "Dawn":
		_finish_night_raid()

func _announce_dusk_warning() -> void:
	var wave_size = 8
	if GameState:
		wave_size = GameState.get_raid_wave_size()
	EventBus.dusk_warning.emit(wave_size, "Heo Rừng Cuồng Nộ")
	_show_banner(
		"⚠ HOÀNG HÔN: CẢNH BÁO THÚ TRIỀU SẮP TỚI! ⚠",
		"Ước tính %d dã thú sẽ tràn về căn cứ khi màn đêm buông xuống. Hãy gia cố tường thành!" % wave_size,
		Color(1.0, 0.6, 0.2)
	)

func _start_night_raid() -> void:
	current_wave += 1
	var wave_size = 8
	if GameState:
		wave_size = GameState.get_raid_wave_size()
		
	raid_started.emit(current_wave)
	EventBus.night_started.emit(wave_size)
	
	_show_banner(
		"☠ THÚ TRIỀU BAN ĐÊM ĐÃ TỚI! ☠",
		"Bầy %d dã thú hoang dã đang điên cuồng tấn công căn cứ!" % wave_size,
		Color(1.0, 0.25, 0.25)
	)
	
	var center = campfire.global_position if campfire else (player.global_position if player else Vector2.ZERO)
	
	for i in range(wave_size):
		var angle = (float(i) / float(wave_size)) * TAU + randf_range(-0.25, 0.25)
		var spawn_pos = center + Vector2(cos(angle), sin(angle)) * randf_range(380.0, 520.0)
		_spawn_boar(spawn_pos)

func _spawn_boar(pos: Vector2) -> void:
	var boar = BoarScene.instantiate()
	boar.global_position = pos
	
	# Chance of spawning elite monster based on day milestone
	if GameState and GameState.current_day >= 16 and randf() < 0.2:
		boar.is_elite = true
		
	add_child(boar)
	active_beasts.append(boar)
	
	boar.boar_died.connect(func(p):
		active_beasts.erase(boar)
		_on_beast_killed(p)
	)

func _on_beast_killed(drop_pos: Vector2) -> void:
	var main = get_parent()
	if main and main.has_method("_on_resource_dropped"):
		main._on_resource_dropped("Thịt Rừng", randi_range(1, 2), drop_pos)
		if randf() < 0.6:
			main._on_resource_dropped("Da Thú", 1, drop_pos + Vector2(10, 5))

func _finish_night_raid() -> void:
	if current_wave > 0:
		raid_cleared.emit(current_wave)
		EventBus.raid_wave_cleared.emit(current_wave)
		
		# End-of-Day Evaluation at Dawn (06:00)
		if GameState:
			GameState.evaluate_day_end()
			
		# Kill remaining roaming beasts if day has come
		for b in active_beasts:
			if is_instance_valid(b) and b.has_method("take_hit"):
				b.queue_free()
		active_beasts.clear()

func _show_banner(title: String, subtitle: String, col: Color) -> void:
	var canvas = CanvasLayer.new()
	var container = CenterContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var vbox = VBoxContainer.new()
	var lbl_title = Label.new()
	lbl_title.text = title
	lbl_title.modulate = col
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_title.add_theme_font_size_override("font_size", 22)
	
	var lbl_sub = Label.new()
	lbl_sub.text = subtitle
	lbl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sub.add_theme_font_size_override("font_size", 14)
	
	vbox.add_child(lbl_title)
	vbox.add_child(lbl_sub)
	container.add_child(vbox)
	canvas.add_child(container)
	get_parent().add_child(canvas)
	
	var tween = canvas.create_tween()
	tween.tween_property(container, "modulate:a", 1.0, 0.4).from(0.0)
	tween.tween_interval(2.6)
	tween.tween_property(container, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(canvas.queue_free)
