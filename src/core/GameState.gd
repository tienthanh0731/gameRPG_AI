extends Node

# Active gameplay state
var current_day: int = 1
var today_sp: int = 0
var total_season_sp: int = 0
var monsters_killed_today: int = 0
var active_talent: Dictionary = {}
var is_in_dungeon: bool = false
var has_cleared_dungeon_today: bool = false

# References
var player_ref: CharacterBody2D = null

func _ready() -> void:
	# Connect to EventBus
	EventBus.sp_added.connect(_on_sp_added)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.dungeon_cleared.connect(_on_dungeon_cleared)
	EventBus.raid_wave_cleared.connect(_on_raid_cleared)

func init_new_game(talent: Dictionary, day: int = 1) -> void:
	active_talent = talent
	current_day = day
	today_sp = 0
	monsters_killed_today = 0
	has_cleared_dungeon_today = false
	is_in_dungeon = false

# ==========================================
# CÔNG THỨC SCALING ĐỘ KHÓ THEO NGÀY (SPEC §5)
# ==========================================
# Hệ số sức mạnh quái: M(d) = 1 + 0.15·√d + 0.01·d
func get_monster_power_mult(d: int = -1) -> float:
	if d <= 0:
		d = current_day
	return 1.0 + 0.15 * sqrt(float(d)) + 0.01 * float(d)

# Quy mô thú triều: W(d) = min(8 + floor(d/3), 40)
func get_raid_wave_size(d: int = -1) -> int:
	if d <= 0:
		d = current_day
	return int(min(8 + floor(float(d) / 3.0), 40))

# Số phó bản / ngày: N(d) = min(3 + floor(d/5), 10)
func get_dungeon_count(d: int = -1) -> int:
	if d <= 0:
		d = current_day
	return int(min(3 + floor(float(d) / 5.0), 10))

# Mốc độ khó (Milestone phase)
func get_difficulty_phase_name(d: int = -1) -> String:
	if d <= 0:
		d = current_day
	if d <= 5:
		return "Tân Thủ (Làm quen)"
	elif d <= 15:
		return "Ổn Định (Thú triều tiêu chuẩn)"
	elif d <= 30:
		return "Thử Thách (Dã thú tinh anh)"
	else:
		return "Ác Mộng (Thú Vương & Cực Hạn)"

# ==========================================
# ĐIỂM SINH TỒN (SP) & TỔNG KẾT
# ==========================================
func add_sp(amount: int, reason: String = "") -> void:
	today_sp += amount
	total_season_sp += amount
	EventBus.sp_added.emit(amount, reason)
	EventBus.score_updated.emit(today_sp, total_season_sp)

func _on_sp_added(amount: int, _reason: String) -> void:
	pass

func _on_enemy_killed(_type: String, is_elite: bool, _pos: Vector2) -> void:
	monsters_killed_today += 1
	if is_elite:
		add_sp(10, "Hạ quái tinh anh")
	else:
		add_sp(1, "Hạ dã thú thường")

func _on_dungeon_cleared(_name: String, _reward: Dictionary) -> void:
	has_cleared_dungeon_today = true
	add_sp(30, "Chinh phục phó bản")

func _on_raid_cleared(_day: int) -> void:
	add_sp(50, "Sống sót qua đêm thú triều")

# Tổng kết cuối ngày (Ngay sau khi kết thúc đêm - 06:00 sáng)
func evaluate_day_end() -> Dictionary:
	var rank_tier = "SP = 0"
	var chest_reward = {
		"tier": "NONE",
		"items": []
	}
	
	if today_sp >= 120:
		rank_tier = "Top 1% (Huyền Thoại)"
		chest_reward["tier"] = "LEGENDARY"
		chest_reward["items"] = [
			{ "name": "Đan Reroll Thiên Phú", "amount": 1 },
			{ "name": "Quặng Sắt", "amount": 15 },
			{ "name": "Đá", "amount": 25 },
			{ "name": "Gỗ", "amount": 40 },
			{ "name": "Thịt Rừng", "amount": 10 }
		]
	elif today_sp >= 75:
		rank_tier = "Top 10% (Hiếm)"
		chest_reward["tier"] = "RARE"
		chest_reward["items"] = [
			{ "name": "Quặng Sắt", "amount": 8 },
			{ "name": "Đá", "amount": 15 },
			{ "name": "Gỗ", "amount": 25 },
			{ "name": "Thịt Rừng", "amount": 5 }
		]
	elif today_sp >= 40:
		rank_tier = "Top 50% (Thường)"
		chest_reward["tier"] = "NORMAL"
		chest_reward["items"] = [
			{ "name": "Đá", "amount": 10 },
			{ "name": "Gỗ", "amount": 15 },
			{ "name": "Thịt Rừng", "amount": 3 }
		]
	elif today_sp > 0:
		rank_tier = "Tham Gia Tích Cực"
		chest_reward["tier"] = "PARTICIPATION"
		chest_reward["items"] = [
			{ "name": "Gỗ", "amount": 8 },
			{ "name": "Đá", "amount": 5 }
		]
		
	var summary = {
		"day": current_day,
		"today_sp": today_sp,
		"rank_tier": rank_tier,
		"chest": chest_reward,
		"monsters_killed": monsters_killed_today
	}
	
	# Emit event
	EventBus.day_ended.emit(current_day, today_sp, rank_tier, chest_reward)
	
	# Reset daily counter & advance day
	current_day += 1
	today_sp = 0
	monsters_killed_today = 0
	has_cleared_dungeon_today = false
	
	return summary
