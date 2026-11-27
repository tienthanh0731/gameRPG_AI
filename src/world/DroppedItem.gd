extends Area2D

signal collected(item_name: String, amount: int)

@export var item_name: String = "Gỗ"
@export var amount: int = 1

var target_player: CharacterBody2D = null
var is_collecting: bool = false
var bob_offset: float = 0.0
var base_pos: Vector2

func _ready() -> void:
	base_pos = global_position
	body_entered.connect(_on_body_entered)
	
	# Initial bounce animation
	var rand_target = base_pos + Vector2(randf_range(-18.0, 18.0), randf_range(-14.0, 14.0))
	var tween = create_tween().set_parallel(false)
	var peak = Vector2((base_pos.x + rand_target.x) * 0.5, min(base_pos.y, rand_target.y) - 14.0)
	tween.tween_property(self, "global_position", peak, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", rand_target, 0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): base_pos = global_position)
	
	# Check if player is already standing on the spawn position
	get_tree().create_timer(0.05).timeout.connect(_check_initial_overlap)

func _check_initial_overlap() -> void:
	if is_collecting: return
	for b in get_overlapping_bodies():
		if _is_valid_player(b):
			_start_collect(b as CharacterBody2D)
			break

func setup(p_name: String, p_amount: int, p_tex: Texture2D) -> void:
	item_name = p_name
	amount = p_amount
	var spr = get_node_or_null("Sprite2D")
	if spr and p_tex:
		spr.texture = p_tex

func _process(delta: float) -> void:
	if is_collecting:
		if is_instance_valid(target_player):
			global_position = global_position.move_toward(target_player.global_position, 650.0 * delta)
			if global_position.distance_to(target_player.global_position) < 28.0:
				_finish_collect()
		else:
			_finish_collect()
		return
		
	# Idle bobbing
	bob_offset += delta * 4.0
	var spr = get_node_or_null("Sprite2D")
	if spr:
		spr.position.y = sin(bob_offset) * 3.0

func _on_body_entered(body: Node2D) -> void:
	if is_collecting:
		return
	if _is_valid_player(body):
		_start_collect(body as CharacterBody2D)

func _is_valid_player(body: Node2D) -> bool:
	if not body: return false
	if body.is_in_group("player"): return true
	if body.name == "Player": return true
	if body is CharacterBody2D and body.get_node_or_null("Inventory") != null: return true
	return false

func _start_collect(p: CharacterBody2D) -> void:
	target_player = p
	is_collecting = true

func _finish_collect() -> void:
	var final_amt = amount
	
	if is_instance_valid(target_player):
		var inv = target_player.get_node_or_null("Inventory")
		if inv and inv.has_method("add_resource"):
			# Apply Talent Gathering multiplier if applicable
			if GameState and not GameState.active_talent.is_empty():
				var t = GameState.active_talent
				if item_name == "Gỗ" and t.get("id") == "a_wood_spirit":
					final_amt *= 2
				elif item_name in ["Đá", "Quặng Sắt"] and t.get("id") == "b_earth_lord":
					final_amt *= 2
				elif t.get("id") == "f_hardworking":
					final_amt += 1
					
			inv.add_resource(item_name, final_amt)
			
	collected.emit(item_name, final_amt)
	_spawn_floating_text("+%d %s" % [final_amt, item_name])
	queue_free()

func _spawn_floating_text(text: String) -> void:
	var label = Label.new()
	label.text = text
	label.top_level = true
	label.global_position = global_position + Vector2(-20, -25)
	label.modulate = Color(0.4, 1.0, 0.4) if "Đan" in text else Color(1.0, 0.95, 0.4)
	label.add_theme_font_size_override("font_size", 13)
	
	var parent_node = get_parent()
	if parent_node:
		parent_node.add_child(label)
		var tween = label.create_tween().set_parallel(true)
		tween.tween_property(label, "position:y", label.position.y - 30.0, 0.7)
		tween.tween_property(label, "modulate:a", 0.0, 0.7)
		tween.chain().tween_callback(label.queue_free)
