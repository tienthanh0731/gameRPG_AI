extends Node2D
## RaidManager — Hoàng hôn cảnh báo, Ban đêm thú triều theo đợt, Rạng đông tổng kết.

const BoarScene = preload("res://src/entities/BoarEnemy.tscn")

signal raid_started(wave_number: int)
signal raid_cleared(wave_number: int)

## Số đợt (sub-wave) mỗi đêm; quái chia đều cho các đợt.
const SUB_WAVES: int = 3
const SUB_WAVE_INTERVAL: float = 12.0

var current_wave: int = 0
var active_beasts: Array[Node2D] = []
var pending_spawns: int = 0

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
	match phase:
		"Dusk": _announce_dusk_warning()
		"Night": _start_night_raid()
		"Dawn": _finish_night_raid()

func _announce_dusk_warning() -> void:
	var p := GameState.get_tonight_preview()
	EventBus.dusk_warning.emit(p.count, p.monster_type)
	var kind := "THÚ TRIỀU" if p.is_real else "ĐỢT TRINH SÁT"
	_show_banner(
		"⚠ HOÀNG HÔN: %s SẮP TỚI! ⚠" % kind,
		"Ước tính %d %s • Hướng tấn công: %s\nHãy gia cố tường, đặt bẫy trước 19:30!" % [
			p.count, p.monster_type, ", ".join(p.direction_names)],
		Color(1.0, 0.6, 0.2))

func _start_night_raid() -> void:
	if current_wave > 0:
		return
	current_wave += 1
	var p := GameState.get_tonight_preview()
	GameState.begin_raid(p.count)
	SaveSystem.character_data["tide_started_day"] = GameState.current_day
	raid_started.emit(current_wave)
	EventBus.night_started.emit(p.count)
	_show_banner(
		"☠ THÚ TRIỀU ĐÃ TỚI TỪ HƯỚNG %s! ☠" % ", ".join(p.direction_names).to_upper(),
		"%d dã thú (x%.2f sức mạnh) đang tràn vào căn cứ!" % [p.count, GameState.get_monster_power_mult()],
		Color(1.0, 0.25, 0.25))

	# Chia thành các đợt, mỗi đợt đến từ một trong các hướng đã báo trước
	pending_spawns = p.count
	var per_wave := ceili(float(p.count) / SUB_WAVES)
	for w in SUB_WAVES:
		var count := mini(per_wave, p.count - w * per_wave)
		if count <= 0:
			break
		var dir_idx: int = p.directions[w % p.directions.size()]
		if w == 0:
			_spawn_group(count, dir_idx, p.elite_chance)
		else:
			get_tree().create_timer(SUB_WAVE_INTERVAL * w).timeout.connect(
				_spawn_group.bind(count, dir_idx, p.elite_chance))

func _spawn_group(count: int, dir_idx: int, elite_chance: float) -> void:
	if day_night and day_night.current_phase != "Night":
		return # trời đã sáng
	var center := _base_center()
	var dir: Vector2 = GameState.DIRECTION_VECTORS[dir_idx]
	for i in count:
		var spread := randf_range(-0.6, 0.6)
		var spawn_pos := center + dir.rotated(spread) * randf_range(420.0, 560.0)
		_spawn_boar(spawn_pos, randf() < elite_chance, center)
	pending_spawns -= count

func _base_center() -> Vector2:
	if campfire:
		return campfire.global_position
	return player.global_position if player else Vector2.ZERO

func _spawn_boar(pos: Vector2, elite: bool, center: Vector2) -> void:
	var boar = BoarScene.instantiate()
	boar.global_position = pos
	boar.is_elite = elite
	boar.raid_mode = true
	boar.raid_target_pos = center
	add_child(boar)
	active_beasts.append(boar)
	boar.boar_died.connect(func(p):
		active_beasts.erase(boar)
		GameState.register_raid_kill()
		_on_beast_killed(p))

func _on_beast_killed(drop_pos: Vector2) -> void:
	var main = get_parent()
	if main and main.has_method("_on_resource_dropped"):
		main._on_resource_dropped("Thịt Rừng", randi_range(1, 2), drop_pos)
		if randf() < 0.6:
			main._on_resource_dropped("Da Thú", 1, drop_pos + Vector2(10, 5))

func _finish_night_raid() -> void:
	# current_wave == 0 nhưng đêm đã bắt đầu trước khi thoát game → vẫn tổng kết
	var started_today := int(SaveSystem.character_data.get("tide_started_day", -1)) == GameState.current_day
	if current_wave <= 0 and not started_today:
		return
	if GameState.is_dead:
		return
	raid_cleared.emit(current_wave)
	current_wave = 0
	SaveSystem.character_data.erase("tide_started_day")
	for b in active_beasts:
		if is_instance_valid(b):
			b.queue_free()
	active_beasts.clear()
	GameState.finish_raid()
	var main = get_parent()
	if main and main.has_method("save_world"):
		main.save_world()
	var summary := GameState.evaluate_day_end()
	EventBus.day_summary_ready.emit(summary)

func _show_banner(title: String, subtitle: String, col: Color) -> void:
	var canvas = CanvasLayer.new()
	canvas.layer = 5
	var container = CenterContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	tween.tween_interval(3.6)
	tween.tween_property(container, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(canvas.queue_free)
