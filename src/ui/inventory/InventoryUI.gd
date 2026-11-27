extends CanvasLayer

signal inventory_toggled(is_open: bool)

const EquipmentData = preload("res://src/data/EquipmentData.gd")
const InventorySlotScene = preload("res://src/ui/inventory/InventorySlotUI.tscn")

const ITEM_META = {
	"wood": {
		"name": "Gỗ Rừng",
		"icon": "res://assets/ui_icons/rpg_icons_32x32/wood_01a.png",
		"tooltip": "Nguyên liệu cơ bản để chế tạo công cụ và xây dựng căn cứ."
	},
	"stone": {
		"name": "Đá Tảng",
		"icon": "res://assets/ui_icons/rpg_icons_32x32/stoneblock_01a.png",
		"tooltip": "Nguyên liệu nâng cấp tường đá và rèn công cụ bậc Đá."
	},
	"iron": {
		"name": "Quặng Sắt",
		"icon": "res://assets/ui_icons/rpg_icons_32x32/ingot_01a.png",
		"tooltip": "Kim loại cứng cáp gia cố pháo đài và đúc vũ khí bậc Sắt."
	},
	"meat": {
		"name": "Thịt Rừng",
		"icon": "res://assets/map/Resources/Meat/Meat Resource/Meat Resource.png",
		"tooltip": "Thịt tươi sống. Nhấn nút Ăn hoặc [Phím F] để hồi 30 No và 10 HP."
	},
	"bone": {
		"name": "Xương / Da Thú",
		"icon": "res://assets/ui_icons/rpg_icons_32x32/bone01a.png",
		"tooltip": "Chiến lợi phẩm từ quái vật, dùng để chế tạo kiếm và bẫy chông."
	},
	"reroll_pill": {
		"name": "Đan Reroll Thiên Phú",
		"icon": "res://assets/ui_icons/rpg_icons_32x32/potion_01a.png",
		"tooltip": "Bảo đan thần bí, dùng để tẩy và roll lại Thiên Phú."
	}
}

const TOOL_ICONS = {
	"axe": [
		"res://assets/ui_icons/tools/axe_wood.png",
		"res://assets/ui_icons/tools/axe_stone.png",
		"res://assets/ui_icons/tools/axe_iron.png"
	],
	"pickaxe": [
		"res://assets/ui_icons/tools/pickaxe_wood.png",
		"res://assets/ui_icons/tools/pickaxe_stone.png",
		"res://assets/ui_icons/tools/pickaxe_iron.png"
	],
	"sword": [
		"res://assets/ui_icons/tools/sword_wood.png",
		"res://assets/ui_icons/tools/sword_stone.png",
		"res://assets/ui_icons/tools/sword_iron.png"
	]
}

@onready var panel_root: Control = $Control
@onready var grid_container: GridContainer = $Control/Panel/MainHBox/RightVBox/GridContainer
@onready var btn_close: Button = $Control/Panel/HeaderHBox/CloseButton
@onready var btn_eat: Button = $Control/Panel/MainHBox/LeftVBox/EatButton

# Equipment Slot Nodes
@onready var axe_icon: TextureRect = $Control/Panel/MainHBox/LeftVBox/EquipCards/AxeCard/HBox/Icon
@onready var axe_name: Label = $Control/Panel/MainHBox/LeftVBox/EquipCards/AxeCard/HBox/VBox/Name
@onready var axe_bar: ProgressBar = $Control/Panel/MainHBox/LeftVBox/EquipCards/AxeCard/HBox/VBox/ProgressBar
@onready var axe_dur: Label = $Control/Panel/MainHBox/LeftVBox/EquipCards/AxeCard/HBox/VBox/DurabilityLabel

@onready var pick_icon: TextureRect = $Control/Panel/MainHBox/LeftVBox/EquipCards/PickaxeCard/HBox/Icon
@onready var pick_name: Label = $Control/Panel/MainHBox/LeftVBox/EquipCards/PickaxeCard/HBox/VBox/Name
@onready var pick_bar: ProgressBar = $Control/Panel/MainHBox/LeftVBox/EquipCards/PickaxeCard/HBox/VBox/ProgressBar
@onready var pick_dur: Label = $Control/Panel/MainHBox/LeftVBox/EquipCards/PickaxeCard/HBox/VBox/DurabilityLabel

