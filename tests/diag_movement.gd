extends Node
## Chẩn đoán: nhân vật có di chuyển / tương tác được không (giả lập phím thật).
## godot.exe --headless --path . res://tests/diag_movement.tscn

var backups: Dictionary = {}

func _ready() -> void:
	for p in [SaveSystem.ACCOUNT_PATH, SaveSystem.CHARACTER_PATH]:
		if FileAccess.file_exists(p):
			backups[p] = FileAccess.get_file_as_string(p)
	_run.call_deferred()

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true).timeout

func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)

func _run() -> void:
	var tree := get_tree()
	SaveSystem.create_new_character("Diag", ServerSim.get_or_roll_pending_talent())
	ServerSim.consume_pending_talent()
	GameState.load_from_character()
	var m = load("res://src/world/Main.tscn").instantiate()
	tree.root.add_child(m)
	tree.current_scene = m
	await _wait(1.0)
	var p = m.player
	print("paused=", tree.paused, " is_dead=", GameState.is_dead, " state=", p.state, " pos=", p.global_position)
	var pos0: Vector2 = p.global_position
	_key(KEY_D, true)
	await _wait(0.6)
	_key(KEY_D, false)
	await _wait(0.1)
	print("after D: pos=", p.global_position, " moved=", p.global_position.distance_to(pos0), " vel=", p.velocity)
	# Ai đang chặn? liệt kê va chạm quanh người chơi
	var space = p.get_world_2d().direct_space_state
	var q := PhysicsShapeQueryParameters2D.new()
	var c := CircleShape2D.new()
	c.radius = 24
	q.shape = c
	q.transform = Transform2D(0, p.global_position)
	q.collision_mask = p.collision_mask
	for hit in space.intersect_shape(q, 16):
		var col = hit.collider
		print("  overlapping: ", col.name, " groups=", col.get_groups(), " at ", col.global_position)
	for s in tree.get_nodes_in_group("structure"):
		print("  structure ", s.name, " at ", s.global_position, " dist=", s.global_position.distance_to(p.global_position))
	tree.paused = false
	for path in [SaveSystem.ACCOUNT_PATH, SaveSystem.CHARACTER_PATH]:
		SaveSystem._delete(path)
		if backups.has(path):
			FileAccess.open(path, FileAccess.WRITE).store_string(backups[path])
	tree.quit()
