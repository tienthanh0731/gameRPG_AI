class_name StructureVisuals
extends RefCounted
## Cung cấp texture và màu sắc theo bậc (Gỗ, Đá, Sắt) cho công trình căn cứ.
## Dùng để Claude gọi trong Structure.set_tier(new_tier).

# Cache loaded textures
static var _textures: Dictionary = {}

static func _get_loaded_tex(path: String) -> Texture2D:
	if _textures.has(path):
		return _textures[path]
	if ResourceLoader.exists(path):
		var tex = load(path)
		if tex is Texture2D:
			_textures[path] = tex
			return tex
	# Fallback: Load directly via ImageTexture if file is not yet imported
	var global_p = ProjectSettings.globalize_path(path)
	var img: Image = null
	if FileAccess.file_exists(path):
		img = Image.load_from_file(path)
	elif FileAccess.file_exists(global_p):
		img = Image.load_from_file(global_p)
	if img and not img.is_empty():
		var itex = ImageTexture.create_from_image(img)
		_textures[path] = itex
		return itex
	return null

## Trả về Texture2D tương ứng với loại công trình và bậc vật liệu (0: Gỗ, 1: Đá, 2: Sắt)
static func get_tier_texture(structure_type: int, tier: int, is_open: bool = false) -> Texture2D:
	tier = clampi(tier, 0, 2)
	match structure_type:
		0: # WALL
			match tier:
				0: return _get_loaded_tex("res://assets/buildings/structures/wall_wood.png")
				1: return _get_loaded_tex("res://assets/buildings/structures/wall_stone.png")
				2: return _get_loaded_tex("res://assets/buildings/structures/wall_iron.png")
		1: # DOOR
			if is_open:
				match tier:
					0: return _get_loaded_tex("res://assets/buildings/structures/door_wood_open.png")
					1: return _get_loaded_tex("res://assets/buildings/structures/door_stone_open.png")
					2: return _get_loaded_tex("res://assets/buildings/structures/door_iron_open.png")
			else:
				match tier:
					0: return _get_loaded_tex("res://assets/buildings/structures/door_wood_closed.png")
					1: return _get_loaded_tex("res://assets/buildings/structures/door_stone_closed.png")
					2: return _get_loaded_tex("res://assets/buildings/structures/door_iron_closed.png")
		2: # SPIKE
			match tier:
				0: return _get_loaded_tex("res://assets/buildings/structures/spike_trap.png")
				1: return _get_loaded_tex("res://assets/buildings/structures/spike_trap_stone.png")
				2: return _get_loaded_tex("res://assets/buildings/structures/spike_trap_iron.png")
		3: # HOUSE
			# Nhà có thể giữ nguyên texture nhà gỗ hoặc thêm tint bảo vệ
			return _get_loaded_tex("res://assets/buildings/Yellow Buildings/House1.png")
	return _get_loaded_tex("res://assets/buildings/structures/wall_wood.png")

## Màu bổ trợ (tint) nếu muốn kết hợp cùng texture
static func get_tier_color(tier: int) -> Color:
	match clampi(tier, 0, 2):
		0: return Color(1.0, 1.0, 1.0, 1.0)       # Gỗ mộc
		1: return Color(0.92, 0.94, 0.98, 1.0)   # Đá granite sáng
		2: return Color(0.85, 0.90, 1.0, 1.0)    # Sắt thép ánh kim
	return Color.WHITE
