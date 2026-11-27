extends Node
## SeasonSystem — Mùa giải, tuần, Season Pass, Tái Sinh (Spec §8). Chỉ logic.
##
## Mùa / tuần tính theo giờ thật (như server): mùa dài 4 tuần, tuần bắt đầu thứ Hai 0h UTC.
## Sang mùa mới: lưu thành tích mùa cũ vào lịch sử Account, reset điểm mùa + BXH mùa,
## và cấp bản đồ mới cho nhân vật đang sống (căn cứ/cứ điểm/phó bản cũ bị xóa,
## còn thiên phú, trang bị, túi đồ được giữ).

const WEEK_SECONDS: int = 7 * 24 * 3600
const WEEKS_PER_SEASON: int = 4
## 1970-01-05 là thứ Hai → mốc tính tuần
const WEEK_EPOCH: int = 4 * 24 * 3600

const PASS_POINTS_PER_TIER: int = 250
const MAX_PRESTIGE: int = 5
const PRESTIGE_MIN_DAY: int = 10
const PRESTIGE_GROWTH_PER_LEVEL: float = 0.10

## Phần thưởng Season Pass. "%s" trong tên danh hiệu = số mùa.
const PASS_REWARDS: Array[Dictionary] = [
	{ "items": [{ "name": "Gỗ", "amount": 20 }] },
	{ "title": "Kẻ Khai Hoang Mùa %s" },
	{ "items": [{ "name": "Quặng Sắt", "amount": 10 }] },
	{ "items": [{ "name": "Đan Reroll Thiên Phú", "amount": 1 }] },
	{ "cosmetic": "Áo Choàng Da Thú" },
	{ "items": [{ "name": "Quặng Sắt", "amount": 15 }, { "name": "Đá", "amount": 15 }] },
	{ "cosmetic": "Khung Tên Hoàng Kim" },
	{ "items": [{ "name": "Đan Reroll Thiên Phú", "amount": 1 }] },
	{ "items": [{ "name": "Đá", "amount": 30 }, { "name": "Quặng Sắt", "amount": 20 }] },
	{ "title": "Huyền Thoại Mùa %s", "cosmetic": "Hào Quang Thái Cổ" },
]

## Để test: đặt > 0 để giả lập thời điểm hiện tại.
var now_override: int = 0

signal season_rolled(old_season: int, new_season: int)
signal week_rolled(new_week: int)

func _ready() -> void:
	check_rollover()

func now() -> int:
	return now_override if now_override > 0 else int(Time.get_unix_time_from_system())

func week_id(t: int = -1) -> int:
	if t < 0:
		t = now()
	return (t - WEEK_EPOCH) / WEEK_SECONDS

func season_id(t: int = -1) -> int:
	return week_id(t) / WEEKS_PER_SEASON + 1

func week_in_season(t: int = -1) -> int:
	return week_id(t) % WEEKS_PER_SEASON + 1

## Giây còn lại tới hết mùa.
func seconds_left_in_season() -> int:
	var next_season_week := (week_id() / WEEKS_PER_SEASON + 1) * WEEKS_PER_SEASON
	return WEEK_EPOCH + next_season_week * WEEK_SECONDS - now()

# ==========================================
# ROLLOVER MÙA / TUẦN
# ==========================================
func check_rollover() -> void:
	var acc := SaveSystem.account_data
	var cur_season := season_id()
	var cur_week := week_id()
	var saved_season := int(acc.get("season_id", 0))
	var saved_week := int(acc.get("week_id", 0))
	if saved_season == 0:
		acc["season_id"] = cur_season
		acc["week_id"] = cur_week
		SaveSystem.save_account()
		return
	if cur_season != saved_season:
		_roll_season(saved_season, cur_season)
	if cur_week != saved_week:
		acc["week_id"] = cur_week
		acc["weekly_kills"] = 0
		acc.erase("weekly_quests")
		SaveSystem.save_account()
		week_rolled.emit(cur_week)

