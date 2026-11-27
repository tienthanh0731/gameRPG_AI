extends Node
## GameState — trạng thái phiên chơi của nhân vật hiện tại + các công thức gameplay.
## Logic thuần (không UI). UI chỉ nghe EventBus.

const BASE_MAX_HEALTH: float = 100.0
const BASE_MOVE_SPEED: float = 160.0
const BASE_SPRINT_SPEED: float = 230.0

const DIRECTIONS: Array[String] = ["Bắc", "Đông", "Nam", "Tây"]
const DIRECTION_VECTORS: Array[Vector2] = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]

# Trạng thái phiên chơi
var current_day: int = 1
var time_hours: float = 7.0
var today_sp: int = 0
var character_total_sp: int = 0
var kills_today: int = 0
var active_talent: Dictionary = {}
## Thiên Phú Phụ (từ ngày 15) — cộng 50% hiệu ứng của nó
var sub_talent: Dictionary = {}
const SUB_TALENT_WEIGHT: float = 0.5
var is_in_dungeon: bool = false
var is_dead: bool = false

## Phó bản đang vào (dict từ danh sách dungeons hôm nay)
var active_dungeon: Dictionary = {}

## Thống kê thú triều đêm nay (cho điểm đóng góp phòng thủ 0-40)
var raid_kills_tonight: int = 0
var raid_size_tonight: int = 0

## true khi đang cộng rương thưởng vào túi (để nhiệm vụ "thu thập" không tính).
var granting_rewards: bool = false

func _ready() -> void:
	EventBus.enemy_killed.connect(_on_enemy_killed)

# ==========================================
# NẠP / LƯU NHÂN VẬT
# ==========================================
func load_from_character() -> void:
	var c := SaveSystem.character_data
	active_talent = c.get("talent", {})
	sub_talent = c.get("sub_talent", {})
	current_day = int(c.get("day", 1))
	time_hours = float(c.get("time_hours", 7.0))
	today_sp = int(c.get("today_sp", 0))
	character_total_sp = int(c.get("total_sp", 0))
	kills_today = int(c.get("kills_today", 0))
	is_in_dungeon = false
	is_dead = false
	active_dungeon = {}
	raid_kills_tonight = 0
	raid_size_tonight = 0
	EventBus.score_updated.emit(today_sp, character_total_sp)

## Giữ tương thích với code cũ.
func init_new_game(talent: Dictionary, day: int = 1) -> void:
	load_from_character()
	if not talent.is_empty():
		active_talent = talent
	current_day = day

func autosave() -> void:
	if is_dead or not SaveSystem.has_active_character():
		return
	var c := SaveSystem.character_data
	c["day"] = current_day
	c["time_hours"] = time_hours
	c["today_sp"] = today_sp
	c["total_sp"] = character_total_sp
	c["kills_today"] = kills_today
	c["talent"] = active_talent
	c["sub_talent"] = sub_talent
	SaveSystem.save_character(c)

## Ghi máu/đói/thể lực/túi đồ của Player vào dữ liệu nhân vật.
func capture_player(player: Node) -> void:
	if is_dead or not player or not SaveSystem.has_active_character():
		return
	var c := SaveSystem.character_data
	var stats := player.get_node_or_null("SurvivalStats")
	if stats:
		c["health"] = stats.current_health
		c["hunger"] = stats.hunger
		c["stamina"] = stats.current_stamina
	var inv := player.get_node_or_null("Inventory")
	if inv and inv.has_method("to_dict"):
		c["inventory"] = inv.to_dict()
	if "equipment" in player:
		c["equipment"] = player.equipment.duplicate(true)

