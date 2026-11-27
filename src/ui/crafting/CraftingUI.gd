extends Control

const CraftingCatalog = preload("res://src/ui/crafting/CraftingCatalog.gd")

@onready var tab_bar: TabBar = $Panel/VBox/HBox/LeftCol/TabBar
@onready var item_list: ItemList = $Panel/VBox/HBox/LeftCol/ItemList
@onready var label_detail_name: Label = $Panel/VBox/HBox/RightCol/LabelDetailName
@onready var label_detail_desc: Label = $Panel/VBox/HBox/RightCol/LabelDetailDesc
@onready var label_detail_cost: Label = $Panel/VBox/HBox/RightCol/LabelDetailCost
@onready var btn_craft: Button = $Panel/VBox/HBox/RightCol/BtnCraft
@onready var btn_close: Button = $Panel/VBox/BtnClose

var current_category: int = 0
var filtered_recipes: Array = []
var selected_recipe: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	btn_close.pressed.connect(close_ui)
	btn_craft.pressed.connect(_on_btn_craft_pressed)
	tab_bar.tab_changed.connect(_on_tab_changed)
	item_list.item_selected.connect(_on_recipe_selected)
	_load_category(0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_I or event.keycode == KEY_TAB:
			toggle_ui()
		elif event.keycode == KEY_ESCAPE and visible:
			close_ui()

func toggle_ui() -> void:
	visible = not visible
	if visible:
		_load_category(current_category)

func close_ui() -> void:
	visible = false

func _on_tab_changed(idx: int) -> void:
	current_category = idx
	_load_category(idx)

func _load_category(cat_idx: int) -> void:
	item_list.clear()
	filtered_recipes.clear()
	
	var player = get_tree().get_first_node_in_group("player")
	var inv: Node = player.get_node_or_null("Inventory") if player else null
	
	for r in CraftingCatalog.RECIPES:
		if r.category == cat_idx:
			filtered_recipes.append(r)
			var can_afford = _check_afford(r.cost, inv)
			var prefix = "✓ " if can_afford else "✗ "
			var idx = item_list.add_item(prefix + r.name)
			if can_afford:
				item_list.set_item_custom_fg_color(idx, Color(0.4, 1.0, 0.5))
			else:
				item_list.set_item_custom_fg_color(idx, Color(0.7, 0.7, 0.7, 0.6))
				
	if not filtered_recipes.is_empty():
		item_list.select(0)
		_on_recipe_selected(0)
	else:
		_clear_details()

func _on_recipe_selected(index: int) -> void:
	if index < 0 or index >= filtered_recipes.size():
		return
	selected_recipe = filtered_recipes[index]
	
	var player = get_tree().get_first_node_in_group("player")
	var inv: Node = player.get_node_or_null("Inventory") if player else null
	var can_afford = _check_afford(selected_recipe.cost, inv)
	
	label_detail_name.text = selected_recipe.name
	label_detail_desc.text = selected_recipe.desc
	
	# Build required cost text
	var cost_text = "Nguyên liệu yêu cầu:\n"
	for mat in selected_recipe.cost.keys():
		var req = selected_recipe.cost[mat]
		var cur = _get_inv_val(mat, inv)
		var mat_name = _get_mat_display_name(mat)
		var status = "✓" if cur >= req else "✗"
		cost_text += " • %s: %d / %d [%s]\n" % [mat_name, cur, req, status]
		
	label_detail_cost.text = cost_text
	if can_afford:
		label_detail_cost.modulate = Color(0.4, 1.0, 0.5)
		btn_craft.disabled = false
		btn_craft.text = "✦ CHẾ TẠO ✦"
	else:
		label_detail_cost.modulate = Color(1.0, 0.4, 0.4)
		btn_craft.disabled = true
		btn_craft.text = "THIẾU NGUYÊN LIỆU"

func _check_afford(cost: Dictionary, inv: Node) -> bool:
	if not inv: return false
	for mat in cost.keys():
		if _get_inv_val(mat, inv) < cost[mat]:
			return false
	return true

func _get_inv_val(mat: String, inv: Node) -> int:
	if not inv: return 0
	match mat:
		"wood": return inv.wood
		"stone": return inv.stone
		"iron": return inv.iron
		"meat": return inv.meat
		"bone": return inv.bone
	return 0

func _get_mat_display_name(mat: String) -> String:
	match mat:
		"wood": return "Gỗ"
		"stone": return "Đá"
		"iron": return "Quặng Sắt"
		"meat": return "Thịt Rừng"
		"bone": return "Xương / Da Thú"
	return mat

func _clear_details() -> void:
	label_detail_name.text = "Chọn công thức chế tạo"
	label_detail_desc.text = ""
	label_detail_cost.text = ""
	btn_craft.disabled = true

func _on_btn_craft_pressed() -> void:
	if selected_recipe.is_empty(): return
	var player = get_tree().get_first_node_in_group("player")
	if not player: return
	var inv = player.get_node_or_null("Inventory")
	var stats = player.get_node_or_null("SurvivalStats")
	if not inv or not _check_afford(selected_recipe.cost, inv): return
	
	# 1. Deduct cost
	for mat in selected_recipe.cost.keys():
		var amt = selected_recipe.cost[mat]
		match mat:
			"wood": inv.wood -= amt
			"stone": inv.stone -= amt
			"iron": inv.iron -= amt
			"meat": inv.meat -= amt
			"bone": inv.bone -= amt
	inv.inventory_updated.emit(inv.get_inventory_dict())
	
	# 2. Apply crafted effect
	match selected_recipe.type:
		"consumable":
			if stats:
				if selected_recipe.has("heal_hp"):
					stats.current_health = min(stats.current_health + selected_recipe["heal_hp"], stats.max_health)
					stats.health_changed.emit(stats.current_health, stats.max_health)
				if selected_recipe.has("restore_stamina"):
					stats.current_stamina = stats.max_stamina
					stats.stamina_changed.emit(stats.current_stamina, stats.max_stamina)
				if selected_recipe.has("warmth"):
					stats.body_temperature = 37.0
					stats.temperature_changed.emit(37.0)
		"tool_upgrade", "weapon_upgrade":
			# Boost player's attack or gathering
			pass
		"structure_item":
			inv.wood += 2
			inv.stone += 1
			
	# Award SP & Refresh UI
	# Đặc tả §6 không có SP cho chế tạo → không cộng SP ở đây.
		
	_load_category(current_category)
