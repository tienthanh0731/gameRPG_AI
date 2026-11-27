extends Node
## Test headless cho logic lõi Phase 1.
## Chạy:  godot.exe --headless --path . res://tests/test_phase1.tscn
## Sao lưu & khôi phục save thật của người chơi trước/sau khi test.

const TalentData = preload("res://src/data/TalentData.gd")

var failures: int = 0
var passes: int = 0
var backups: Dictionary = {}

func check(cond: bool, msg: String) -> void:
	if cond:
		passes += 1
	else:
		failures += 1
		printerr("  FAIL: ", msg)

func _ready() -> void:
	_backup()
	_test_scaling()
	_test_talent_distribution()
	_test_ranking_tiers()
	_test_pending_talent_is_sticky()
	_test_sp_and_day_end()
	_test_reroll_once()
	_test_structure_upgrade()
	_test_daily_quests()
	_test_outpost_income_and_unclaimed()
	_test_permadeath_atomic()
	_test_death_journal_recovery()
	_test_leaderboard_paging()
	_restore()
	print("\n=== Phase 1 tests: %d passed, %d failed ===" % [passes, failures])
	get_tree().quit(1 if failures > 0 else 0)

# ------------------------------------------------------------------
func _backup() -> void:
	for p in [SaveSystem.ACCOUNT_PATH, SaveSystem.CHARACTER_PATH, SaveSystem.DEATH_JOURNAL_PATH]:
		if FileAccess.file_exists(p):
			backups[p] = FileAccess.get_file_as_string(p)
	SaveSystem.account_data = SaveSystem._get_default_account()
	SaveSystem.account_data["account_id"] = "ACC_TEST"
	SaveSystem.character_data = {}

func _restore() -> void:
	for p in [SaveSystem.ACCOUNT_PATH, SaveSystem.CHARACTER_PATH, SaveSystem.DEATH_JOURNAL_PATH]:
		SaveSystem._delete(p)
		if backups.has(p):
			var f = FileAccess.open(p, FileAccess.WRITE)
			f.store_string(backups[p])

# ------------------------------------------------------------------
func _test_scaling() -> void:
	print("scaling M(d)/W(d)/N(d)")
	check(is_equal_approx(GameState.get_monster_power_mult(1), 1.16), "M(1)=1.16")
	check(is_equal_approx(GameState.get_monster_power_mult(100), 1.0 + 1.5 + 1.0), "M(100)=3.5")
	check(GameState.get_raid_wave_size(1) == 8, "W(1)=8")
	check(GameState.get_raid_wave_size(9) == 11, "W(9)=11")
	check(GameState.get_raid_wave_size(500) == 40, "W cap 40")
	check(GameState.get_dungeon_count(1) == 3, "N(1)=3")
	check(GameState.get_dungeon_count(12) == 5, "N(12)=5")
	check(GameState.get_dungeon_count(100) == 10, "N cap 10")
	check(not GameState.is_real_tide(5) and GameState.is_real_tide(6), "real tide from day 6")
	check(GameState.get_tonight_wave_size(3) == 3, "scout wave day 3 = W/3")
	check(GameState.get_tonight_wave_size(6) == 10, "full wave day 6")
	check(GameState.get_elite_chance(15) == 0.0 and GameState.get_elite_chance(16) > 0.0, "elites from day 16")

func _test_talent_distribution() -> void:
	print("talent roll distribution")
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	var counts = {}
	var n = 200000
	for i in n:
		var r: int = TalentData.roll_rank_with(rng)
		counts[r] = counts.get(r, 0) + 1
	var expected = { 0: 45.0, 1: 25.0, 2: 15.0, 3: 8.0, 4: 4.5, 5: 2.0, 6: 0.5 }
	for r in expected:
		var pct = 100.0 * counts.get(r, 0) / n
		check(absf(pct - expected[r]) < 0.4, "rank %d ≈ %.1f%% (got %.2f%%)" % [r, expected[r], pct])

