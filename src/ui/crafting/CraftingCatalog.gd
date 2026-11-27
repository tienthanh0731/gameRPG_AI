class_name CraftingCatalog
extends RefCounted
const EquipmentData = preload("res://src/data/EquipmentData.gd") # preload: không phụ thuộc cache class_name

enum Category {
	TOOLS_WEAPONS,
	SURVIVAL_MED,
	DEFENSE_STRUCTURES
}

const RECIPES = [
	{
		"id": "healing_salve",
		"name": "Đan Dược Trị Thương",
		"category": Category.SURVIVAL_MED,
		"desc": "Chiết xuất tinh hoa từ thịt rừng và tủy xương thú. Hồi phục ngay lập tức 45 Máu (HP).",
		"cost": { "meat": 2, "bone": 2 },
		"icon_path": "res://assets/ui_icons/rpg_icons_32x32/potion_01a.png",
		"type": "consumable",
		"heal_hp": 45.0
	},
	{
		"id": "rations",
		"name": "Lương Khô Hoang Cổ",
		"category": Category.SURVIVAL_MED,
		"desc": "Thịt sấy khô giữ ấm cơ thể. Hồi đầy 100% Thể Lực và sưởi ấm thân nhiệt lên 37°C.",
		"cost": { "meat": 3 },
		"icon_path": "res://assets/map/Resources/Meat/Meat Resource/Meat Resource.png",
		"type": "consumable",
		"restore_stamina": 100.0,
		"warmth": 37.0
	},
	{
		"id": "steel_spike",
		"name": "Bẫy Chông Thép",
		"category": Category.DEFENSE_STRUCTURES,
		"desc": "Bẫy ngầm gia cố bằng mũi tên sắt. Gây 35 sát thương và làm choáng dã thú giẫm qua.",
		"cost": { "wood": 4, "stone": 2, "iron": 4 },
		"icon_path": "res://assets/buildings/structures/spike_trap.png",
		"type": "structure_item",
		"struct_type": "spike"
	},
	{
		"id": "barricade",
		"name": "Hàng Rào Gai Thép",
		"category": Category.DEFENSE_STRUCTURES,
		"desc": "Chiến lũy kiên cố có gai sắt bảo vệ. Máu 140, chặn hoàn toàn đường lao của thú triều.",
		"cost": { "wood": 8, "iron": 4 },
		"icon_path": "res://assets/buildings/structures/wall_wood.png",
		"type": "structure_item",
		"struct_type": "wall"
	}
]


const TOOL_ICONS: Array[String] = [
	"res://assets/ui_icons/rpg_icons_32x32/axe_01a.png",
	"res://assets/ui_icons/rpg_icons_32x32/pickaxe_01a.png",
	"res://assets/ui_icons/rpg_icons_32x32/sword_01a.png",
]

## Toàn bộ công thức: công cụ/vũ khí theo bậc (sinh từ EquipmentData) + sửa chữa + RECIPES tĩnh.
static func get_recipes() -> Array:
	var out: Array = []
	for slot in 3:
		for tier in range(1, EquipmentData.MAX_TIER + 1):
			var st: Dictionary = EquipmentData.TIER_STATS[tier]
			out.append({
				"id": "%s_t%d" % [EquipmentData.SLOT_KEYS[slot], tier],
				"name": EquipmentData.item_name(slot, tier),
				"category": Category.TOOLS_WEAPONS,
				"desc": "Sức mạnh %d • vung %.2fs • độ bền %d • +%d sản lượng. Thay thế công cụ cùng loại bậc thấp hơn." % [
					st.power, st.swing, st.durability, st.bonus_yield],
				"cost": EquipmentData.craft_cost(slot, tier),
				"icon_path": TOOL_ICONS[slot],
				"type": "equipment",
				"slot": slot,
				"tier": tier,
			})
		out.append({
			"id": "repair_%s" % EquipmentData.SLOT_KEYS[slot],
			"name": "Sửa %s đang dùng" % EquipmentData.SLOT_NAMES[slot],
			"category": Category.TOOLS_WEAPONS,
			"desc": "Phục hồi đầy độ bền. Tốn 3 nguyên liệu theo bậc: Gỗ / Đá / Sắt.",
			"cost": {}, # tính động theo bậc hiện tại (CraftingUI._cost_of)
			"icon_path": TOOL_ICONS[slot],
			"type": "repair",
			"slot": slot,
		})
	out.append_array(RECIPES)
	return out
