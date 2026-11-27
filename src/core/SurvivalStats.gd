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
@export var hunger_decay_rate: float = 0.1

@export var thirst: float = 100.0
@export var thirst_decay_rate: float = 0.15

@export var body_temperature: float = 37.0
@export var target_temperature: float = 37.0

var is_near_fire: bool = false
var regen_per_sec: float = 0.0 # từ Thiên Phú
var damage_reduction: float = 0.0 # từ Thiên Phú, chỉ áp cho đòn quái
var is_dead: bool = false

func _ready() -> void:
	current_health = max_health
	current_stamina = max_stamina
	body_temperature = 37.0
	target_temperature = 37.0
	health_changed.emit(current_health, max_health)
	stamina_changed.emit(current_stamina, max_stamina)
	temperature_changed.emit(body_temperature)

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
	elif current_health < max_health and hunger > 50.0 and thirst > 50.0 and body_temperature >= 35.0:
		# Passive health recovery when well-fed and warm
		current_health = min(max_health, current_health + (1.2 + regen_per_sec) * delta)
		health_changed.emit(current_health, max_health)
	elif regen_per_sec > 0.0 and current_health < max_health and not is_dead:
		current_health = min(max_health, current_health + regen_per_sec * delta)
		health_changed.emit(current_health, max_health)

func _update_temperature(delta: float) -> void:
	var rate = 1.2 if is_near_fire else 0.05
	body_temperature = move_toward(body_temperature, target_temperature, rate * delta)
	temperature_changed.emit(body_temperature)
	
	if body_temperature < 30.0:
		take_damage(1.5 * delta)
	elif body_temperature > 39.5:
		take_damage(1.5 * delta)

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
	if is_dead:
		return
	current_health = max(0.0, current_health - amount)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		is_dead = true
		player_died.emit() # chỉ bắn 1 lần

## Sát thương từ quái: áp giảm sát thương của Thiên Phú.
func take_monster_damage(amount: float) -> void:
	take_damage(amount * (1.0 - clampf(damage_reduction, 0.0, 0.9)))

func eat(hunger_amount: float, heal_amount: float) -> void:
	hunger = min(100.0, hunger + hunger_amount)
	heal(heal_amount)
	hunger_changed.emit(hunger)

func heal(amount: float) -> void:
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)

func respawn() -> void:
	current_health = max_health
	current_stamina = max_stamina
	body_temperature = 37.0
	target_temperature = 37.0
	hunger = 90.0
	thirst = 90.0
	health_changed.emit(current_health, max_health)
	stamina_changed.emit(current_stamina, max_stamina)
	temperature_changed.emit(body_temperature)
