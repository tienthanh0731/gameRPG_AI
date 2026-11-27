extends Area2D

signal collected(item_name: String, amount: int)

@export var item_name: String = "Gỗ"
@export var amount: int = 1

var target_player: CharacterBody2D = null
var is_collecting: bool = false
var bob_offset: float = 0.0
var base_pos: Vector2

func _ready() -> void:
	base_pos = position
	body_entered.connect(_on_body_entered)
	
	# Initial bounce animation
	var rand_target = base_pos + Vector2(randf_range(-20.0, 20.0), randf_range(-16.0, 16.0))
	var tween = create_tween().set_parallel(false)
	var peak = Vector2((base_pos.x + rand_target.x) * 0.5, min(base_pos.y, rand_target.y) - 16.0)
	tween.tween_property(self, "position", peak, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", rand_target, 0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): base_pos = position)

func setup(p_name: String, p_amount: int, p_tex: Texture2D) -> void:
	item_name = p_name
	amount = p_amount
	var spr = get_node_or_null("Sprite2D")
	if spr:
		spr.texture = p_tex

func _process(delta: float) -> void:
	if is_collecting:
		if target_player:
			position = position.move_toward(target_player.global_position, 550.0 * delta)
			if position.distance_to(target_player.global_position) < 18.0:
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
	if body.is_in_group("player"):
		target_player = body as CharacterBody2D
		is_collecting = true

func _finish_collect() -> void:
	if target_player:
		var inv = target_player.get_node_or_null("Inventory")
		if inv and inv.has_method("add_resource"):
			inv.add_resource(item_name, amount)
			
	collected.emit(item_name, amount)
	_spawn_floating_text("+%d %s" % [amount, item_name])
	queue_free()

func _spawn_floating_text(text: String) -> void:
	var label = Label.new()
	label.text = text
	label.top_level = true
	label.global_position = global_position + Vector2(-15, -20)
	label.modulate = Color(1.0, 0.95, 0.4)
	label.add_theme_font_size_override("font_size", 12)
	var parent_node = get_parent()
	if parent_node:
		parent_node.add_child(label)
		var tween = label.create_tween().set_parallel(true)
		tween.tween_property(label, "position:y", label.position.y - 25.0, 0.6)
		tween.tween_property(label, "modulate:a", 0.0, 0.6)
		tween.chain().tween_callback(label.queue_free)
