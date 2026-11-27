extends Node

signal resources_updated(wood: int, stone: int, iron: int)
signal inventory_updated(inv_data: Dictionary)
signal item_collected(item_name: String, amount: int)

@export var wood: int = 0
@export var stone: int = 0
@export var iron: int = 0
@export var meat: int = 0
@export var bone: int = 0
@export var reroll_pill: int = 0

func add_resource(item_name: String, amount: int) -> void:
	var key := ""
	match item_name:
		"Gỗ", "Wood", "gỗ":
			wood += amount
			key = "wood"
		"Đá", "Stone", "đá":
			stone += amount
			key = "stone"
		"Quặng Sắt", "Sắt", "Iron", "quặng sắt", "sắt":
			iron += amount
			key = "iron"
		"Thịt Rừng", "Thịt", "Meat", "thịt rừng":
			meat += amount
			key = "meat"
		"Xương Thú", "Da Thú", "Xương", "Da", "Bone", "xương thú":
			bone += amount
			key = "bone"
		"Đan Reroll Thiên Phú", "Đan Reroll", "Reroll Pill", "đan reroll":
			reroll_pill += amount
			key = "reroll_pill"
		_:
			push_warning("Inventory: vật phẩm không xác định '%s'" % item_name)
			return
	_emit_and_sync()
	item_collected.emit(item_name, amount)
	# Thu thập thật (không tính rương thưởng) → nhiệm vụ ngày
	if amount > 0 and not GameState.granting_rewards:
		EventBus.resource_gathered.emit(key, amount)

func _emit_and_sync() -> void:
	var inv_dict := get_inventory_dict()
	resources_updated.emit(wood, stone, iron)
	inventory_updated.emit(inv_dict)
	# Đồng bộ ngay vào dữ liệu nhân vật (không cho phép khi nhân vật đã chết)
	if SaveSystem and SaveSystem.has_active_character():
		SaveSystem.character_data["inventory"] = inv_dict
		SaveSystem.save_character(SaveSystem.character_data)

func get_inventory_dict() -> Dictionary:
	return { "wood": wood, "stone": stone, "iron": iron, "meat": meat, "bone": bone, "reroll_pill": reroll_pill }

func load_inventory_dict(d: Dictionary) -> void:
	wood = int(d.get("wood", 0))
	stone = int(d.get("stone", 0))
	iron = int(d.get("iron", 0))
	meat = int(d.get("meat", 0))
	bone = int(d.get("bone", 0))
	# "reroll_pills" là key cũ của bản trên main → vẫn đọc được
	reroll_pill = int(d.get("reroll_pill", d.get("reroll_pills", 0)))
	resources_updated.emit(wood, stone, iron)
	inventory_updated.emit(get_inventory_dict())

## Tên gọi dùng bởi GameState (giữ đồng nghĩa với get/load_inventory_dict).
func to_dict() -> Dictionary:
	return get_inventory_dict()

func from_dict(d: Dictionary) -> void:
	load_inventory_dict(d)

func has_resources(req_wood: int, req_stone: int, req_iron: int = 0) -> bool:
	return wood >= req_wood and stone >= req_stone and iron >= req_iron

func consume_resources(req_wood: int, req_stone: int, req_iron: int = 0) -> bool:
	if not has_resources(req_wood, req_stone, req_iron):
		return false
	wood -= req_wood
	stone -= req_stone
	iron -= req_iron
	_emit_and_sync()
	return true

func consume_meat() -> bool:
	if meat <= 0:
		return false
	meat -= 1
	_emit_and_sync()
	item_collected.emit("Thịt Rừng", -1)
	return true
