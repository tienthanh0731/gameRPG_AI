extends Node
## Smoke test: tạo nhân vật → chạy Main → tua tới đêm (thú triều) → rạng đông (tổng kết)
## → vào phó bản → ra lại. Chỉ kiểm tra không có lỗi runtime & luồng hoạt động.
## Chạy: godot.exe --headless --path . res://tests/smoke_scenes.tscn

var backups: Dictionary = {}
var failures: int = 0

func _ready() -> void:
	for p in [SaveSystem.ACCOUNT_PATH, SaveSystem.CHARACTER_PATH]:
		if FileAccess.file_exists(p):
			backups[p] = FileAccess.get_file_as_string(p)
	_run.call_deferred()

func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		failures += 1

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true).timeout

func _run() -> void:
	var tree := get_tree()
	SaveSystem.create_new_character("Smoke", ServerSim.get_or_roll_pending_talent())
	ServerSim.consume_pending_talent()
	GameState.load_from_character()
	# Node test không phải current_scene nữa → sống sót qua các lần change_scene
	var m = load("res://src/world/Main.tscn").instantiate()
	tree.root.add_child(m)
	tree.current_scene = m
	await _wait(1.5)
	var main := tree.current_scene
	check(main != null and main.name == "Main", "Main loaded")
	check(main.dungeon_nodes.size() == GameState.get_dungeon_count(), "N(d) dungeon entrances spawned")

	# Bàn chế tạo: rèn Rìu Đá qua UI thật
	var craft = main.get_node("HUD/CraftingUI")
	var inv_n = main.player.get_node("Inventory")
	inv_n.wood = 20
	inv_n.stone = 20
	craft._load_category(0)
	var idx := -1
	for i in craft.filtered_recipes.size():
		if craft.filtered_recipes[i].get("id") == "axe_t1":
			idx = i
	check(idx >= 0, "stone axe recipe listed")
	craft._on_recipe_selected(idx)
	craft._on_btn_craft_pressed()
	check(main.player.equipment.axe.tier == 1, "crafted & equipped Rìu Đá")
	check(inv_n.stone == 14, "6 stone consumed")
	craft._on_recipe_selected(idx)
	check(craft.btn_craft.disabled, "cannot craft same tier again")

	# Tua tới hoàng hôn rồi đêm
	var dn = main.get_node("DayNightCycle")
	dn.current_time_hours = 17.1
	await _wait(0.3)
	dn.current_time_hours = 19.6
	await _wait(0.5)
	var raid = main.get_node("RaidManager")
	check(raid.active_beasts.size() > 0, "night raid spawned beasts (%d)" % raid.active_beasts.size())

	# Rạng đông → tổng kết
	var day_before := GameState.current_day
	dn.current_time_hours = 4.6
	await _wait(0.5)
	check(GameState.current_day == day_before + 1, "day advanced at dawn")
	check(main.get_node("HUD/DaySummaryUI").visible, "day summary popup shown")
	main.get_node("HUD/DaySummaryUI")._on_btn_continue_pressed()
	check(not tree.paused, "unpaused after summary")

	# Phó bản
	var entrance = main.dungeon_nodes[0]
	entrance.player_ref = main.player
	entrance._enter_dungeon()
	await _wait(1.0)
	check(tree.current_scene.name == "DungeonScene", "dungeon loaded")
	var ds := tree.current_scene
	check(is_instance_valid(ds.boss_instance), "boss spawned")
	ds.boss_instance._die()
	await _wait(0.3)
	check(ds.is_dungeon_cleared, "dungeon cleared")
	ds._return_to_surface()
	await _wait(1.5)
	check(tree.current_scene.name == "Main", "back to Main")
	check(tree.current_scene.dungeon_nodes.size() == GameState.get_dungeon_count() - 1, "cleared dungeon not respawned")

	# Permadeath trong thế giới mở
	var stats = tree.current_scene.player.get_node("SurvivalStats")
	stats.take_damage(99999)
	stats.take_damage(99999)
	await _wait(0.2)
	check(not SaveSystem.has_active_character(), "character wiped on death")
	check(tree.current_scene.get_node("HUD/PermadeathUI").visible, "permadeath screen shown")

	tree.paused = false
	for p in [SaveSystem.ACCOUNT_PATH, SaveSystem.CHARACTER_PATH]:
		SaveSystem._delete(p)
		if backups.has(p):
			FileAccess.open(p, FileAccess.WRITE).store_string(backups[p])
	print("=== smoke: %d failures ===" % failures)
	tree.quit(1 if failures > 0 else 0)