@onready var sword_icon: TextureRect = $Control/Panel/MainHBox/LeftVBox/EquipCards/SwordCard/HBox/Icon
@onready var sword_name: Label = $Control/Panel/MainHBox/LeftVBox/EquipCards/SwordCard/HBox/VBox/Name
@onready var sword_bar: ProgressBar = $Control/Panel/MainHBox/LeftVBox/EquipCards/SwordCard/HBox/VBox/ProgressBar
@onready var sword_dur: Label = $Control/Panel/MainHBox/LeftVBox/EquipCards/SwordCard/HBox/VBox/DurabilityLabel

var player: CharacterBody2D = null
var inventory: Node = null

# Thứ tự ô hiển thị trong giao diện (16 ô)
var slot_order: Array[String] = [
	"wood", "stone", "iron", "meat",
	"bone", "reroll_pill", "", "",
	"", "", "", "",
	"", "", "", ""
]
var slot_nodes: Array[Node] = []
var _loaded_textures: Dictionary = {}

func _ready() -> void:
	visible = false
	if btn_close:
		btn_close.pressed.connect(close_inventory)
	if btn_eat:
		btn_eat.pressed.connect(_on_eat_pressed)
		
	_create_grid_slots()
	_ensure_references()

func _ensure_references() -> void:
	if not is_instance_valid(player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0] as CharacterBody2D
			if player:
				inventory = player.get_node_or_null("Inventory")
				if player.has_signal("equipment_changed"):
					if not player.equipment_changed.is_connected(_on_equipment_changed):
						player.equipment_changed.connect(_on_equipment_changed)
				if inventory and inventory.has_signal("inventory_updated"):
					if not inventory.inventory_updated.is_connected(_on_inventory_updated):
						inventory.inventory_updated.connect(_on_inventory_updated)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_TAB:
			toggle_inventory()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and visible:
			close_inventory()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F and visible:
			_on_eat_pressed()
			get_viewport().set_input_as_handled()

func toggle_inventory() -> void:
	if visible:
		close_inventory()
	else:
		open_inventory()

func open_inventory() -> void:
	_ensure_references()
	_refresh_all()
	visible = true
	inventory_toggled.emit(true)

func close_inventory() -> void:
	visible = false
	inventory_toggled.emit(false)

func _create_grid_slots() -> void:
	if not grid_container: return
	for child in grid_container.get_children():
		child.queue_free()
	slot_nodes.clear()
	
	for i in range(16):
		var slot_inst = InventorySlotScene.instantiate()
		grid_container.add_child(slot_inst)
		slot_inst.slot_drag_swapped.connect(_on_slot_drag_swapped)
		slot_nodes.append(slot_inst)

func _get_tex(path: String) -> Texture2D:
	if _loaded_textures.has(path):
		return _loaded_textures[path]
	if ResourceLoader.exists(path):
		var t = load(path)
		_loaded_textures[path] = t
		return t
	var gp = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(gp) or FileAccess.file_exists(path):
		var img = Image.load_from_file(gp if FileAccess.file_exists(gp) else path)
		if img and not img.is_empty():
			var itex = ImageTexture.create_from_image(img)
			_loaded_textures[path] = itex
			return itex
	return null

func _refresh_all() -> void:
	_refresh_grid()
	_refresh_equipment()
	_refresh_eat_button()

func _refresh_grid() -> void:
	_ensure_references()
	var inv_dict: Dictionary = {}
	if inventory and inventory.has_method("get_inventory_dict"):
		inv_dict = inventory.get_inventory_dict()
		
	for i in range(slot_nodes.size()):
		var slot_node = slot_nodes[i]
		var key = slot_order[i] if i < slot_order.size() else ""
		var amount = int(inv_dict.get(key, 0)) if not key.is_empty() else 0
		
		if not key.is_empty() and ITEM_META.has(key):
			var meta = ITEM_META[key]
			var tex = _get_tex(meta["icon"])
			slot_node.setup(i, key, amount, tex, meta["name"], meta["tooltip"])
		else:
			slot_node.setup(i, "", 0, null, "", "")

