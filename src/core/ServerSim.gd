extends Node
## ServerSim — "máy chủ authoritative" giả lập chạy local cho Phase 1.
##
## Mọi quyết định mà ở Phase 2 thuộc về Game Server đều đi qua đây:
##   - Roll Thiên Phú (client UI KHÔNG tự roll)
##   - Dùng Đan Reroll
##   - Xếp hạng SP cuối ngày theo phần trăm toàn server
##   - Dữ liệu 5 bảng xếp hạng (phân trang)
## Ở Phase 2 chỉ cần thay phần thân các hàm này bằng request tới Gateway/Game Server,
## giữ nguyên chữ ký hàm để UI/logic không phải sửa.

const TalentData = preload("res://src/data/TalentData.gd")
const AwakeningData = preload("res://src/data/AwakeningData.gd")

## Số "người chơi khác" giả lập trên server (không tính bản thân).
const SIM_POPULATION: int = 199
const PAGE_SIZE: int = 10

enum Board { SURVIVAL, COMBAT, TERRITORY, ALLIANCE, RARE_TALENT }

const BOT_NAMES: Array[String] = [
	"Bắc Đẩu", "Vô Nhai", "Tiêu Dao", "Trấn Nam", "Dạ Hành", "Thiết Quyền", "Hắc Phong",
	"Thanh Vân", "Lạc Nhật", "Huyền Vũ", "Bạch Hổ", "Chu Tước", "Thanh Long", "Cổ Nguyệt",
	"Lăng Thiên", "Phong Vân", "Lôi Đình", "Tử Điện", "Hàn Băng", "Liệt Hỏa",
]
const BOT_SUFFIX: Array[String] = [
	"Ma Quân", "Kiếm Thánh", "Đạo Nhân", "Vương", "Khách", "Thợ Săn", "Lãng Tử", "Tán Nhân",
]
const GUILD_NAMES: Array[String] = [
	"[THIÊN HẠ]", "[TIÊU DAO]", "[HOANG CỔ]", "[VẠN TIÊN]", "[HẮC PHONG]", "[LONG MÔN]",
	"[BẠCH VÂN]", "[HUYỀN THIÊN]", "[TINH HÀ]", "[LIỆT DIỄM]", "[CỬU U]", "[THANH SƠN]",
]

# ==========================================
# THIÊN PHÚ — ROLL PHÍA "SERVER"
# ==========================================
## Trả về thiên phú đang chờ của account. Nếu chưa có thì roll MỘT lần và lưu lại,
## nên tắt game/mở lại cũng không roll lại được.
func get_or_roll_pending_talent() -> Dictionary:
	var pending: Dictionary = SaveSystem.account_data.get("pending_talent", {})
	if pending.is_empty():
		pending = TalentData.roll_talent()
		SaveSystem.account_data["pending_talent"] = pending
		SaveSystem.save_account()
	return pending

func has_pending_talent() -> bool:
	return not SaveSystem.account_data.get("pending_talent", {}).is_empty()

## Tiêu thụ thiên phú đang chờ khi tạo nhân vật.
func consume_pending_talent() -> Dictionary:
	var t: Dictionary = SaveSystem.account_data.get("pending_talent", {})
	SaveSystem.account_data.erase("pending_talent")
	SaveSystem.save_account()
	return t

## Dùng Đan Reroll: mỗi nhân vật chỉ reroll được 1 lần, phải có đan trong túi.
## Trả về {} nếu bị từ chối.
func use_reroll_pill() -> Dictionary:
	var c: Dictionary = SaveSystem.character_data
	if c.is_empty() or c.get("rerolled", false):
		return {}
	var inv: Dictionary = c.get("inventory", {})
	if int(inv.get("reroll_pill", 0)) <= 0:
		return {}
	inv["reroll_pill"] = int(inv["reroll_pill"]) - 1
	var new_talent := TalentData.roll_talent()
	c["inventory"] = inv
	c["talent"] = new_talent
	c["rerolled"] = true
	SaveSystem.save_character(c)
	return new_talent

## Thức tỉnh Thiên Phú Phụ (từ ngày 15, 1 lần). Trả về thiên phú phụ, {} nếu bị từ chối.
func awaken_sub_talent() -> Dictionary:
	var c: Dictionary = SaveSystem.character_data
	if c.is_empty() or not AwakeningData.can_awaken_sub_talent(c, GameState.current_day):
		return {}
	var out: Dictionary = AwakeningData.awaken_sub_talent(c, GameState.current_day)
	c["sub_talent"] = out.get("sub_talent", {})
	c["sub_talent_unlocked_day"] = GameState.current_day
	GameState.sub_talent = c.sub_talent
	SaveSystem.save_character(c)
	EventBus.talent_changed.emit(GameState.active_talent)
	return c.sub_talent

