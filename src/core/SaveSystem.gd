extends Node

const ACCOUNT_PATH = "user://account_data.json"
const CHARACTER_PATH = "user://character_data.json"

var account_data: Dictionary = {}
var character_data: Dictionary = {}

func _ready() -> void:
	load_account()
	load_character()

# ==========================================
# TẦNG 1: ACCOUNT (VĨNH VIỄN, KHÔNG BỊ XÓA)
# ==========================================
func load_account() -> Dictionary:
	if not FileAccess.file_exists(ACCOUNT_PATH):
		account_data = _get_default_account()
		save_account()
		return account_data
		
	var file = FileAccess.open(ACCOUNT_PATH, FileAccess.READ)
	if file:
		var text = file.get_as_text()
		var json = JSON.new()
		var parse_result = json.parse(text)
		if parse_result == OK and json.data is Dictionary:
			account_data = json.data
		else:
			account_data = _get_default_account()
	else:
		account_data = _get_default_account()
	return account_data

func save_account() -> void:
	var file = FileAccess.open(ACCOUNT_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(account_data, "\t"))

func _get_default_account() -> Dictionary:
	return {
		"account_id": "ACC_" + str(randi() % 900000 + 100000),
		"survivor_name": "Kẻ Xuyên Không",
		"highest_day_record": 0,
		"highest_sp_record": 0,
		"season_sp": 0,
		"total_games_played": 0,
		"total_monsters_killed": 0,
		"titles": ["Tân Thủ Hoang Cổ"],
		"active_title": "Tân Thủ Hoang Cổ",
		"history_logs": []
	}

# ==========================================
# TẦNG 2: CHARACTER (MẤT VĨNH VIỄN KHI CHẾT)
# ==========================================
func has_active_character() -> bool:
	return character_data.has("is_alive") and character_data["is_alive"] == true

func load_character() -> Dictionary:
	if not FileAccess.file_exists(CHARACTER_PATH):
		character_data = {}
		return character_data
		
	var file = FileAccess.open(CHARACTER_PATH, FileAccess.READ)
	if file:
		var text = file.get_as_text()
		var json = JSON.new()
		var parse_result = json.parse(text)
		if parse_result == OK and json.data is Dictionary:
			character_data = json.data
		else:
			character_data = {}
	return character_data

func save_character(data: Dictionary) -> void:
	character_data = data
	var file = FileAccess.open(CHARACTER_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(character_data, "\t"))

func create_new_character(char_name: String, talent: Dictionary) -> Dictionary:
	character_data = {
		"is_alive": true,
		"name": char_name,
		"day": 1,
		"talent": talent,
		"health": 100.0,
		"stamina": 100.0,
		"today_sp": 0,
		"total_sp": 0,
		"monsters_killed": 0,
		"inventory": {
			"wood": 0,
			"stone": 0,
			"iron": 0,
			"meat": 0,
			"bone": 0
		},
		"created_at": Time.get_datetime_string_from_system()
	}
	save_character(character_data)
	return character_data

# ==========================================
# PERMADEATH ATOMIC TRANSACTION
# ==========================================
func kill_character_atomic(day_survived: int, sp_earned: int, talent_info: Dictionary) -> Dictionary:
	var old_record = account_data.get("highest_day_record", 0)
	var record_broken = day_survived > old_record
	
	# 1. Update Account records
	account_data["total_games_played"] = account_data.get("total_games_played", 0) + 1
	account_data["season_sp"] = account_data.get("season_sp", 0) + sp_earned
	
	if record_broken:
		account_data["highest_day_record"] = day_survived
		
	if sp_earned > account_data.get("highest_sp_record", 0):
		account_data["highest_sp_record"] = sp_earned
		
	# Unlock milestone titles
	var titles: Array = account_data.get("titles", [])
	if day_survived >= 5 and not "Người Sống Sót Hoang Cổ" in titles:
		titles.append("Người Sống Sót Hoang Cổ")
	if day_survived >= 15 and not "Chiến Binh Rừng Sâu" in titles:
		titles.append("Chiến Binh Rừng Sâu")
	if day_survived >= 30 and not "Bá Chủ Thú Triều" in titles:
		titles.append("Bá Chủ Thú Triều")
	account_data["titles"] = titles
	
	# Archive play history entry into Account
	var log_entry = {
		"char_name": character_data.get("name", "Vô Danh"),
		"day_survived": day_survived,
		"sp_earned": sp_earned,
		"talent_rank": talent_info.get("rank_str", "F"),
		"talent_name": talent_info.get("name", "Vô Thiên Phú"),
		"date": Time.get_date_string_from_system()
	}
	var logs: Array = account_data.get("history_logs", [])
	logs.push_front(log_entry)
	if logs.size() > 20:
		logs.pop_back()
	account_data["history_logs"] = logs
	
	# Save Account to disk
	save_account()
	
	# 2. ATOMIC WIPE of Character data
	character_data = {}
	if FileAccess.file_exists(CHARACTER_PATH):
		DirAccess.remove_absolute(CHARACTER_PATH)
		
	return {
		"record_broken": record_broken,
		"old_record": old_record,
		"new_record": account_data["highest_day_record"],
		"day_survived": day_survived,
		"sp_earned": sp_earned,
		"talent": talent_info
	}