## Áp thiên phú + khôi phục chỉ số/túi đồ đã lưu lên Player.
func apply_player(player: Node) -> void:
	if not player:
		return
	var c := SaveSystem.character_data
	apply_talent_stats(player, false)
	var stats := player.get_node_or_null("SurvivalStats")
	if stats:
		var hp := float(c.get("health", -1.0))
		stats.current_health = stats.max_health if hp <= 0.0 else minf(hp, stats.max_health)
		stats.hunger = float(c.get("hunger", 100.0))
		stats.current_stamina = minf(float(c.get("stamina", stats.max_stamina)), stats.max_stamina)
		stats.health_changed.emit(stats.current_health, stats.max_health)
		stats.stamina_changed.emit(stats.current_stamina, stats.max_stamina)
	var inv := player.get_node_or_null("Inventory")
	if inv and inv.has_method("from_dict"):
		inv.from_dict(c.get("inventory", {}))
	if player.has_method("set_equipment"):
		player.set_equipment(c.get("equipment", EquipmentData.default_loadout()))

## Chỉ số thiên phú tổng hợp = thiên phú chính + 50% thiên phú phụ.
## key nhân (…_mult) gộp kiểu nhân; regen / dmg_reduction gộp kiểu cộng.
func talent_stat(key: String, default_val: float) -> float:
	var main_v := float(active_talent.get(key, default_val))
	if sub_talent.is_empty():
		return main_v
	var sub_v := float(sub_talent.get(key, default_val))
	if key.ends_with("_mult"):
		return main_v * (1.0 + (sub_v - 1.0) * SUB_TALENT_WEIGHT)
	return main_v + sub_v * SUB_TALENT_WEIGHT

func _talent_ids() -> Array:
	return [str(active_talent.get("id", "")), str(sub_talent.get("id", ""))]

func apply_talent_stats(player: Node, refill: bool) -> void:
	var stats := player.get_node_or_null("SurvivalStats")
	if stats:
		var ratio: float = stats.current_health / maxf(1.0, stats.max_health)
		stats.max_health = BASE_MAX_HEALTH * talent_stat("hp_mult", 1.0)
		stats.current_health = stats.max_health if refill else stats.max_health * ratio
		stats.regen_per_sec = talent_stat("regen", 0.0)
		stats.damage_reduction = minf(talent_stat("dmg_reduction", 0.0), 0.6)
		stats.health_changed.emit(stats.current_health, stats.max_health)
	var spd := talent_stat("speed_mult", 1.0)
	player.set("move_speed", BASE_MOVE_SPEED * spd)
	player.set("sprint_speed", BASE_SPRINT_SPEED * spd)

func get_player_damage_mult() -> float:
	return talent_stat("dmg_mult", 1.0)

func get_gather_mult() -> float:
	return talent_stat("gather_mult", 1.0)

## Thiên phú tăng máu công trình: Thổ Bá +100%, Hoang Cổ Bá Chủ +200%.
func get_structure_hp_mult() -> float:
	var ids := _talent_ids()
	if "sss_primordial_overlord" in ids: return 3.0
	if "b_earth_lord" in ids: return 2.0
	return 1.0

## Sản lượng thụ động của các cứ điểm đã chiếm (cộng vào rương cuối ngày).
const OUTPOST_INCOME := { "Gỗ": 8, "Đá": 5, "Quặng Sắt": 2 }

func get_outpost_income() -> Array:
	var n: int = SaveSystem.character_data.get("captured_outposts", []).size()
	if n <= 0:
		return []
	var out: Array = []
	for item_name in OUTPOST_INCOME:
		out.append({ "name": item_name, "amount": OUTPOST_INCOME[item_name] * n, "source": "Lãnh thổ" })
	return out

## Rương chưa nhận (tắt game khi popup tổng kết đang mở) → trả về và xóa.
func take_unclaimed_rewards() -> Array:
	var items: Array = SaveSystem.character_data.get("unclaimed_rewards", [])
	SaveSystem.character_data.erase("unclaimed_rewards")
	return items

# ==========================================
# CÔNG THỨC SCALING ĐỘ KHÓ THEO NGÀY (SPEC §5)
# ==========================================
## M(d) = 1 + 0.15·√d + 0.01·d
func get_monster_power_mult(d: int = -1) -> float:
	if d <= 0:
		d = current_day
	return 1.0 + 0.15 * sqrt(float(d)) + 0.01 * float(d)

