extends Node
## QuestSystem — nhiệm vụ ngày (Spec §8). Mỗi ngày 3 nhiệm vụ ngẫu nhiên (cố định
## theo nhân vật + ngày), hoàn thành mỗi cái +20 SP (Spec §6). Reset khi sang ngày.
## Chỉ logic; UI là QuestTracker (nghe EventBus.quest_updated).

const QUESTS_PER_DAY: int = 3
const SP_REWARD: int = 20

func _ready() -> void:
	EventBus.enemy_killed.connect(func(_t, _e, _p): progress("kill", 1))
	EventBus.resource_gathered.connect(_on_gathered)
	EventBus.dungeon_cleared.connect(func(_n, _r): progress("dungeon", 1))
	EventBus.structure_placed.connect(func(_t, _p): progress("build", 1))
	EventBus.structure_upgraded.connect(func(_t, _p): progress("upgrade", 1))
	EventBus.day_started.connect(func(_d): EventBus.quest_updated.emit(get_today_quests()))

func _on_gathered(key: String, amount: int) -> void:
	if key == "wood" or key == "stone":
		progress(key, amount)

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