## Giác Ngộ: hoàn thành thử thách → lên bậc kế tiếp cùng dòng. slot: "talent" | "sub_talent"
func promote_talent(slot: String = "talent") -> Dictionary:
	var c: Dictionary = SaveSystem.character_data
	if c.is_empty():
		return {}
	c["day"] = GameState.current_day
	var before := str(c.get(slot, {}).get("id", ""))
	var out: Dictionary = AwakeningData.promote_talent(c, slot)
	var t: Dictionary = out.get(slot, {})
	if t.is_empty() or str(t.get("id", "")) == before:
		return {}
	c[slot] = t
	c["enlightenment_count"] = int(out.get("enlightenment_count", 0))
	if slot == "talent":
		GameState.active_talent = t
	else:
		GameState.sub_talent = t
	SaveSystem.save_character(c)
	EventBus.talent_changed.emit(GameState.active_talent)
	return t

# ==========================================
# DÂN SỐ SERVER GIẢ LẬP (deterministic theo account + ngày)
# ==========================================
func _rng_for(tag: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(SaveSystem.account_data.get("account_id", "ACC")) + "|" + tag)
	return rng

## SP trong ngày của 199 người chơi khác. ~15% offline (SP=0).
func simulated_daily_sp(day: int) -> Array[int]:
	var rng := _rng_for("daysp|%d" % day)
	var out: Array[int] = []
	for i in SIM_POPULATION:
		if rng.randf() < 0.15:
			out.append(0)
			continue
		# phần lớn quanh 40-90 SP, đuôi dài tới ~200
		var base := rng.randfn(62.0, 22.0)
		if rng.randf() < 0.06:
			base += rng.randf_range(60.0, 140.0)
		out.append(maxi(1, int(base)))
	return out

## Xếp hạng TOÀN BỘ người chơi theo SP ngày và trả về bậc thưởng (Spec §6).
func rank_day(day: int, my_sp: int) -> Dictionary:
	var all_sp := simulated_daily_sp(day)
	var better := 0
	for v in all_sp:
		if v > my_sp:
			better += 1
	var total := all_sp.size() + 1
	var rank := better + 1
	var pct := float(rank) / float(total) * 100.0
	var tier := tier_for(my_sp, pct)
	return {
		"rank": rank,
		"total": total,
		"percentile": pct,
		"tier": tier,
		"tier_label": tier_label(tier),
		"chest": chest_for(tier),
	}

static func tier_for(sp: int, percentile: float) -> String:
	if sp <= 0:
		return "NONE"
	if percentile <= 1.0:
		return "LEGENDARY"
	if percentile <= 10.0:
		return "RARE"
	if percentile <= 50.0:
		return "NORMAL"
	return "PARTICIPATION"

static func tier_label(tier: String) -> String:
	match tier:
		"LEGENDARY": return "Top 1% (Huyền Thoại)"
		"RARE": return "Top 10% (Hiếm)"
		"NORMAL": return "Top 50% (Thường)"
		"PARTICIPATION": return "Tham Gia"
		_: return "Offline (SP = 0)"

static func chest_for(tier: String) -> Dictionary:
	match tier:
		"LEGENDARY":
			return { "tier": tier, "title": "Thiên Kiêu Hoang Cổ", "items": [
				{ "name": "Đan Reroll Thiên Phú", "amount": 1 },
				{ "name": "Quặng Sắt", "amount": 15 },
				{ "name": "Đá", "amount": 25 },
				{ "name": "Gỗ", "amount": 40 },
				{ "name": "Thịt Rừng", "amount": 10 } ] }
		"RARE":
			return { "tier": tier, "items": [
				{ "name": "Quặng Sắt", "amount": 8 },
				{ "name": "Đá", "amount": 15 },
				{ "name": "Gỗ", "amount": 25 },
				{ "name": "Thịt Rừng", "amount": 5 } ] }
		"NORMAL":
			return { "tier": tier, "items": [
				{ "name": "Đá", "amount": 10 },
				{ "name": "Gỗ", "amount": 15 },
				{ "name": "Thịt Rừng", "amount": 3 } ] }
		"PARTICIPATION":
			return { "tier": tier, "items": [
				{ "name": "Gỗ", "amount": 8 },
				{ "name": "Đá", "amount": 5 } ] }
		_:
			return { "tier": "NONE", "items": [] }

