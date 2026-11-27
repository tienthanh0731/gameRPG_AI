extends Node2D

signal biome_changed(biome_name: String, ambient_temp: float)
signal player_spawn_found(spawn_pos: Vector2)
signal resource_dropped(item_name: String, amount: int, pos: Vector2)

const TreePropScript = preload("res://src/world/TreeProp.gd")
const RockPropScript = preload("res://src/world/RockProp.gd")

enum BiomeType {
	OCEAN,
	RIVER,
	BEACH,
	FOREST,
	SWAMP,
	MOUNTAIN,
	SNOW_TUNDRA
}

@export var map_width: int = 80
@export var map_height: int = 80
@export var tile_size: int = 64
@export var map_seed: int = 0

var elevation_noise: FastNoiseLite
var moisture_noise: FastNoiseLite
var foliage_noise: FastNoiseLite

@onready var terrain_layer: Node2D = $TerrainTiles
@onready var props_layer: Node2D = $PropsLayer

var tex_water: Texture2D
var tex_sand: Texture2D
var tex_grass: Texture2D
var tex_stone: Texture2D
var tex_snow: Texture2D
var tex_swamp: Texture2D

var tex_trees: Array[Texture2D] = []
var tex_stumps: Array[Texture2D] = []
var tex_rocks: Array[Texture2D] = []
var tex_bushes: Array[Texture2D] = []

var spawn_location: Vector2 = Vector2.ZERO
var current_player_biome: BiomeType = BiomeType.FOREST

func _ready() -> void:
	if terrain_layer:
		terrain_layer.z_index = -10
		terrain_layer.z_as_relative = false
	if props_layer:
		props_layer.y_sort_enabled = true
	_init_textures()
	_init_noises()
	generate_world()

func _init_textures() -> void:
	tex_grass = load("res://assets/map/tiles/tile_grass.png")
	tex_stone = load("res://assets/map/tiles/tile_stone.png")
	tex_sand = load("res://assets/map/tiles/tile_sand.png")
	tex_water = load("res://assets/map/tiles/tile_water.png")
	tex_snow = load("res://assets/map/tiles/tile_snow.png")
	tex_swamp = load("res://assets/map/tiles/tile_swamp.png")

	# Load Trees
	for i in range(1, 5):
		var tree_path = "res://assets/raw_packs/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Resources/Wood/Trees/Tree%d.png" % i
		if ResourceLoader.exists(tree_path):
			tex_trees.append(load(tree_path))

	# Load Stumps
	for i in range(1, 5):
		var stump_path = "res://assets/map/Resources/Wood/Trees/Stump %d.png" % i
		if ResourceLoader.exists(stump_path):
			tex_stumps.append(load(stump_path))

	# Load Rocks
	for i in range(1, 5):
		var rock_path = "res://assets/raw_packs/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Decorations/Rocks/Rock%d.png" % i
		if ResourceLoader.exists(rock_path):
			tex_rocks.append(load(rock_path))

	# Load Bushes
	for i in range(1, 5):
		var bush_path = "res://assets/map/Decorations/Bushes/Bushe%d.png" % i
		if ResourceLoader.exists(bush_path):
			tex_bushes.append(load(bush_path))

func _init_noises() -> void:
	if map_seed == 0:
		randomize()
		map_seed = randi()

	elevation_noise = FastNoiseLite.new()
	elevation_noise.seed = map_seed
	elevation_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	elevation_noise.frequency = 0.03

	moisture_noise = FastNoiseLite.new()
	moisture_noise.seed = map_seed + 101
	moisture_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	moisture_noise.frequency = 0.025

	foliage_noise = FastNoiseLite.new()
	foliage_noise.seed = map_seed + 202
	foliage_noise.frequency = 0.09

