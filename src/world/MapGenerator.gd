class_name MapGenerator
extends Node2D

signal biome_changed(biome_name: String, ambient_temp: float)
signal player_spawn_found(spawn_pos: Vector2)

enum BiomeType {
	OCEAN,
	RIVER,
	BEACH,
	FOREST,
	SWAMP,
	MOUNTAIN,
	SNOW_TUNDRA
}

@export var map_width: int = 120
@export var map_height: int = 120
@export var tile_size: int = 64
@export var map_seed: int = 0

var elevation_noise: FastNoiseLite
var moisture_noise: FastNoiseLite
var foliage_noise: FastNoiseLite

# Node holders
@onready var terrain_layer: Node2D = $TerrainTiles
@onready var props_layer: Node2D = $PropsLayer

# Preloaded textures for procedural visual rendering
var tex_water: Texture2D
var tex_sand: Texture2D
var tex_grass: Texture2D
var tex_stone: Texture2D
var tex_snow: Texture2D

var tex_trees: Array[Texture2D] = []
var tex_rocks: Array[Texture2D] = []
var tex_bushes: Array[Texture2D] = []

var spawn_location: Vector2 = Vector2.ZERO
var current_player_biome: BiomeType = BiomeType.FOREST

func _ready() -> void:
	_init_textures()
	_init_noises()
	generate_world()

func _init_textures() -> void:
	var path_base = "res://assets/map/"
	tex_grass = load("res://assets/map/forest_cainos/TX Tileset Grass.png")
	tex_stone = load("res://assets/map/forest_cainos/TX Tileset Stone Ground.png")
	tex_sand = load("res://assets/map/tiny_terrain/Tileset/Tilemap_color3.png")
	tex_water = load("res://assets/map/tiny_terrain/Tileset/Water Background color.png")
	tex_snow = load("res://assets/map/tiny_terrain/Tileset/Tilemap_color5.png")

	# Load Trees
	for i in range(1, 5):
		var tree_path = "res://assets/raw_packs/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Resources/Wood/Trees/Tree%d.png" % i
		if ResourceLoader.exists(tree_path):
			tex_trees.append(load(tree_path))

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
	elevation_noise.frequency = 0.025

	moisture_noise = FastNoiseLite.new()
	moisture_noise.seed = map_seed + 101
	moisture_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	moisture_noise.frequency = 0.02

	foliage_noise = FastNoiseLite.new()
	foliage_noise.seed = map_seed + 202
	foliage_noise.frequency = 0.08

func generate_world() -> void:
	for child in terrain_layer.get_children():
		child.queue_free()
	for child in props_layer.get_children():
		child.queue_free()

	var valid_spawn_points: Array[Vector2] = []

	var half_w = map_width / 2
	var half_h = map_height / 2

	for x in range(-half_w, half_w):
		for y in range(-half_h, half_h):
			var world_pos = Vector2(x * tile_size, y * tile_size)
			var biome = get_biome_at(x, y)
			
			_create_tile_sprite(world_pos, biome)
			_spawn_props_at(world_pos, biome, x, y)

			if biome == BiomeType.FOREST or biome == BiomeType.BEACH:
				if world_pos.distance_to(Vector2.ZERO) < 600.0:
					valid_spawn_points.append(world_pos)

	if valid_spawn_points.size() > 0:
		spawn_location = valid_spawn_points[randi() % valid_spawn_points.size()]
	else:
		spawn_location = Vector2.ZERO

	player_spawn_found.emit(spawn_location)

func get_biome_at(grid_x: int, grid_y: int) -> BiomeType:
	var elev = elevation_noise.get_noise_2d(grid_x, grid_y)
	var moisture = moisture_noise.get_noise_2d(grid_x, grid_y)

	if elev < -0.3:
		return BiomeType.OCEAN
	elif elev < -0.15:
		return BiomeType.RIVER
	elif elev < -0.05:
		return BiomeType.BEACH

	if moisture < -0.2:
		return BiomeType.SNOW_TUNDRA
	elif moisture > 0.3 and elev < 0.2:
		return BiomeType.SWAMP
	elif elev > 0.35:
		return BiomeType.MOUNTAIN
	else:
		return BiomeType.FOREST

