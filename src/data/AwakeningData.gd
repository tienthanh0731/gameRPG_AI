class_name AwakeningData
extends RefCounted

const TalentData = preload("res://src/data/TalentData.gd")

# LINE 1: SURVIVAL & GATHERING
const LINE_GATHERING = [
	"f_hardworking",
	"d_herbalist",
	"c_wind_walker",
	"b_earth_lord",
	"a_wood_spirit",
	"s_phoenix_rebirth",
	"sss_immortal"
]

# LINE 2: COMBAT & STRENGTH
const LINE_COMBAT = [
	"f_strong_back",
	"d_survivalist",
	"c_hunter_eye",
	"b_iron_skin",
	"a_beast_blood",
	"s_sword_domain",
	"sss_primordial_overlord"
]

# ==========================================
# THIÊN PHÚ PHỤ (TỪ NGÀY 15)
# ==========================================
static func can_awaken_sub_talent(char_data: Dictionary, current_day: int) -> bool:
	if current_day < 15:
		return false
	var sub = char_data.get("sub_talent", {})
	return sub.is_empty()

static func awaken_sub_talent(char_data: Dictionary, current_day: int) -> Dictionary:
	var out = char_data.duplicate(true)
	if not can_awaken_sub_talent(out, current_day):
		return out
		
	var rolled_sub = TalentData.roll_talent()
	out["sub_talent"] = rolled_sub
	out["sub_talent_unlocked_day"] = current_day
	return out

# ==========================================
# GIÁC NGỘ (NÂNG BẬC CÙNG DÒNG)
# ==========================================
static func get_talent_line(talent_id: String) -> Array:
	if talent_id in LINE_GATHERING:
		return LINE_GATHERING
	return LINE_COMBAT

static func get_next_talent_in_line(talent_id: String) -> Dictionary:
	var line = get_talent_line(talent_id)
	var idx = line.find(talent_id)
	if idx == -1:
		idx = 0
	if idx + 1 >= line.size():
		return {} # Already at SSS max tier
		
	var next_id = line[idx + 1]
	# Search in catalog
	for rank in TalentData.TALENT_CATALOG.keys():
		for t in TalentData.TALENT_CATALOG[rank]:
			if t.get("id") == next_id:
				var found = t.duplicate(true)
				found["rank"] = rank
				found["rank_str"] = TalentData.RANK_NAMES[rank]
				found["color_hex"] = TalentData.RANK_COLORS[rank].to_html()
				return found
	return {}

static func get_enlightenment_challenge(talent: Dictionary) -> Dictionary:
	var rank = talent.get("rank", TalentData.Rank.F)
	match rank:
		TalentData.Rank.F:
			return {
				"type": "MONSTER_KILLS",
				"target": 15,
				"desc": "Hạ gục 15 Dã Thú Hoang Cổ",
				"next_rank_str": "D"
			}
		TalentData.Rank.D:
			return {
				"type": "SURVIVAL_DAYS",
				"target": 5,
				"desc": "Sống sót an toàn qua Ngày 5",
				"next_rank_str": "C"
			}
		TalentData.Rank.C:
			return {
				"type": "DUNGEON_CLEARS",
				"target": 2,
				"desc": "Chinh phục 2 Phó Bản Tàn Tích",
				"next_rank_str": "B"
			}
		TalentData.Rank.B:
			return {
				"type": "MONSTER_KILLS",
				"target": 60,
				"desc": "Hạ gục 60 Quái Vật Thú Triều",
				"next_rank_str": "A"
			}
		TalentData.Rank.A:
			return {
				"type": "SURVIVAL_DAYS",
				"target": 15,
				"desc": "Sống sót tới Mốc Ngày 15",
				"next_rank_str": "S"
			}
		TalentData.Rank.S:
			return {
				"type": "WORLD_BOSS_DEFEAT",
				"target": 1,
				"desc": "Chém giết 1 Thái Cổ Thú Vương (World Boss)",
				"next_rank_str": "SSS"
			}
		TalentData.Rank.SSS:
			return {
				"type": "MAXED",
				"target": 0,
				"desc": "Đã đạt cực hạn Cổ Thần (Bậc SSS)",
				"next_rank_str": ""
			}
	return {"type": "UNKNOWN", "target": 0, "desc": "Không có thử thách"}

static func check_enlightenment_progress(char_data: Dictionary, slot: String = "talent") -> Dictionary:
	var talent = char_data.get(slot, {})
	if talent.is_empty():
		return { "completed": false, "progress": 0, "target": 1, "percent": 0.0, "desc": "Chưa có thiên phú" }
		
	var chal = get_enlightenment_challenge(talent)
	if chal["type"] == "MAXED":
		return { "completed": false, "is_maxed": true, "progress": 1, "target": 1, "percent": 1.0, "desc": chal["desc"] }
		
	var progress = 0
	var target = chal["target"]
	match chal["type"]:
		"MONSTER_KILLS":
			progress = char_data.get("monsters_killed", 0)
		"SURVIVAL_DAYS":
			progress = char_data.get("day", 1)
		"DUNGEON_CLEARS":
			progress = char_data.get("dungeons_cleared", 0)
		"WORLD_BOSS_DEFEAT":
			progress = char_data.get("world_bosses_defeated", 0)
			
	var completed = progress >= target
	var pct = clamp(float(progress) / float(max(1, target)), 0.0, 1.0)
	
	return {
		"completed": completed,
		"is_maxed": false,
		"progress": progress,
		"target": target,
		"percent": pct,
		"challenge": chal
	}

static func promote_talent(char_data: Dictionary, slot: String = "talent") -> Dictionary:
	var out = char_data.duplicate(true)
	var prog = check_enlightenment_progress(out, slot)
	if not prog.get("completed", false):
		return out # Progress not yet complete
		
	var cur_talent = out.get(slot, {})
	var next_talent = get_next_talent_in_line(cur_talent.get("id", ""))
	if next_talent.is_empty():
		return out
		
	out[slot] = next_talent
	out["enlightenment_count"] = out.get("enlightenment_count", 0) + 1
	return out