func _test_ranking_tiers() -> void:
	print("day-end ranking tiers")
	check(ServerSim.tier_for(0, 1.0) == "NONE", "SP=0 → no reward even if top")
	check(ServerSim.tier_for(10, 0.5) == "LEGENDARY", "top 1%")
	check(ServerSim.tier_for(10, 7.0) == "RARE", "top 10%")
	check(ServerSim.tier_for(10, 40.0) == "NORMAL", "top 50%")
	check(ServerSim.tier_for(10, 80.0) == "PARTICIPATION", "rest")
	var high = ServerSim.rank_day(3, 100000)
	check(high.rank == 1 and high.tier == "LEGENDARY", "huge SP ranks #1")
	var zero = ServerSim.rank_day(3, 0)
	check(zero.tier == "NONE" and zero.chest.items.is_empty(), "SP 0 → no chest")
	check(ServerSim.rank_day(3, 50).rank == ServerSim.rank_day(3, 50).rank, "deterministic per day")
	var has_pill = false
	for it in ServerSim.chest_for("LEGENDARY").items:
		has_pill = has_pill or it.name == "Đan Reroll Thiên Phú"
	check(has_pill, "legendary chest has reroll pill")

func _test_pending_talent_is_sticky() -> void:
	print("talent rolled once by authority")
	var a = ServerSim.get_or_roll_pending_talent()
	var b = ServerSim.get_or_roll_pending_talent()
	check(a.id == b.id and a.rank == b.rank, "second call returns same pending talent")
	var c = ServerSim.consume_pending_talent()
	check(c.id == a.id and not ServerSim.has_pending_talent(), "consume clears pending")
	SaveSystem.create_new_character("Tester", c)
	GameState.load_from_character()
	check(SaveSystem.has_active_character(), "character created")

func _test_sp_and_day_end() -> void:
	print("SP + day end")
	var season_before = int(SaveSystem.account_data.season_sp)
	GameState.add_sp(5, "test")
	EventBus.enemy_killed.emit("x", true, Vector2.ZERO)  # +10
	EventBus.enemy_killed.emit("x", false, Vector2.ZERO) # +1
	GameState.begin_raid(10)
	for i in 5:
		GameState.register_raid_kill()
	GameState.finish_raid() # +50 +20
	check(GameState.today_sp == 86, "SP sum 5+10+1+50+20 = 86 (got %d)" % GameState.today_sp)
	var day_before = GameState.current_day
	var s = GameState.evaluate_day_end()
	check(s.today_sp == 86 and s.rank >= 1, "summary has SP + rank")
	check(GameState.current_day == day_before + 1 and GameState.today_sp == 0, "day advanced, SP reset")
	check(int(SaveSystem.account_data.season_sp) == season_before + 86, "day SP committed to account season")
	var reloaded = SaveSystem._read_json(SaveSystem.CHARACTER_PATH)
	check(reloaded is Dictionary and int(reloaded.day) == day_before + 1, "day persisted to disk")
	# dungeons/day stable & clear only once
	var list = GameState.get_today_dungeons(Vector2.ZERO)
	check(list.size() == GameState.get_dungeon_count(), "N(d) dungeons generated")
	check(GameState.get_today_dungeons(Vector2.ZERO)[0].id == list[0].id, "dungeon list stable within day")
	var sp0 = GameState.today_sp
	check(GameState.mark_dungeon_cleared(list[0].id), "clear dungeon")
	check(not GameState.mark_dungeon_cleared(list[0].id), "cannot clear twice")
	check(GameState.today_sp == sp0 + 30, "+30 SP exactly once")

func _test_reroll_once() -> void:
	print("reroll pill")
	SaveSystem.character_data.inventory.reroll_pill = 0
	check(ServerSim.use_reroll_pill().is_empty(), "no pill → refused")
	SaveSystem.character_data.inventory.reroll_pill = 2
	check(not ServerSim.use_reroll_pill().is_empty(), "pill → reroll ok")
	check(ServerSim.use_reroll_pill().is_empty(), "second reroll refused (1 per character)")
	check(int(SaveSystem.character_data.inventory.reroll_pill) == 1, "only one pill consumed")