## W(d) = min(8 + floor(d/3), 40)
func get_raid_wave_size(d: int = -1) -> int:
	if d <= 0:
		d = current_day
	return int(min(8 + floor(float(d) / 3.0), 40))

## N(d) = min(3 + floor(d/5), 10)
func get_dungeon_count(d: int = -1) -> int:
	if d <= 0:
		d = current_day
	return int(min(3 + floor(float(d) / 5.0), 10))

## Ngày 1-5 "chưa có thú triều thật": chỉ có đợt trinh sát nhỏ (1/3 W(d)).
func is_real_tide(d: int = -1) -> bool:
	if d <= 0:
		d = current_day
	return d > 5

func get_tonight_wave_size(d: int = -1) -> int:
	if d <= 0:
		d = current_day
	var w := get_raid_wave_size(d)
	return w if is_real_tide(d) else maxi(2, w / 3)

## Tỉ lệ quái tinh anh trong thú triều (từ ngày 16).
func get_elite_chance(d: int = -1) -> float:
	if d <= 0:
		d = current_day
	if d < 16:
		return 0.0
	return minf(0.1 + 0.01 * float(d - 16), 0.35)

## Hướng tấn công + loại quái chủ lực đêm nay (ngẫu nhiên nhưng cố định trong ngày,
## nên cảnh báo hoàng hôn khớp với đợt tấn công thật).
func get_tonight_preview(d: int = -1) -> Dictionary:
	if d <= 0:
		d = current_day
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|tide|%d" % [SaveSystem.character_data.get("char_id", ""), d])
	var dir_count := 1 if d <= 10 else (2 if d <= 25 else 3)
	var pool: Array[int] = [0, 1, 2, 3]
	var dirs: Array[int] = []
	for i in dir_count:
		var idx := rng.randi() % pool.size()
		dirs.append(pool[idx])
		pool.remove_at(idx)
	var names: Array[String] = []
	for di in dirs:
		names.append(DIRECTIONS[di])
	return {
		"count": get_tonight_wave_size(d),
		"directions": dirs,
		"direction_names": names,
		"monster_type": "Heo Rừng Cuồng Nộ" if d < 16 else "Heo Rừng + Cổ Thú Tinh Anh",
		"is_real": is_real_tide(d),
		"elite_chance": get_elite_chance(d),
	}

## Số giờ game còn lại tới khi thú triều bắt đầu (19:30).
func hours_until_tide() -> float:
	var h := 19.5 - time_hours
	if h < 0.0:
		h += 24.0
	return h

func get_difficulty_phase_name(d: int = -1) -> String:
	if d <= 0:
		d = current_day
	if d <= 5:
		return "Tân Thủ (Làm quen)"
	elif d <= 15:
		return "Ổn Định"
	elif d <= 30:
		return "Thử Thách (Quái tinh anh)"
	return "Ác Mộng (Boss chu kỳ)"