# ==========================================
# BẢNG XẾP HẠNG (5 loại, phân trang)
# ==========================================
func _bot_name(rng: RandomNumberGenerator) -> String:
	return "%s %s" % [BOT_NAMES[rng.randi() % BOT_NAMES.size()], BOT_SUFFIX[rng.randi() % BOT_SUFFIX.size()]]

func _bot_rank_str(rng: RandomNumberGenerator) -> String:
	var r := TalentData.roll_rank_with(rng)
	return TalentData.RANK_NAMES[r]

## Toàn bộ BXH đã sắp xếp. Mỗi entry: {name, value(int), display, badge, is_self}
func build_board(board: int) -> Array:
	var rng := _rng_for("board|%d" % board)
	var acc := SaveSystem.account_data
	var ch := SaveSystem.character_data
	var alive := SaveSystem.has_active_character()
	var my_name := str(acc.get("survivor_name", "Bạn"))
	if alive:
		my_name = str(ch.get("name", my_name))
	var entries: Array = []
	var self_entry: Dictionary = {}

	match board:
		Board.SURVIVAL:
			for i in SIM_POPULATION:
				var d := int(clamp(rng.randfn(9.0, 7.0), 1, 60))
				entries.append({ "name": _bot_name(rng), "value": d, "badge": "[%s]" % _bot_rank_str(rng) })
			var best := int(acc.get("highest_day_record", 0))
			if alive:
				best = maxi(best, int(ch.get("day", 1)))
			self_entry = { "name": my_name, "value": best, "badge": "Bản thân" }
		Board.COMBAT:
			for i in SIM_POPULATION:
				entries.append({ "name": _bot_name(rng), "value": maxi(0, int(rng.randfn(70.0, 50.0))), "badge": "Tuần này" })
			self_entry = { "name": my_name, "value": int(acc.get("weekly_kills", 0)), "badge": "Bản thân" }
		Board.TERRITORY:
			for i in SIM_POPULATION:
				entries.append({ "name": _bot_name(rng), "value": maxi(0, int(rng.randfn(1.5, 1.6))), "badge": "Mùa này" })
			self_entry = { "name": my_name, "value": (1 + int(ch.get("outposts", 0))) if alive else 0, "badge": "Bản thân" }
		Board.ALLIANCE:
			for g in GUILD_NAMES:
				entries.append({ "name": g + " Liên Minh", "value": maxi(0, int(rng.randfn(5000.0, 3500.0))), "badge": "Mùa này" })
			var ap := int(acc.get("alliance_points", 0))
			if ap > 0:
				self_entry = { "name": my_name, "value": ap, "badge": "Điểm World Boss" }
		Board.RARE_TALENT:
			for i in SIM_POPULATION:
				var r := _bot_rank_str(rng)
				if r == "S" or r == "SSS":
					entries.append({ "name": _bot_name(rng), "value": 2 if r == "SSS" else 1, "badge": "[%s] Đang sống" % r })
			if alive:
				var my_r := str(ch.get("talent", {}).get("rank_str", "F"))
				if my_r == "S" or my_r == "SSS":
					self_entry = { "name": my_name, "value": 2 if my_r == "SSS" else 1, "badge": "[%s] Bản thân" % my_r }

	for e in entries:
		e["is_self"] = false
	if not self_entry.is_empty():
		self_entry["is_self"] = true
		self_entry["name"] += " (Bạn)"
		entries.append(self_entry)
	entries.sort_custom(func(a, b): return a.value > b.value or (a.value == b.value and a.is_self and not b.is_self))
	for i in entries.size():
		entries[i]["rank"] = i + 1
		entries[i]["display"] = _format_value(board, int(entries[i].value))
	return entries

static func _format_value(board: int, v: int) -> String:
	match board:
		Board.SURVIVAL: return "%d ngày" % v
		Board.COMBAT: return "%d quái" % v
		Board.TERRITORY: return "%d căn cứ" % v
		Board.ALLIANCE: return "%d điểm" % v
		Board.RARE_TALENT: return "SSS" if v == 2 else "S"
	return str(v)

## Trả về {entries (1 trang), page, page_count, self_rank (0 nếu không có)}
func get_board_page(board: int, page: int) -> Dictionary:
	var all := build_board(board)
	var page_count := maxi(1, ceili(float(all.size()) / PAGE_SIZE))
	page = clampi(page, 0, page_count - 1)
	var self_rank := 0
	for e in all:
		if e.is_self:
			self_rank = e.rank
	return {
		"entries": all.slice(page * PAGE_SIZE, (page + 1) * PAGE_SIZE),
		"page": page,
		"page_count": page_count,
		"self_rank": self_rank,
		"total": all.size(),
	}

func page_of_rank(rank: int) -> int:
	return maxi(0, (rank - 1) / PAGE_SIZE)