func _test_permadeath_atomic() -> void:
	print("permadeath")
	GameState.current_day = 7
	var games = int(SaveSystem.account_data.total_games_played)
	var r1 = GameState.handle_player_death()
	var r2 = GameState.handle_player_death() # bắn lần 2 không được tính
	check(r1.record_broken and r1.new_record == 7, "record 7 days saved")
	check(int(SaveSystem.account_data.total_games_played) == games + 1, "death counted once")
	check(not SaveSystem.has_active_character(), "character wiped in memory")
	check(not FileAccess.file_exists(SaveSystem.CHARACTER_PATH), "character file deleted")
	check(not FileAccess.file_exists(SaveSystem.DEATH_JOURNAL_PATH), "journal committed")
	check(r2.day_survived == 7, "second call returns same summary")
	var acc = SaveSystem._read_json(SaveSystem.ACCOUNT_PATH)
	check(int(acc.highest_day_record) == 7, "account record persisted on disk")
	check("Người Sống Sót Hoang Cổ" in acc.titles, "title unlocked")
	SaveSystem.character_data = {}
	SaveSystem.save_character({ "is_alive": false })
	check(not FileAccess.file_exists(SaveSystem.CHARACTER_PATH), "dead character never re-saved")

func _test_death_journal_recovery() -> void:
	print("journal recovery (crash mid-permadeath)")
	ServerSim.get_or_roll_pending_talent()
	SaveSystem.create_new_character("Crashy", ServerSim.consume_pending_talent())
	var games = int(SaveSystem.account_data.total_games_played)
	# Giả lập crash: journal đã ghi, nhưng chưa cập nhật account / xóa nhân vật
	SaveSystem._write_json_atomic(SaveSystem.DEATH_JOURNAL_PATH, {
		"char_id": SaveSystem.character_data.char_id, "char_name": "Crashy",
		"day_survived": 30, "sp_earned": 999, "talent": {} })
	SaveSystem._recover_death_journal()
	check(not FileAccess.file_exists(SaveSystem.CHARACTER_PATH), "character deleted on recovery")
	check(int(SaveSystem.account_data.highest_day_record) == 30, "record applied on recovery")
	check(int(SaveSystem.account_data.total_games_played) == games + 1, "counted once")
	# Replay lần 2 (idempotent)
	SaveSystem._write_json_atomic(SaveSystem.DEATH_JOURNAL_PATH, {
		"char_id": SaveSystem.account_data.processed_deaths[-1], "day_survived": 30, "talent": {} })
	SaveSystem._recover_death_journal()
	check(int(SaveSystem.account_data.total_games_played) == games + 1, "replay is idempotent")

func _test_leaderboard_paging() -> void:
	print("leaderboard paging")
	for b in 5:
		var p0 = ServerSim.get_board_page(b, 0)
		check(p0.entries.size() <= ServerSim.PAGE_SIZE, "board %d page size" % b)
		if p0.page_count > 1:
			var p1 = ServerSim.get_board_page(b, 1)
			check(p1.entries[0].rank == ServerSim.PAGE_SIZE + 1, "board %d page 2 starts at 11" % b)
	var surv = ServerSim.get_board_page(ServerSim.Board.SURVIVAL, 0)
	check(surv.self_rank > 0, "self appears on survival board")
	var page = ServerSim.get_board_page(ServerSim.Board.SURVIVAL, ServerSim.page_of_rank(surv.self_rank))
	var found = false
	for e in page.entries:
		found = found or e.is_self
	check(found, "jump-to-self page contains self")

