class_name MainWorld
extends Node2D

@onready var player: Player = $Player
@onready var day_night: DayNightCycle = $DayNightCycle
@onready var hud: HUD = $HUD
@onready var campfire: Area2D = $Campfire

func _ready() -> void:
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
	if player and player.survival_stats and day_night:
		if not player.survival_stats.is_near_fire:
			player.survival_stats.target_temperature = day_night.get_ambient_temperature()

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
