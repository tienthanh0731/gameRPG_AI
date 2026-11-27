extends Node
## QuestSystem — nhiệm vụ ngày (Spec §8). Mỗi ngày 3 nhiệm vụ ngẫu nhiên (cố định
## theo nhân vật + ngày), hoàn thành mỗi cái +20 SP (Spec §6). Reset khi sang ngày.
## Chỉ logic; UI là QuestTracker (nghe EventBus.quest_updated).

const QUESTS_PER_DAY: int = 3
const SP_REWARD: int = 20
## Nhiệm vụ tuần: gắn với Account (không mất khi chết), reset thứ Hai 0h.
## Thưởng Điểm Mùa (Season Pass), không phải SP ngày → không ảnh hưởng xếp hạng ngày.
const WEEKLY_PER_WEEK: int = 3
const WEEKLY_SEASON_POINTS: int = 60

func _ready() -> void:
	EventBus.enemy_killed.connect(func(_t, _e, _p): progress("kill", 1))
	EventBus.resource_gathered.connect(_on_gathered)
	EventBus.dungeon_cleared.connect(func(_n, _r): progress("dungeon", 1))
	EventBus.structure_placed.connect(func(_t, _p): progress("build", 1))
	EventBus.structure_upgraded.connect(func(_t, _p): progress("upgrade", 1))
	EventBus.day_started.connect(func(_d): EventBus.quest_updated.emit(get_today_quests()))
	EventBus.raid_wave_cleared.connect(func(_d): progress_weekly("nights", 1))
	EventBus.world_boss_defeated.connect(func(_d): progress_weekly("boss", 1))

func _on_gathered(key: String, amount: int) -> void:
	if key == "wood" or key == "stone":
		progress(key, amount)
	if key == "iron":
		progress_weekly("iron", amount)

## Mẫu nhiệm vụ: type, mô tả, mục tiêu theo ngày d, ngày tối thiểu.
static func _templates(d: int) -> Array:
	return [
		{ "type": "kill", "desc": "Hạ %d dã thú", "target": mini(4 + d / 2, 20), "min_day": 1 },
		{ "type": "wood", "desc": "Thu thập %d Gỗ", "target": mini(15 + 2 * d, 60), "min_day": 1 },
		{ "type": "stone", "desc": "Thu thập %d Đá", "target": mini(8 + d, 40), "min_day": 1 },
		{ "type": "dungeon", "desc": "Hoàn thành %d phó bản", "target": 1, "min_day": 1 },
		{ "type": "build", "desc": "Xây %d công trình", "target": 2 + d / 5, "min_day": 1 },
		{ "type": "upgrade", "desc": "Nâng cấp %d công trình", "target": 1, "min_day": 2 },
	]

static func generate(char_id: String, day: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|quest|%d" % [char_id, day])
	var pool: Array = []
	for t in _templates(day):
		if day >= int(t.min_day):
			pool.append(t)
	var out: Array = []
	for i in mini(QUESTS_PER_DAY, pool.size()):
		var t: Dictionary = pool.pop_at(rng.randi() % pool.size())
		out.append({
			"id": "Q%d_%s" % [day, t.type],
			"type": t.type,
			"desc": t.desc % t.target,
			"target": int(t.target),
			"progress": 0,
			"done": false,
		})
	return out

## Danh sách nhiệm vụ hôm nay (tự sinh mới khi sang ngày).
func get_today_quests() -> Array:
	if not SaveSystem.has_active_character():
		return []
	var c := SaveSystem.character_data
	var q: Dictionary = c.get("quests", {})
	if int(q.get("day", 0)) != GameState.current_day or not q.has("list"):
		q = { "day": GameState.current_day, "list": generate(str(c.get("char_id", "")), GameState.current_day) }
		c["quests"] = q
	return q["list"]

func progress(type: String, amount: int) -> void:
	if amount <= 0 or GameState.is_dead or not SaveSystem.has_active_character():
		return
	var changed := false
	for quest in get_today_quests():
		if quest.type != type or quest.done:
			continue
		quest.progress = mini(int(quest.progress) + amount, int(quest.target))
		changed = true
		if quest.progress >= quest.target:
			quest.done = true
			GameState.add_sp(SP_REWARD, "Nhiệm vụ ngày: " + str(quest.desc))
			EventBus.quest_completed.emit(quest)
	if changed:
		EventBus.quest_updated.emit(get_today_quests())
	# Các loại trùng tên cũng tính cho nhiệm vụ tuần
	if type in ["kill", "dungeon", "upgrade"]:
		progress_weekly(type, amount)

# ==========================================
# NHIỆM VỤ TUẦN
# ==========================================
const WEEKLY_TEMPLATES: Array[Dictionary] = [
	{ "type": "kill", "desc": "Hạ %d dã thú trong tuần", "target": 60 },
	{ "type": "dungeon", "desc": "Hoàn thành %d phó bản", "target": 5 },
	{ "type": "upgrade", "desc": "Nâng cấp %d công trình", "target": 4 },
	{ "type": "nights", "desc": "Sống sót qua %d đêm thú triều", "target": 4 },
	{ "type": "boss", "desc": "Hạ %d Thú Vương (World Boss)", "target": 1 },
	{ "type": "iron", "desc": "Khai thác %d Quặng Sắt", "target": 25 },
]

static func generate_weekly(account_id: String, week: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|week|%d" % [account_id, week])
	var pool: Array = WEEKLY_TEMPLATES.duplicate(true)
	var out: Array = []
	for i in WEEKLY_PER_WEEK:
		var t: Dictionary = pool.pop_at(rng.randi() % pool.size())
		out.append({ "id": "W%d_%s" % [week, t.type], "type": t.type, "desc": t.desc % t.target,
			"target": int(t.target), "progress": 0, "done": false })
	return out

func get_weekly_quests() -> Array:
	var acc := SaveSystem.account_data
	var week := SeasonSystem.week_id()
	var w: Dictionary = acc.get("weekly_quests", {})
	if int(w.get("week", -1)) != week or not w.has("list"):
		w = { "week": week, "list": generate_weekly(str(acc.get("account_id", "")), week) }
		acc["weekly_quests"] = w
	return w["list"]

func progress_weekly(type: String, amount: int) -> void:
	if amount <= 0 or GameState.is_dead:
		return
	var changed := false
	for q in get_weekly_quests():
		if q.type != type or q.done:
			continue
		q.progress = mini(int(q.progress) + amount, int(q.target))
		changed = true
		if q.progress >= q.target:
			q.done = true
			var acc := SaveSystem.account_data
			acc["season_sp"] = int(acc.get("season_sp", 0)) + WEEKLY_SEASON_POINTS
			EventBus.quest_completed.emit(q)
	if changed:
		SaveSystem.save_account()
		EventBus.weekly_quest_updated.emit(get_weekly_quests())
