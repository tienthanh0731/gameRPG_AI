extends Control

@onready var label_player_loc: Label = $Panel/VBox/HBox/RightPanel/LabelPlayerLoc
@onready var btn_warp_home: Button = $Panel/VBox/HBox/RightPanel/BtnWarpHome
@onready var btn_warp_outpost: Button = $Panel/VBox/HBox/RightPanel/BtnWarpOutpost
@onready var label_outpost_status: Label = $Panel/VBox/HBox/RightPanel/LabelOutpostStatus
@onready var btn_close: Button = $Panel/VBox/BtnClose

var player_node: CharacterBody2D
var campfire_node: Node2D
var outpost_node: Node2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	btn_close.pressed.connect(close_map)
	btn_warp_home.pressed.connect(_on_warp_home_pressed)
	btn_warp_outpost.pressed.connect(_on_warp_outpost_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_M:
			toggle_map()
		elif event.keycode == KEY_ESCAPE and visible:
			close_map()

func toggle_map() -> void:
	visible = not visible
	if visible:
		_refresh_map_data()

func close_map() -> void:
	visible = false

func _refresh_map_data() -> void:
	var root = get_tree().root
	player_node = get_tree().get_first_node_in_group("player") as CharacterBody2D
	campfire_node = root.find_child("Campfire", true, false)
	outpost_node = root.find_child("Outpost", true, false)
	
	if player_node:
		label_player_loc.text = "Tọa độ: (X: %d, Y: %d)" % [
			int(player_node.global_position.x), int(player_node.global_position.y)
		]
	else:
		label_player_loc.text = "Tọa độ: (X: 0, Y: 0)"
		
	# Check outpost capture state
	if outpost_node and outpost_node.get("state") == 2: # CAPTURED
		label_outpost_status.text = "Trạng thái: ĐÃ THU PHỤC (Sẵn sàng truyền tống)"
		label_outpost_status.modulate = Color(0.4, 1.0, 0.5)
		btn_warp_outpost.disabled = false
	else:
		label_outpost_status.text = "Trạng thái: Chưa thu phục (Hãy tới cắm cờ)"
		label_outpost_status.modulate = Color(1.0, 0.4, 0.4)
		btn_warp_outpost.disabled = true

func _on_warp_home_pressed() -> void:
	if player_node and campfire_node:
		player_node.global_position = campfire_node.global_position + Vector2(25, 0)
		close_map()

func _on_warp_outpost_pressed() -> void:
	if player_node and outpost_node:
		player_node.global_position = outpost_node.global_position + Vector2(25, 0)
		close_map()