func _test_structure_upgrade() -> void:
	print("structure upgrade wood -> stone -> iron")
	var wall = load("res://src/world/structures/WoodenWall.tscn").instantiate()
	add_child(wall)
	var base_hp: int = wall.max_health
	check(wall.tier == 0 and wall.can_upgrade(), "starts wood, upgradable")
	wall.take_damage(10)
	wall.set_tier(1, true)
	check(wall.max_health == int(round(base_hp * 2.5)), "stone = x2.5 HP")
	check(wall.current_health < wall.max_health, "keeps damage ratio")
	wall.set_tier(2, true)
	check(wall.max_health == base_hp * 5 and not wall.can_upgrade(), "iron = x5 HP, max tier")
	check(wall.get_upgrade_cost().is_empty(), "no cost at max tier")
	# Thông qua BuildingManager: trừ nguyên liệu + 15 SP
	var bm = load("res://src/world/BuildingManager.gd").new()
	add_child(bm)
	var inv = load("res://src/core/Inventory.gd").new()
	add_child(inv)
	bm.inventory = inv
	var wall2 = load("res://src/world/structures/WoodenWall.tscn").instantiate()
	add_child(wall2)
	check(not bm.upgrade_structure(wall2), "refused without stone")
	inv.stone = 6
	var sp0 = GameState.today_sp
	check(bm.upgrade_structure(wall2), "upgrade with 6 stone")
	check(inv.stone == 0 and wall2.tier == 1, "stone consumed, tier 1")
	check(GameState.today_sp == sp0 + 15, "+15 SP for upgrade")
	for n in [wall, wall2, bm, inv]:
		n.queue_free()

func _test_daily_quests() -> void:
	print("daily quests")
	var q1 = QuestSystem.generate("CHR_X", 5)
	var q2 = QuestSystem.generate("CHR_X", 5)
	check(q1.size() == 3, "3 quests/day")
	check(q1[0].type == q2[0].type and q1[1].type == q2[1].type, "deterministic per char+day")
	var types = {}
	for q in q1:
		types[q.type] = true
	check(types.size() == 3, "distinct quest types")
	check(not "upgrade" in QuestSystem.generate("CHR_Y", 1).map(func(q): return q.type), "no upgrade quest on day 1")
	SaveSystem.character_data.erase("quests")
	var today = QuestSystem.get_today_quests()
	var q = today[0]
	var sp0 = GameState.today_sp
	QuestSystem.progress(q.type, q.target - 1)
	check(not q.done and GameState.today_sp == sp0, "not done before target")
	QuestSystem.progress(q.type, 5)
	check(q.done and q.progress == q.target, "done at target (capped)")
	check(GameState.today_sp == sp0 + 20, "+20 SP once")
	QuestSystem.progress(q.type, 5)
	check(GameState.today_sp == sp0 + 20, "no double reward")
	# Rương thưởng không tính vào nhiệm vụ thu thập
	SaveSystem.character_data["quests"] = { "day": GameState.current_day, "list": [
		{ "id": "t", "type": "wood", "desc": "x", "target": 50, "progress": 0, "done": false } ] }
	var inv = load("res://src/core/Inventory.gd").new()
	add_child(inv)
	GameState.granting_rewards = true
	inv.add_resource("Gỗ", 30)
	GameState.granting_rewards = false
	check(QuestSystem.get_today_quests()[0].progress == 0, "chest rewards don't count")
	inv.add_resource("Gỗ", 7)
	check(QuestSystem.get_today_quests()[0].progress == 7, "real gathering counts")
	inv.queue_free()
	var old_day = GameState.current_day
	GameState.current_day += 1
	check(QuestSystem.get_today_quests()[0].id.begins_with("Q%d" % GameState.current_day), "new quests next day")
	GameState.current_day = old_day

func _test_outpost_income_and_unclaimed() -> void:
	print("outpost income + unclaimed chest")
	SaveSystem.character_data["captured_outposts"] = []
	check(GameState.get_outpost_income().is_empty(), "no outposts → no income")
	SaveSystem.character_data["captured_outposts"] = ["A", "B"]
	var inc = GameState.get_outpost_income()
	var wood = 0
	for it in inc:
		if it.name == "Gỗ":
			wood = it.amount
	check(wood == 16, "2 outposts → 16 wood")
	GameState.add_sp(5, "t")
	var s = GameState.evaluate_day_end()
	var saved = SaveSystem._read_json(SaveSystem.CHARACTER_PATH)
	check(saved.has("unclaimed_rewards") and saved.unclaimed_rewards.size() == s.chest.items.size(), "chest persisted before popup")
	check(s.chest.items.size() >= 3, "income merged into chest")
	var taken = GameState.take_unclaimed_rewards()
	check(taken.size() == s.chest.items.size() and GameState.take_unclaimed_rewards().is_empty(), "claimed exactly once")
	SaveSystem.character_data["captured_outposts"] = []