func _refresh_equipment() -> void:
	_ensure_references()
	var equip = player.get("equipment") if player else {}
	if not equip or not (equip is Dictionary):
		equip = EquipmentData.default_loadout()
		
	# 1. AXE (Slot 0)
	var axe_item = equip.get("axe", { "tier": 0, "durability": 40 })
	_update_tool_card(0, "axe", axe_item, axe_icon, axe_name, axe_bar, axe_dur)
	
	# 2. PICKAXE (Slot 1)
	var pick_item = equip.get("pickaxe", { "tier": 0, "durability": 40 })
	_update_tool_card(1, "pickaxe", pick_item, pick_icon, pick_name, pick_bar, pick_dur)
	
	# 3. SWORD (Slot 2)
	var sword_item = equip.get("sword", { "tier": 0, "durability": 40 })
	_update_tool_card(2, "sword", sword_item, sword_icon, sword_name, sword_bar, sword_dur)

func _update_tool_card(slot: int, slot_key: String, item: Dictionary, icon_node: TextureRect, name_node: Label, bar_node: ProgressBar, dur_node: Label) -> void:
	var tier = clampi(int(item.get("tier", 0)), 0, EquipmentData.MAX_TIER)
	var cur_dur = maxi(0, int(item.get("durability", 0)))
	var max_dur = EquipmentData.max_durability(tier)
	
	# Icon
	if icon_node and TOOL_ICONS.has(slot_key):
		var p = TOOL_ICONS[slot_key][tier]
		icon_node.texture = _get_tex(p)
		
	# Name
	if name_node:
		name_node.text = EquipmentData.item_name(slot, tier)
		match tier:
			0: name_node.modulate = Color(0.9, 0.8, 0.6) # Gỗ
			1: name_node.modulate = Color(0.8, 0.9, 1.0) # Đá
			2: name_node.modulate = Color(0.95, 0.85, 0.3) # Sắt
			
	# Durability bar & label
	if bar_node:
		bar_node.max_value = max_dur
		bar_node.value = cur_dur
		
	if dur_node:
		if cur_dur <= 0:
			dur_node.text = "💥 GÃY (Cần sửa ở Bàn Chế Tạo)"
			dur_node.modulate = Color(1.0, 0.3, 0.25)
		else:
			dur_node.text = "Độ bền: %d / %d" % [cur_dur, max_dur]
			var ratio = float(cur_dur) / float(max(1, max_dur))
			if ratio > 0.5:
				dur_node.modulate = Color(0.4, 0.95, 0.4)
			elif ratio > 0.25:
				dur_node.modulate = Color(1.0, 0.75, 0.2)
			else:
				dur_node.modulate = Color(1.0, 0.35, 0.3)

func _refresh_eat_button() -> void:
	_ensure_references()
	var meat_count = 0
	if inventory and inventory.has_method("get_inventory_dict"):
		meat_count = int(inventory.get_inventory_dict().get("meat", 0))
		
	if btn_eat:
		btn_eat.text = "🍖 Ăn Thịt Hồi Phục [F] (Còn: %d)" % meat_count
		btn_eat.disabled = (meat_count <= 0)

func _on_slot_drag_swapped(from_idx: int, to_idx: int) -> void:
	if from_idx < 0 or from_idx >= slot_order.size() or to_idx < 0 or to_idx >= slot_order.size():
		return
	var temp = slot_order[from_idx]
	slot_order[from_idx] = slot_order[to_idx]
	slot_order[to_idx] = temp
	_refresh_grid()

func _on_eat_pressed() -> void:
	_ensure_references()
	if player and player.has_method("_try_eat"):
		player._try_eat()
		_refresh_all()

func _on_equipment_changed(_equip: Dictionary, _tool_idx: int) -> void:
	if visible:
		_refresh_equipment()

func _on_inventory_updated(_inv_dict: Dictionary) -> void:
	if visible:
		_refresh_grid()
		_refresh_eat_button()
