class_name MainWorld
extends Node2D

@onready var map_gen: MapGenerator = $MapGenerator
@onready var player: Player = $Player
@onready var day_night: DayNightCycle = $DayNightCycle
@onready var hud: HUD = $HUD
@onready var campfire: Area2D = $Campfire

var current_biome_temp: float = 28.0

func _ready() -> void:
	if map_gen:
		map_gen.player_spawn_found.connect(_on_player_spawn_found)
		map_gen.biome_changed.connect(_on_biome_changed)
		
	if player and player.survival_stats:
		player.survival_stats.health_changed.connect(_on_health_changed)
		player.survival_stats.stamina_changed.connect(_on_stamina_changed)
		player.survival_stats.temperature_changed.connect(_on_temperature_changed)
		
	if day_night:
		day_night.time_changed.connect(_on_time_changed)
		day_night.phase_changed.connect(_on_phase_changed)
		
	if campfire:
		campfire.body_entered.connect(_on_campfire_entered)
		campfire.body_exited.connect(_on_campfire_exited)

func _process(_delta: float) -> void:
	if player and map_gen:
		map_gen.update_player_biome(player.global_position)

	if player and player.survival_stats and day_night:
		if not player.survival_stats.is_near_fire:
			# Ket hop giua nhiet do khu vuc va chu ky ngay/dem
			var time_temp_offset = 0.0
			match day_night.current_phase:
				"Night": time_temp_offset = -14.0 # Dem ha them 14 do
				"Dusk": time_temp_offset = -4.0
				"Dawn": time_temp_offset = -6.0
				"Day": time_temp_offset = 2.0
				
			player.survival_stats.target_temperature = max(4.0, current_biome_temp + time_temp_offset)

func _on_player_spawn_found(spawn_pos: Vector2) -> void:
	if player:
		player.global_position = spawn_pos
	if campfire:
		campfire.global_position = spawn_pos + Vector2(60, 0)

func _on_biome_changed(biome_name: String, ambient_temp: float) -> void:
	current_biome_temp = ambient_temp
	if hud:
		hud.update_biome(biome_name)

func _on_health_changed(hp: float, max_hp: float) -> void:
	if hud: hud.update_health(hp, max_hp)

func _on_stamina_changed(stamina: float, max_stamina: float) -> void:
	if hud: hud.update_stamina(stamina, max_stamina)

func _on_temperature_changed(temp: float) -> void:
	if hud: hud.update_temperature(temp)

func _on_time_changed(hour: int, minute: int) -> void:
	if hud: hud.update_time(hour, minute)

func _on_phase_changed(phase_name: String) -> void:
	if hud: hud.update_phase(phase_name)

func _on_campfire_entered(body: Node2D) -> void:
	if body == player and player.survival_stats:
		player.survival_stats.is_near_fire = true

func _on_campfire_exited(body: Node2D) -> void:
	if body == player and player.survival_stats:
		player.survival_stats.is_near_fire = false