func generate_world() -> void:
	for child in terrain_layer.get_children():
		child.queue_free()
	for child in props_layer.get_children():
		child.queue_free()

	var half_w = map_width / 2
	var half_h = map_height / 2

	# Step 1: Find safe player spawn on land
	var valid_spawn_points: Array[Vector2] = []
	for x in range(-half_w + 10, half_w - 10):
		for y in range(-half_h + 10, half_h - 10):
			var biome = get_biome_at(x, y)
			if biome == BiomeType.FOREST or biome == BiomeType.BEACH:
				var world_p = Vector2(x * tile_size, y * tile_size)
				if world_p.distance_to(Vector2.ZERO) < 500.0:
					valid_spawn_points.append(world_p)

	if valid_spawn_points.size() > 0:
		spawn_location = valid_spawn_points[randi() % valid_spawn_points.size()]
	else:
		spawn_location = Vector2.ZERO

	# Step 2: Build terrain and spaced props
	for x in range(-half_w, half_w):
		for y in range(-half_h, half_h):
			var world_pos = Vector2(x * tile_size, y * tile_size)
			var biome = get_biome_at(x, y)
			
			_create_tile_sprite(world_pos, biome)
			
			# Leave a clear 220px radius around player spawn
			if world_pos.distance_to(spawn_location) > 220.0:
				_spawn_props_at(world_pos, biome, x, y)

	player_spawn_found.emit(spawn_location)

func get_biome_at(grid_x: int, grid_y: int) -> BiomeType:
	var elev = elevation_noise.get_noise_2d(grid_x, grid_y)
	var moisture = moisture_noise.get_noise_2d(grid_x, grid_y)

	if elev < -0.32:
		return BiomeType.OCEAN
	elif elev < -0.16:
		return BiomeType.RIVER
	elif elev < -0.06:
		return BiomeType.BEACH

	if moisture < -0.22:
		return BiomeType.SNOW_TUNDRA
	elif moisture > 0.32 and elev < 0.2:
		return BiomeType.SWAMP
	elif elev > 0.38:
		return BiomeType.MOUNTAIN
	else:
		return BiomeType.FOREST

func _create_tile_sprite(pos: Vector2, biome: BiomeType) -> void:
	var sprite = Sprite2D.new()
	sprite.position = pos
	sprite.centered = true
	sprite.z_index = -10
	sprite.z_as_relative = false

	match biome:
		BiomeType.OCEAN:
			sprite.texture = tex_water
			sprite.modulate = Color(0.35, 0.55, 0.95)
		BiomeType.RIVER:
			sprite.texture = tex_water
			sprite.modulate = Color(0.55, 0.75, 1.0)
		BiomeType.BEACH:
			sprite.texture = tex_sand
			sprite.modulate = Color.WHITE
		BiomeType.FOREST:
			sprite.texture = tex_grass
			sprite.modulate = Color.WHITE
		BiomeType.SWAMP:
			sprite.texture = tex_swamp
			sprite.modulate = Color.WHITE
		BiomeType.MOUNTAIN:
			sprite.texture = tex_stone
			sprite.modulate = Color.WHITE
		BiomeType.SNOW_TUNDRA:
			sprite.texture = tex_snow
			sprite.modulate = Color.WHITE

	terrain_layer.add_child(sprite)

func _spawn_props_at(pos: Vector2, biome: BiomeType, grid_x: int, grid_y: int) -> void:
	var f_noise = foliage_noise.get_noise_2d(grid_x, grid_y)

	match biome:
		BiomeType.FOREST:
			if (abs(grid_x) % 3 == 0 and abs(grid_y) % 3 == 0) and f_noise > -0.1 and tex_trees.size() > 0:
				var t_idx = randi() % tex_trees.size()
				var s_tex = tex_stumps[t_idx % tex_stumps.size()] if tex_stumps.size() > 0 else null
				_create_tree_prop(pos, tex_trees[t_idx], s_tex)
			elif (abs(grid_x) % 2 == 1 and abs(grid_y) % 2 == 1) and f_noise < -0.25 and tex_bushes.size() > 0:
				_create_bush_prop(pos, tex_bushes[randi() % tex_bushes.size()])
			elif (abs(grid_x) % 4 == 2 and abs(grid_y) % 4 == 2) and f_noise > 0.3 and tex_rocks.size() > 0:
				_create_rock_prop(pos, tex_rocks[randi() % tex_rocks.size()])

		BiomeType.MOUNTAIN:
			if (abs(grid_x) % 2 == 0 and abs(grid_y) % 2 == 0) and f_noise > -0.05 and tex_rocks.size() > 0:
				_create_rock_prop(pos, tex_rocks[randi() % tex_rocks.size()])

		BiomeType.SNOW_TUNDRA:
			if (abs(grid_x) % 3 == 1 and abs(grid_y) % 3 == 1) and f_noise > 0.0 and tex_trees.size() > 0:
				var t_idx = randi() % tex_trees.size()
				var s_tex = tex_stumps[t_idx % tex_stumps.size()] if tex_stumps.size() > 0 else null
				var tree = _create_tree_prop(pos, tex_trees[t_idx], s_tex)
				tree.modulate = Color(0.75, 0.88, 1.0)

		BiomeType.BEACH:
			if (abs(grid_x) % 4 == 0 and abs(grid_y) % 4 == 0) and f_noise > 0.2 and tex_rocks.size() > 0:
				_create_rock_prop(pos, tex_rocks[randi() % tex_rocks.size()], 0.6)

