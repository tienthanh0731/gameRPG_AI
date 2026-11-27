class_name CraftingCatalog
extends RefCounted

enum Category {
	TOOLS_WEAPONS,
	SURVIVAL_MED,
	DEFENSE_STRUCTURES
}

const RECIPES = [
	{
		"id": "iron_axe",
		"name": "Rìu Sắt Sắc Bén",
		"category": Category.TOOLS_WEAPONS,
		"desc": "Rìu tôi luyện bằng sắt hoang cổ. Đốn hạ cổ thụ nhanh x2 và nhận gấp đôi gỗ.",
		"cost": { "wood": 6, "iron": 4 },
		"icon_path": "res://assets/ui_icons/rpg_icons_32x32/axe_01a.png",
		"type": "tool_upgrade",
		"bonus_dmg": 20
	},
	{
		"id": "iron_pickaxe",
		"name": "Cuốc Thạch Kim",
		"category": Category.TOOLS_WEAPONS,
		"desc": "Cuốc nặng đào khoáng thạch. Đập đá nhanh gấp đôi và tăng tỉ lệ rơi quặng sắt.",
		"cost": { "wood": 6, "stone": 4, "iron": 4 },
		"icon_path": "res://assets/ui_icons/rpg_icons_32x32/pickaxe_01a.png",
		"type": "tool_upgrade",
		"bonus_dmg": 20
	},
	{
		"id": "iron_sword",
		"name": "Cổ Phong Trảm Mã Kiếm",
		"category": Category.TOOLS_WEAPONS,
		"desc": "Thanh kiếm rèn bằng thiết thạch và xương thú. Sát thương 35, quét sạch bầy dã thú.",
		"cost": { "wood": 8, "iron": 8, "bone": 4 },
		"icon_path": "res://assets/ui_icons/rpg_icons_32x32/sword_01a.png",
		"type": "weapon_upgrade",
		"bonus_dmg": 35
	},
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
