extends Node

signal resources_updated(wood: int, stone: int, iron: int)
signal item_collected(item_name: String, amount: int)

@export var wood: int = 0
@export var stone: int = 0
@export var iron: int = 0

func add_resource(item_name: String, amount: int) -> void:
	match item_name:
		"Gỗ":
			wood += amount
		"Đá":
			stone += amount
		"Quặng Sắt":
			iron += amount
	resources_updated.emit(wood, stone, iron)
	item_collected.emit(item_name, amount)

func has_resources(req_wood: int, req_stone: int, req_iron: int = 0) -> bool:
	return wood >= req_wood and stone >= req_stone and iron >= req_iron

func consume_resources(req_wood: int, req_stone: int, req_iron: int = 0) -> bool:
	if not has_resources(req_wood, req_stone, req_iron):
		return false
	wood -= req_wood
	stone -= req_stone
	iron -= req_iron
	resources_updated.emit(wood, stone, iron)
	return true
