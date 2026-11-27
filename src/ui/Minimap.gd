extends Control
## Mini-map đơn giản: vẽ người chơi, căn cứ và các cửa phó bản hôm nay.

const WORLD_RADIUS: float = 1800.0

var player_pos: Vector2 = Vector2.ZERO
var base_pos: Vector2 = Vector2.ZERO
var dungeons: Array = []

func set_points(p: Vector2, b: Vector2, d: Array) -> void:
	player_pos = p
	base_pos = b
	dungeons = d
	queue_redraw()

func _to_map(world: Vector2) -> Vector2:
	var half := size * 0.5
	var rel := (world - player_pos) / WORLD_RADIUS * half.x
	rel = rel.limit_length(half.x - 4.0)
	return half + rel

func _draw() -> void:
	var half := size * 0.5
	draw_circle(half, half.x, Color(0.05, 0.08, 0.05, 0.75))
	draw_arc(half, half.x, 0, TAU, 48, Color(0.6, 0.6, 0.5), 2.0)
	for d in dungeons:
		draw_circle(_to_map(d), 4.0, Color(0.4, 0.7, 1.0))
	draw_rect(Rect2(_to_map(base_pos) - Vector2(4, 4), Vector2(8, 8)), Color(1.0, 0.6, 0.2))
	draw_circle(half, 3.5, Color(1, 1, 1))
	draw_string(ThemeDB.fallback_font, Vector2(6, size.y - 4), "■ căn cứ  ● phó bản", HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