func _create_tile_sprite(pos: Vector2, biome: BiomeType) -> void:
	var sprite = Sprite2D.new()
	sprite.position = pos
	sprite.centered = true
	sprite.scale = Vector2(float(tile_size) / 64.0, float(tile_size) / 64.0)

	match biome:
		BiomeType.OCEAN, BiomeType.RIVER:
			sprite.texture = tex_water if tex_water else tex_stone
			sprite.modulate = Color(0.2, 0.45, 0.85) if biome == BiomeType.OCEAN else Color(0.3, 0.6, 0.95)
		BiomeType.BEACH:
			sprite.texture = tex_sand if tex_sand else tex_grass
			sprite.modulate = Color(0.95, 0.85, 0.5)
		BiomeType.FOREST:
			sprite.texture = tex_grass
			sprite.modulate = Color(0.4, 0.8, 0.35)
		BiomeType.SWAMP:
			sprite.texture = tex_grass
			sprite.modulate = Color(0.35, 0.45, 0.3)
		BiomeType.MOUNTAIN:
			sprite.texture = tex_stone
			sprite.modulate = Color(0.65, 0.65, 0.65)
		BiomeType.SNOW_TUNDRA:
			sprite.texture = tex_snow if tex_snow else tex_stone
			sprite.modulate = Color(0.92, 0.95, 1.0)

	terrain_layer.add_child(sprite)

func _spawn_props_at(pos: Vector2, biome: BiomeType, grid_x: int, grid_y: int) -> void:
	var f_noise = foliage_noise.get_noise_2d(grid_x, grid_y)

	match biome:
		BiomeType.FOREST:
			if f_noise > 0.2 and tex_trees.size() > 0:
				_create_prop_sprite(pos, tex_trees[randi() % tex_trees.size()], 1.2, true)
			elif f_noise < -0.25 and tex_bushes.size() > 0:
				_create_prop_sprite(pos, tex_bushes[randi() % tex_bushes.size()], 0.8, false)
		BiomeType.MOUNTAIN:
			if f_noise > 0.15 and tex_rocks.size() > 0:
				_create_prop_sprite(pos, tex_rocks[randi() % tex_rocks.size()], 1.4, true)
		BiomeType.SNOW_TUNDRA:
			if f_noise > 0.25 and tex_trees.size() > 0:
				var tree = _create_prop_sprite(pos, tex_trees[randi() % tex_trees.size()], 1.0, true)
				tree.modulate = Color(0.7, 0.85, 1.0) # Cay phu bang
			elif f_noise < -0.2 and tex_rocks.size() > 0:
				var rock = _create_prop_sprite(pos, tex_rocks[randi() % tex_rocks.size()], 1.2, true)
				rock.modulate = Color(0.8, 0.9, 1.0)
		BiomeType.BEACH:
			if f_noise > 0.35 and tex_rocks.size() > 0:
				_create_prop_sprite(pos, tex_rocks[randi() % tex_rocks.size()], 0.7, false)

func _create_prop_sprite(pos: Vector2, tex: Texture2D, scale_mult: float, has_collision: bool) -> Sprite2D:
	var sprite = Sprite2D.new()
	sprite.texture = tex
	sprite.position = pos
	sprite.scale = Vector2(scale_mult, scale_mult)
	
	if has_collision:
		var static_body = StaticBody2D.new()
		var col = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = 16.0 * scale_mult
		col.shape = shape
		col.position = Vector2(0, 10 * scale_mult)
		static_body.add_child(col)
		sprite.add_child(static_body)

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
		BiomeType.SNOW_TUNDRA: return 8.0 # Cực lạnh
		BiomeType.MOUNTAIN: return 18.0 # Lạnh sương mù
		BiomeType.SWAMP: return 26.0
		BiomeType.FOREST: return 28.0 # Mát mẻ
		BiomeType.BEACH: return 34.0 # Nắng ấm
		BiomeType.OCEAN, BiomeType.RIVER: return 22.0
		_: return 25.0