func _roll_season(old_s: int, new_s: int) -> void:
	var acc := SaveSystem.account_data
	var hist: Array = acc.get("season_history", [])
	hist.push_front({
		"season": old_s,
		"season_sp": int(acc.get("season_sp", 0)),
		"best_day": int(acc.get("season_best_day", 0)),
		"alliance_points": int(acc.get("alliance_points", 0)),
		"pass_tier": pass_tier(),
	})
	while hist.size() > 12:
		hist.pop_back()
	acc["season_history"] = hist
	acc["season_id"] = new_s
	acc["season_sp"] = 0
	acc["season_best_day"] = 0
	acc["alliance_points"] = 0
	acc["pass_claimed"] = []
	SaveSystem.save_account()
	# Bản đồ mới cho nhân vật đang sống
	if SaveSystem.has_active_character():
		var c := SaveSystem.character_data
		c["world_seed"] = randi() % 2000000000 + 1
		for k in ["structures", "captured_outposts", "pos_x", "pos_y", "dungeons", "starter_house_given", "tide_started_day"]:
			c.erase(k)
		c["outposts"] = 0
		SaveSystem.save_character(c)
	season_rolled.emit(old_s, new_s)

# ==========================================
# SEASON PASS
# ==========================================
func pass_tier() -> int:
	return mini(int(SaveSystem.account_data.get("season_sp", 0)) / PASS_POINTS_PER_TIER, PASS_REWARDS.size())

func is_claimed(tier: int) -> bool:
	return tier in SaveSystem.account_data.get("pass_claimed", [])

func can_claim(tier: int) -> bool:
	return tier >= 1 and tier <= pass_tier() and not is_claimed(tier)

func describe_reward(tier: int) -> String:
	var r: Dictionary = PASS_REWARDS[tier - 1]
	var parts: Array[String] = []
	for it in r.get("items", []):
		parts.append("+%d %s" % [it.amount, it.name])
	if r.has("title"):
		parts.append("Danh hiệu: " + (str(r.title) % season_id()))
	if r.has("cosmetic"):
		parts.append("Cosmetic: " + str(r.cosmetic))
	return ", ".join(parts)

## Nhận thưởng bậc `tier`. Vật phẩm vào túi của `inventory` (nhân vật đang sống),
## danh hiệu / cosmetic vào Account. Trả về false nếu chưa đủ điều kiện.
func claim(tier: int, inventory: Node) -> bool:
	if not can_claim(tier):
		return false
	var r: Dictionary = PASS_REWARDS[tier - 1]
	var items: Array = r.get("items", [])
	if not items.is_empty() and (inventory == null or not SaveSystem.has_active_character()):
		return false # cần nhân vật đang sống để nhận vật phẩm
	var acc := SaveSystem.account_data
	if inventory:
		GameState.granting_rewards = true
		for it in items:
			inventory.add_resource(str(it.name), int(it.amount))
		GameState.granting_rewards = false
	if r.has("title"):
		SaveSystem.add_title(str(r.title) % season_id())
	if r.has("cosmetic"):
		var cos: Array = acc.get("cosmetics", [])
		if not r.cosmetic in cos:
			cos.append(r.cosmetic)
		acc["cosmetics"] = cos
	var claimed: Array = acc.get("pass_claimed", [])
	claimed.append(tier)
	acc["pass_claimed"] = claimed
	SaveSystem.save_account()
	return true

# ==========================================
# TÁI SINH (PRESTIGE) — tự nguyện
# ==========================================
func prestige_level() -> int:
	return int(SaveSystem.account_data.get("prestige_level", 0))

## Hệ số tăng trưởng cho nhân vật mới: +10%/cấp Tái Sinh (thu thập & rương cuối ngày).
func growth_mult() -> float:
	return 1.0 + PRESTIGE_GROWTH_PER_LEVEL * prestige_level()

func can_prestige() -> String:
	if not SaveSystem.has_active_character():
		return "Không có nhân vật"
	if GameState.current_day < PRESTIGE_MIN_DAY:
		return "Cần sống tới ngày %d" % PRESTIGE_MIN_DAY
	if prestige_level() >= MAX_PRESTIGE:
		return "Đã đạt Tái Sinh tối đa (%d)" % MAX_PRESTIGE
	return ""

## Tái Sinh: kết thúc nhân vật hiện tại (lưu thành tích như khi chết, nhưng không tính là chết),
## +1 cấp Tái Sinh cho Account. Trả về summary, {} nếu bị từ chối.
func prestige() -> Dictionary:
	if can_prestige() != "":
		return {}
	var summary := SaveSystem.retire_character_atomic(GameState.current_day, GameState.character_total_sp, GameState.active_talent, "prestige")
	GameState.is_dead = true # phiên chơi kết thúc
	GameState.active_talent = {}
	return summary
