extends PanelContainer

signal slot_drag_swapped(from_index: int, to_index: int)
signal slot_clicked(slot_index: int, item_key: String)

@export var slot_index: int = 0
var item_key: String = ""
var item_amount: int = 0
var item_name_str: String = ""

@onready var icon_rect: TextureRect = $Margin/VBox/Icon
@onready var count_label: Label = $Margin/VBox/Count

func _ready() -> void:
	custom_minimum_size = Vector2(58, 58)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func setup(p_index: int, p_key: String, p_amount: int, p_tex: Texture2D, p_display_name: String, p_tooltip: String = "") -> void:
	slot_index = p_index
	item_key = p_key
	item_amount = p_amount
	item_name_str = p_display_name
	
	if not count_label or not icon_rect:
		return
		
	if item_amount > 0 and p_tex:
		icon_rect.texture = p_tex
		icon_rect.visible = true
		count_label.text = str(item_amount)
		count_label.visible = true
		tooltip_text = "%s (Số lượng: %d)\n%s" % [p_display_name, item_amount, p_tooltip]
	else:
		icon_rect.texture = null
		icon_rect.visible = false
		count_label.text = ""
		count_label.visible = false
		tooltip_text = "Ô trống (Kéo thả để sắp xếp)"

func _get_drag_data(_at_position: Vector2) -> Variant:
	if item_amount <= 0 or item_key.is_empty():
		return null
		
	var preview = Control.new()
	var prev_icon = TextureRect.new()
	prev_icon.texture = icon_rect.texture
	prev_icon.custom_minimum_size = Vector2(40, 40)
	prev_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	prev_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	prev_icon.position = Vector2(-20, -20)
	preview.add_child(prev_icon)
	
	set_drag_preview(preview)
	
	return {
		"type": "inventory_slot",
		"from_index": slot_index,
		"item_key": item_key
	}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data is Dictionary and data.get("type") == "inventory_slot":
		return true
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary and data.get("type") == "inventory_slot":
		var from_idx = int(data.get("from_index", -1))
		if from_idx != -1 and from_idx != slot_index:
			slot_drag_swapped.emit(from_idx, slot_index)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		slot_clicked.emit(slot_index, item_key)

func _on_mouse_entered() -> void:
	modulate = Color(1.15, 1.15, 1.15, 1.0)

func _on_mouse_exited() -> void:
	modulate = Color.WHITE
