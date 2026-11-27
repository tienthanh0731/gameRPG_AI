extends Node

signal resources_updated(wood: int, stone: int, iron: int)
signal inventory_updated(inv_data: Dictionary)
signal item_collected(item_name: String, amount: int)

@export var wood: int = 0
@export var stone: int = 0
@export var iron: int = 0
@export var meat: int = 0
@export var bone: int = 0
@export var reroll_pills: int = 0

func add_resource(item_name: String, amount: int) -> void:
	match item_name:
		"Gỗ", "Wood", "gỗ":
			wood += amount
		"Đá", "Stone", "đá":
			stone += amount
		"Quặng Sắt", "Sắt", "Iron", "quặng sắt", "sắt":
			iron += amount
		"Thịt Rừng", "Thịt", "Meat", "thịt rừng":
			meat += amount
		"Xương Thú", "Da Thú", "Xương", "Da", "Bone", "xương thú":
			bone += amount
		"Đan Reroll Thiên Phú", "Đan Reroll", "Reroll Pill", "đan reroll":
			reroll_pills += amount
		_:
			# Default fallback
			wood += amount
			
	var inv_dict = get_inventory_dict()
	resources_updated.emit(wood, stone, iron)
	inventory_updated.emit(inv_dict)
	item_collected.emit(item_name, amount)
	
	# Auto-sync with character save data
	if SaveSystem and SaveSystem.has_active_character():
		SaveSystem.character_data["inventory"] = inv_dict
		SaveSystem.save_character(SaveSystem.character_data)

func get_inventory_dict() -> Dictionary:
	return {
		"wood": wood,
		"stone": stone,
		"iron": iron,
		"meat": meat,
		"bone": bone,
		"reroll_pills": reroll_pills
	}

func load_inventory_dict(dict: Dictionary) -> void:
	wood = dict.get("wood", 0)
	stone = dict.get("stone", 0)
	iron = dict.get("iron", 0)
	meat = dict.get("meat", 0)
	bone = dict.get("bone", 0)
	reroll_pills = dict.get("reroll_pills", 0)
	resources_updated.emit(wood, stone, iron)
	inventory_updated.emit(get_inventory_dict())

func has_resources(req_wood: int, req_stone: int, req_iron: int = 0) -> bool:
	return wood >= req_wood and stone >= req_stone and iron >= req_iron

func consume_resources(req_wood: int, req_stone: int, req_iron: int = 0) -> bool:
	if not has_resources(req_wood, req_stone, req_iron):
		return false
	wood -= req_wood
	stone -= req_stone
	iron -= req_iron
	var inv_dict = get_inventory_dict()
	resources_updated.emit(wood, stone, iron)
	inventory_updated.emit(inv_dict)
	
	if SaveSystem and SaveSystem.has_active_character():
		SaveSystem.character_data["inventory"] = inv_dict
		SaveSystem.save_character(SaveSystem.character_data)
		
	return true
