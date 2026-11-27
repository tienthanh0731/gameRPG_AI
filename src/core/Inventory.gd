extends Node

signal resources_updated(wood: int, stone: int, iron: int)
signal item_collected(item_name: String, amount: int)

@export var wood: int = 0
@export var stone: int = 0
@export var iron: int = 0
@export var meat: int = 0
@export var bone: int = 0
@export var reroll_pill: int = 0

func add_resource(item_name: String, amount: int) -> void:
	match item_name:
		"Gỗ":
			wood += amount
		"Đá":
			stone += amount
		"Quặng Sắt":
			iron += amount
		"Thịt Rừng":
			meat += amount
		"Xương Thú", "Da Thú":
			bone += amount
		"Đan Reroll Thiên Phú":
			reroll_pill += amount
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

func to_dict() -> Dictionary:
	return { "wood": wood, "stone": stone, "iron": iron, "meat": meat, "bone": bone, "reroll_pill": reroll_pill }

func from_dict(d: Dictionary) -> void:
	wood = int(d.get("wood", 0))
	stone = int(d.get("stone", 0))
	iron = int(d.get("iron", 0))
	meat = int(d.get("meat", 0))
	bone = int(d.get("bone", 0))
	reroll_pill = int(d.get("reroll_pill", 0))
	resources_updated.emit(wood, stone, iron)

func consume_meat() -> bool:
	if meat <= 0:
		return false
	meat -= 1
	item_collected.emit("Thịt Rừng", -1)
	return true