func _create_tree_prop(pos: Vector2, tex: Texture2D, stump_tex: Texture2D = null) -> Node2D:
	var tree = TreePropScript.new()
	tree.position = pos
	tree.stump_texture = stump_tex
	
	var sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = tex
	sprite.hframes = 8
	sprite.frame = 0
	sprite.scale = Vector2(0.55, 0.55)
	sprite.offset = Vector2(0, -96)
	tree.add_child(sprite)

	var col = CollisionShape2D.new()
	col.name = "CollisionShape2D"
	var shape = CircleShape2D.new()
	shape.radius = 14.0
	col.shape = shape
	col.position = Vector2(0, -6)
	tree.add_child(col)

	tree.tree_chopped.connect(func(amt, p): resource_dropped.emit("Gỗ", amt, p))
	props_layer.add_child(tree)
	return tree

func _create_rock_prop(pos: Vector2, tex: Texture2D, scale_val: float = 0.85) -> Node2D:
	var rock = RockPropScript.new()
	rock.position = pos

	var sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = tex
	sprite.scale = Vector2(scale_val, scale_val)
	sprite.offset = Vector2(0, -12)
	rock.add_child(sprite)

	var col = CollisionShape2D.new()
	col.name = "CollisionShape2D"
	var shape = CircleShape2D.new()
	shape.radius = 16.0 * scale_val
	col.shape = shape
	col.position = Vector2(0, -8)
	rock.add_child(col)

	rock.rock_mined.connect(func(stone_amt, iron_amt, p): 
		if stone_amt > 0: resource_dropped.emit("Đá", stone_amt, p)
		if iron_amt > 0: resource_dropped.emit("Quặng Sắt", iron_amt, p)
	)
	props_layer.add_child(rock)
	return rock

func _create_bush_prop(pos: Vector2, tex: Texture2D) -> Sprite2D:
	var sprite = Sprite2D.new()
	sprite.texture = tex
	sprite.hframes = 8
	sprite.frame = 0
	sprite.position = pos
	sprite.scale = Vector2(0.35, 0.35)
	sprite.offset = Vector2(0, -20)
	props_layer.add_child(sprite)
	return sprite

func update_player_biome(player_global_pos: Vector2) -> void:
	var grid_x = int(round(player_global_pos.x / tile_size))
	var grid_y = int(round(player_global_pos.y / tile_size))
	var biome = get_biome_at(grid_x, grid_y)

	if biome != current_player_biome:
		current_player_biome = biome
		var biome_name = get_biome_name(biome)
		var temp = get_biome_temperature(biome)
		biome_changed.emit(biome_name, temp)

func get_biome_name(biome: BiomeType) -> String:
	match biome:
		BiomeType.OCEAN: return "Đại Dương Sâu Thẳm"
		BiomeType.RIVER: return "Dòng Sông Nước Ngọt"
		BiomeType.BEACH: return "Bãi Biển Hoang Sơ"
		BiomeType.FOREST: return "Khu Rừng Nguyên Sinh"
		BiomeType.SWAMP: return "Đầm Lầy Tử Khí"
		BiomeType.MOUNTAIN: return "Cao Nguyên Vách Đá"
		BiomeType.SNOW_TUNDRA: return "Vùng Băng Tuyết Vĩnh Cửu"
		_: return "Vùng Đất Bí Ẩn"

func get_biome_temperature(biome: BiomeType) -> float:
	match biome:
		BiomeType.SNOW_TUNDRA: return 8.0
		BiomeType.MOUNTAIN: return 18.0
		BiomeType.SWAMP: return 26.0
		BiomeType.FOREST: return 28.0
		BiomeType.BEACH: return 34.0
		BiomeType.OCEAN, BiomeType.RIVER: return 22.0
		_: return 25.0
