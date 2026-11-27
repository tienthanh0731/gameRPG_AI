extends PanelContainer

@export var radar_radius: float = 650.0
@export var map_display_size: float = 60.0

var player_node: Node2D
var campfire_node: Node2D
var dungeon_node: Node2D

func _ready() -> void:
	custom_minimum_size = Vector2(130, 130)

func _process(_delta: float) -> void:
	if not player_node:
		var p = get_tree().get_first_node_in_group("player")
		if p: player_node = p
	if not campfire_node:
		var root = get_tree().root
		campfire_node = root.find_child("Campfire", true, false)
	if not dungeon_node:
		var root = get_tree().root
		dungeon_node = root.find_child("DungeonEntrance", true, false)
		
	queue_redraw()

func _draw() -> void:
	var center = size * 0.5
	var r = min(center.x, center.y) - 4.0
	
	# Radar background & boundary
	draw_circle(center, r, Color(0.06, 0.08, 0.12, 0.85))
	draw_arc(center, r, 0, TAU, 32, Color(0.3, 0.5, 0.7, 0.8), 1.5)
	
	if not player_node:
		return
		
	var player_pos = player_node.global_position
	
	# Draw Campfire (Yellow/Orange)
	if campfire_node:
		var off = (campfire_node.global_position - player_pos) / radar_radius * r
		if off.length() <= r:
			draw_circle(center + off, 4.0, Color(1.0, 0.7, 0.2))
			
	# Draw Dungeon (Purple/Cyan)
	if dungeon_node:
		var off = (dungeon_node.global_position - player_pos) / radar_radius * r
		if off.length() <= r:
			draw_circle(center + off, 4.5, Color(0.7, 0.3, 1.0))
			
	# Draw nearby enemies (Red)
	var enemies = get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		if is_instance_valid(e) and e is Node2D:
			var off = (e.global_position - player_pos) / radar_radius * r
			if off.length() <= r:
				draw_circle(center + off, 2.5, Color(1.0, 0.25, 0.25))
				
	# Draw Player (Bright Green)
	draw_circle(center, 3.5, Color(0.3, 1.0, 0.4))