# ==========================================
# PHÓ BẢN NGẪU NHIÊN MỖI NGÀY
# ==========================================
## Sinh N(d) cửa phó bản quanh căn cứ. Vị trí/layout/độ khó đổi mỗi ngày,
## được lưu vào nhân vật để thoát/vào lại không bị roll lại.
func get_today_dungeons(base_pos: Vector2) -> Array:
	var c := SaveSystem.character_data
	var data: Dictionary = c.get("dungeons", {})
	if int(data.get("day", 0)) == current_day and data.has("list"):
		return data["list"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|dungeon|%d" % [c.get("char_id", ""), current_day])
	var list: Array = []
	var n := get_dungeon_count()
	for i in n:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(420.0, 1500.0)
		var pos := base_pos + Vector2(cos(ang), sin(ang)) * dist
		var stars := clampi(1 + int(dist / 450.0) + int(current_day / 10), 1, 5)
		list.append({
			"id": "D%d_%d" % [current_day, i],
			"x": pos.x, "y": pos.y,
			"seed": rng.randi(),
			"stars": stars,
			"cleared": false,
		})
	c["dungeons"] = { "day": current_day, "list": list }
	return list

func mark_dungeon_cleared(dungeon_id: String) -> bool:
	var data: Dictionary = SaveSystem.character_data.get("dungeons", {})
	for d in data.get("list", []):
		if d.get("id") == dungeon_id and not d.get("cleared", false):
			d["cleared"] = true
			var c := SaveSystem.character_data
			c["dungeons_cleared"] = int(c.get("dungeons_cleared", 0)) + 1 # cho Giác Ngộ
			add_sp(30, "Hoàn thành phó bản")
			return true
	return false

# ==========================================
# ĐIỂM SINH TỒN (SP) — chỉ tính ở đây ("server"), không nhận từ UI
# ==========================================
func add_sp(amount: int, reason: String = "") -> void:
	if amount <= 0 or is_dead:
		return
	today_sp += amount
	character_total_sp += amount
	EventBus.sp_added.emit(amount, reason)
	EventBus.score_updated.emit(today_sp, character_total_sp)

func _on_enemy_killed(_type: String, is_elite: bool, _pos: Vector2) -> void:
	if is_dead:
		return
	kills_today += 1
	var c := SaveSystem.character_data
	c["monsters_killed"] = int(c.get("monsters_killed", 0)) + 1
	if is_elite:
		c["elites_killed"] = int(c.get("elites_killed", 0)) + 1
		add_sp(10, "Hạ quái tinh anh")
	else:
		add_sp(1, "Hạ quái thường")

func begin_raid(size: int) -> void:
	raid_kills_tonight = 0
	raid_size_tonight = size

func register_raid_kill() -> void:
	raid_kills_tonight += 1

## Gọi lúc rạng đông: sống sót qua đêm +50, đóng góp phòng thủ 0-40.
func finish_raid() -> void:
	add_sp(50, "Sống sót qua đêm")
	if raid_size_tonight > 0:
		var share := clampf(float(raid_kills_tonight) / float(raid_size_tonight), 0.0, 1.0)
		add_sp(int(round(40.0 * share)), "Đóng góp phòng thủ thú triều")
	EventBus.raid_wave_cleared.emit(current_day)

## Tổng kết cuối ngày (ngay sau khi đêm kết thúc). Xếp hạng qua ServerSim,
## ghi SP vào điểm mùa của Account, sang ngày mới và autosave.
func evaluate_day_end() -> Dictionary:
	var ranking := ServerSim.rank_day(current_day, today_sp)
	var chest: Dictionary = ranking.chest.duplicate(true)
	chest["items"] = chest.get("items", []) + get_outpost_income()
	# Lưu thưởng vào nhân vật trước khi autosave: nếu tắt game khi popup còn mở
	# thì lần sau vẫn nhận được (Main gọi take_unclaimed_rewards khi nạp).
	SaveSystem.character_data["unclaimed_rewards"] = chest.items
	if chest.has("title"):
		SaveSystem.add_title(chest.title)
	SaveSystem.commit_day_to_account(today_sp, kills_today)

	var summary := {
		"day": current_day,
		"today_sp": today_sp,
		"rank": ranking.rank,
		"total_players": ranking.total,
		"percentile": ranking.percentile,
		"rank_tier": ranking.tier_label,
		"chest": chest,
		"monsters_killed": kills_today,
	}
	EventBus.day_ended.emit(current_day, today_sp, ranking.tier_label, chest)

	current_day += 1
	today_sp = 0
	kills_today = 0
	autosave()
	EventBus.day_started.emit(current_day)
	EventBus.score_updated.emit(today_sp, character_total_sp)
	return summary

# ==========================================
# PERMADEATH
# ==========================================
## Xử lý chết đúng 1 lần (SurvivalStats có thể bắn tín hiệu nhiều lần khi HP=0).
func handle_player_death() -> Dictionary:
	if is_dead:
		return SaveSystem.last_death_summary
	is_dead = true
	var result := SaveSystem.kill_character_atomic(current_day, character_total_sp, active_talent)
	EventBus.player_died.emit(current_day, character_total_sp, result.get("record_broken", false))
	active_talent = {}
	return result
