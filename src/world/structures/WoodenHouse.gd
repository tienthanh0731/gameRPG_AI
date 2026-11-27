extends "res://src/world/Structure.gd"

@onready var shelter_area: Area2D = $ShelterArea
@onready var rest_prompt: Label = $RestPrompt

var player_in_shelter: CharacterBody2D = null

func _ready() -> void:
	structure_type = StructureType.HOUSE
	structure_name = "Nhà Gỗ Nhỏ"
	max_health = 250
	super._ready() # base_max_health / bậc vật liệu / thanh máu
	
	if shelter_area:
		shelter_area.body_entered.connect(_on_shelter_body_entered)
		shelter_area.body_exited.connect(_on_shelter_body_exited)
		
	if rest_prompt:
		rest_prompt.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if player_in_shelter and event is InputEventKey and event.pressed and event.keycode == KEY_E:
		_rest_player()

func _on_shelter_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_shelter = body as CharacterBody2D
		var stats = body.get_node_or_null("SurvivalStats")
		if stats:
			stats.is_near_fire = true
		if rest_prompt:
			rest_prompt.visible = true
		_spawn_hint_text("BẠN ĐANG Ở TRONG NHÀ GỖ (Được giữ ấm & an toàn)", Color(1.0, 0.9, 0.4))

func _on_shelter_body_exited(body: Node2D) -> void:
	if body == player_in_shelter:
		var stats = body.get_node_or_null("SurvivalStats")
		if stats:
			var fires = get_tree().get_nodes_in_group("campfire")
			var near_fire = false
			for f in fires:
				if f.global_position.distance_to(body.global_position) <= 65.0:
					near_fire = true
					break
			if not near_fire:
				stats.is_near_fire = false
		player_in_shelter = null
		if rest_prompt:
			rest_prompt.visible = false

func _rest_player() -> void:
	if not player_in_shelter: return
	var stats = player_in_shelter.get_node_or_null("SurvivalStats")
	if stats:
		if stats.has_method("heal"):
			stats.heal(25.0)
		elif "current_health" in stats and "max_health" in stats:
			stats.current_health = min(stats.max_health, stats.current_health + 25.0)
			if stats.has_signal("health_changed"):
				stats.health_changed.emit(stats.current_health, stats.max_health)
		stats.current_stamina = stats.max_stamina
		if stats.has_signal("stamina_changed"):
			stats.stamina_changed.emit(stats.current_stamina, stats.max_stamina)
		stats.target_temperature = 37.0
	_spawn_hint_text("ĐÃ NGHỈ NGƠI TRONG NHÀ GỖ (+25 HP, Hồi phục thể lực)!", Color(0.3, 1.0, 0.4))
