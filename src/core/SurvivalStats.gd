class_name SurvivalStats
extends Node

signal health_changed(current_hp: float, max_hp: float)
signal stamina_changed(current_stamina: float, max_stamina: float)
signal hunger_changed(current_hunger: float)
signal thirst_changed(current_thirst: float)
signal temperature_changed(current_temp: float)
signal player_died()

@export var max_health: float = 100.0
@export var current_health: float = 100.0

@export var max_stamina: float = 100.0
@export var current_stamina: float = 100.0
@export var stamina_regen_rate: float = 15.0

@export var hunger: float = 100.0
@export var hunger_decay_rate: float = 0.5

@export var thirst: float = 100.0
@export var thirst_decay_rate: float = 0.8

@export var body_temperature: float = 37.0
@export var target_temperature: float = 37.0

var is_near_fire: bool = false

func _process(delta: float) -> void:
	_update_needs(delta)
	_update_temperature(delta)
	_update_stamina(delta)

func _update_needs(delta: float) -> void:
	hunger = max(0.0, hunger - hunger_decay_rate * delta)
	thirst = max(0.0, thirst - thirst_decay_rate * delta)
	hunger_changed.emit(hunger)
	thirst_changed.emit(thirst)
	
	if hunger <= 0.0 or thirst <= 0.0:
		take_damage(2.0 * delta)

func _update_temperature(delta: float) -> void:
	if is_near_fire:
		target_temperature = 37.2
	
	body_temperature = move_toward(body_temperature, target_temperature, 0.2 * delta)
	temperature_changed.emit(body_temperature)
	
	if body_temperature < 32.0:
		take_damage(3.0 * delta)
	elif body_temperature > 39.0:
		take_damage(2.0 * delta)

func _update_stamina(delta: float) -> void:
	if current_stamina < max_stamina:
		var bonus_regen = 1.0 if hunger > 50.0 else 0.5
		current_stamina = min(max_stamina, current_stamina + stamina_regen_rate * bonus_regen * delta)
		stamina_changed.emit(current_stamina, max_stamina)

func use_stamina(amount: float) -> bool:
	if current_stamina >= amount:
		current_stamina -= amount
		stamina_changed.emit(current_stamina, max_stamina)
		return true
	return false

func take_damage(amount: float) -> void:
	current_health = max(0.0, current_health - amount)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		player_died.emit()
