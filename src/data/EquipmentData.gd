class_name EquipmentData
extends RefCounted
## Dữ liệu & công thức thuần cho trang bị (công cụ / vũ khí) và độ cứng vật liệu.
##
## Thời gian khai thác 1 vật = số nhát × thời gian vung:
##   số nhát = ceil(độ cứng vật liệu / sức mạnh công cụ)
## → Rìu Sắt chặt Cổ Thụ nhanh hơn Rìu Gỗ rất nhiều, và Rìu Gỗ không chặt nổi Cổ Thụ.
## Mỗi nhát trúng trừ độ bền = 1 + bậc cứng của vật liệu. Độ bền 0 = gãy (đánh tay không).

enum Slot { AXE, PICKAXE, SWORD } # khớp Player.ToolMode

const SLOT_KEYS: Array[String] = ["axe", "pickaxe", "sword"]
const SLOT_NAMES: Array[String] = ["Rìu", "Cuốc", "Kiếm"]
const TIER_NAMES: Array[String] = ["Gỗ", "Đá", "Sắt"]
const MAX_TIER: int = 2

## Theo bậc: sức mạnh (điểm khai thác / sát thương), thời gian vung (giây), độ bền tối đa,
## sản lượng cộng thêm khi khai thác xong.
const TIER_STATS: Array[Dictionary] = [
	{ "power": 10, "swing": 0.45, "durability": 40, "bonus_yield": 0 },
	{ "power": 18, "swing": 0.36, "durability": 90, "bonus_yield": 1 },
	{ "power": 30, "swing": 0.28, "durability": 200, "bonus_yield": 2 },
]
## Tay không (công cụ gãy)
const BROKEN_STATS: Dictionary = { "power": 4, "swing": 0.55, "durability": 0, "bonus_yield": 0 }

## Nguyên liệu chế tạo từng bậc (giống nhau cho mọi loại công cụ, kiếm tốn thêm xương).
const CRAFT_COST: Array[Dictionary] = [
	{ "wood": 4 },
	{ "wood": 4, "stone": 6 },
	{ "wood": 6, "iron": 4 },
]

# ------------------------------------------------------------------
# VẬT LIỆU: độ cứng + bậc công cụ tối thiểu
# ------------------------------------------------------------------
const TREE_KINDS: Array[Dictionary] = [
	{ "name": "Cây Non", "toughness": 20, "hardness": 0, "min_tier": 0, "wood": [2, 3], "scale": 0.8 },
	{ "name": "Cây Rừng", "toughness": 40, "hardness": 0, "min_tier": 0, "wood": [3, 5], "scale": 1.0 },
	{ "name": "Cổ Thụ", "toughness": 90, "hardness": 1, "min_tier": 1, "wood": [7, 10], "scale": 1.25 },
]
const ROCK_KINDS: Array[Dictionary] = [
	{ "name": "Đá Vụn", "toughness": 20, "hardness": 0, "min_tier": 0, "stone": [1, 2], "iron_chance": 0.0, "iron": [0, 0] },
	{ "name": "Đá Tảng", "toughness": 45, "hardness": 1, "min_tier": 0, "stone": [2, 4], "iron_chance": 0.3, "iron": [1, 1] },
	{ "name": "Mạch Quặng Sắt", "toughness": 80, "hardness": 2, "min_tier": 1, "stone": [1, 2], "iron_chance": 1.0, "iron": [2, 3] },
]

## Chọn loại cây theo một số ngẫu nhiên [0,1) (cố định theo vị trí trong map).
static func pick_tree_kind(r: float) -> Dictionary:
	if r < 0.30: return TREE_KINDS[0]
	if r < 0.85: return TREE_KINDS[1]
	return TREE_KINDS[2]

static func pick_rock_kind(r: float, small: bool) -> Dictionary:
	if small: return ROCK_KINDS[0]
	if r < 0.78: return ROCK_KINDS[1]
	return ROCK_KINDS[2]

# ------------------------------------------------------------------
# TRANG BỊ
# ------------------------------------------------------------------
static func default_loadout() -> Dictionary:
	var out := {}
	for k in SLOT_KEYS:
		out[k] = { "tier": 0, "durability": TIER_STATS[0].durability }
	return out

static func item_name(slot: int, tier: int) -> String:
	return "%s %s" % [SLOT_NAMES[slot], TIER_NAMES[clampi(tier, 0, MAX_TIER)]]

static func is_broken(item: Dictionary) -> bool:
	return int(item.get("durability", 0)) <= 0

static func stats_for(item: Dictionary) -> Dictionary:
	if is_broken(item):
		return BROKEN_STATS
	return TIER_STATS[clampi(int(item.get("tier", 0)), 0, MAX_TIER)]

static func max_durability(tier: int) -> int:
	return int(TIER_STATS[clampi(tier, 0, MAX_TIER)].durability)

## Số nhát cần để phá vật liệu có độ cứng `toughness` với công cụ `item`.
static func hits_needed(item: Dictionary, toughness: int) -> int:
	return ceili(float(toughness) / float(stats_for(item).power))

## Thời gian (giây) để khai thác xong — chỉ để hiển thị/test.
static func time_to_harvest(item: Dictionary, toughness: int) -> float:
	return hits_needed(item, toughness) * float(stats_for(item).swing)

## Có thể khai thác vật liệu yêu cầu bậc `min_tier` không? (công cụ gãy coi như bậc -1)
static func can_harvest(item: Dictionary, min_tier: int) -> bool:
	var t := -1 if is_broken(item) else int(item.get("tier", 0))
	return t >= min_tier

## Trừ độ bền sau 1 nhát trúng. Trả về true nếu công cụ VỪA gãy.
static func apply_wear(item: Dictionary, hardness: int) -> bool:
	if is_broken(item):
		return false
	item["durability"] = maxi(0, int(item.durability) - (1 + hardness))
	return int(item.durability) == 0

static func craft_cost(slot: int, tier: int) -> Dictionary:
	var c: Dictionary = CRAFT_COST[clampi(tier, 0, MAX_TIER)].duplicate()
	if slot == Slot.SWORD:
		c["bone"] = 1 + tier
	return c

## Sửa về đầy độ bền: tốn 3 nguyên liệu chính của bậc đó (Gỗ / Đá / Sắt).
static func repair_cost(tier: int) -> Dictionary:
	match clampi(tier, 0, MAX_TIER):
		0: return { "wood": 3 }
		1: return { "stone": 3 }
	return { "iron": 3 }
