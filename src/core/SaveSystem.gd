extends Node
## SaveSystem — lưu trữ local cho Phase 1 (JSON).
##
## 2 tầng dữ liệu tách biệt (Spec §4):
##   - Account   (user://account_data.json)   : vĩnh viễn, không mất khi chết
##   - Character (user://character_data.json) : bị XÓA khi nhân vật chết
##
## Mọi lần ghi đều qua _write_json_atomic (ghi file .tmp rồi đổi tên) để file
## không bao giờ bị ghi dở. Permadeath dùng một "journal" để toàn bộ chuỗi
## (cập nhật kỷ lục → xóa nhân vật) chạy như 1 transaction: nếu game crash giữa
## chừng, lần mở sau sẽ replay journal và hoàn tất — không thể "sống lại".

const ACCOUNT_PATH = "user://account_data.json"
const CHARACTER_PATH = "user://character_data.json"
const DEATH_JOURNAL_PATH = "user://death_journal.json"

var account_data: Dictionary = {}
var character_data: Dictionary = {}

## Tóm tắt lần chết gần nhất (để màn hình Permadeath đọc).
var last_death_summary: Dictionary = {}

func _ready() -> void:
	load_account()
	load_character()
	_recover_death_journal()

# ==========================================
# FILE HELPERS
# ==========================================
func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return null
	return json.data

func _write_json_atomic(path: String, data: Dictionary) -> bool:
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if not file:
		push_error("SaveSystem: không ghi được %s" % tmp)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp, path) == OK

func _delete(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

# ==========================================
# TẦNG 1: ACCOUNT (VĨNH VIỄN)
# ==========================================
func load_account() -> Dictionary:
	var data = _read_json(ACCOUNT_PATH)
	if data is Dictionary:
		account_data = _get_default_account()
		account_data.merge(data, true)
	else:
		account_data = _get_default_account()
		save_account()
	return account_data

func save_account() -> void:
	_write_json_atomic(ACCOUNT_PATH, account_data)

func _get_default_account() -> Dictionary:
	return {
		"account_id": "ACC_" + str(randi() % 900000 + 100000),
		"survivor_name": "Kẻ Xuyên Không",
		"highest_day_record": 0,
		"highest_sp_record": 0,
		"season_sp": 0,
		"total_games_played": 0,
		"total_monsters_killed": 0,
		"weekly_kills": 0,
		"titles": ["Tân Thủ Hoang Cổ"],
		"active_title": "Tân Thủ Hoang Cổ",
		"cosmetics": [],
		"history_logs": [],
		"processed_deaths": [],
	}

func add_title(title: String) -> void:
	var titles: Array = account_data.get("titles", [])
	if not title in titles:
		titles.append(title)
	account_data["titles"] = titles

## Ghi SP của ngày vào điểm mùa (tầng Account) ngay khi ngày kết thúc.
func commit_day_to_account(today_sp: int, kills_today: int) -> void:
	account_data["season_sp"] = int(account_data.get("season_sp", 0)) + today_sp
	account_data["total_monsters_killed"] = int(account_data.get("total_monsters_killed", 0)) + kills_today
	account_data["weekly_kills"] = int(account_data.get("weekly_kills", 0)) + kills_today
	save_account()

# ==========================================
# TẦNG 2: CHARACTER (MẤT VĨNH VIỄN KHI CHẾT)
# ==========================================
func has_active_character() -> bool:
	return character_data.get("is_alive", false) == true

func load_character() -> Dictionary:
	var data = _read_json(CHARACTER_PATH)
	character_data = data if data is Dictionary else {}
	return character_data

func save_character(data: Dictionary) -> void:
	if data.is_empty() or not data.get("is_alive", false):
		return # không bao giờ ghi đè nhân vật đã chết
	character_data = data
	_write_json_atomic(CHARACTER_PATH, character_data)

func create_new_character(char_name: String, talent: Dictionary) -> Dictionary:
	character_data = {
		"is_alive": true,
		"char_id": "CHR_%d_%d" % [Time.get_unix_time_from_system(), randi() % 100000],
		"name": char_name,
		"day": 1,
		"time_hours": 7.0,
		"world_seed": randi() % 2000000000 + 1,
		"talent": talent,
		"rerolled": false,
		"health": -1.0, # -1 = đầy máu theo max của thiên phú
		"hunger": 100.0,
		"stamina": 100.0,
		"today_sp": 0,
		"total_sp": 0,
		"kills_today": 0,
		"monsters_killed": 0,
		"elites_killed": 0,
		"outposts": 0,
		"inventory": {
			"wood": 10, "stone": 4, "iron": 0, "meat": 3, "bone": 0, "reroll_pill": 0,
		},
		"structures": [],
		"dungeons": { "day": 0, "list": [] },
		"created_at": Time.get_datetime_string_from_system(),
	}
	save_character(character_data)
	return character_data

# ==========================================
# PERMADEATH — ATOMIC TRANSACTION
# ==========================================
## Gọi đúng 1 lần khi nhân vật chết. Trả về summary cho màn hình Permadeath.
func kill_character_atomic(day_survived: int, sp_earned: int, talent_info: Dictionary) -> Dictionary:
	var char_id := str(character_data.get("char_id", "legacy_%d" % Time.get_unix_time_from_system()))
	var journal := {
		"char_id": char_id,
		"char_name": character_data.get("name", "Vô Danh"),
		"day_survived": day_survived,
		"sp_earned": sp_earned,
		"kills": int(character_data.get("monsters_killed", 0)),
		"talent": talent_info,
		"date": Time.get_date_string_from_system(),
	}
	# Bước 0: ghi ý định (write-ahead log). Từ đây nhân vật coi như đã chết.
	_write_json_atomic(DEATH_JOURNAL_PATH, journal)
	return _apply_death_journal(journal)

func _recover_death_journal() -> void:
	var j = _read_json(DEATH_JOURNAL_PATH)
	if j is Dictionary:
		push_warning("SaveSystem: phát hiện permadeath chưa hoàn tất — đang replay journal.")
		last_death_summary = _apply_death_journal(j)

func _apply_death_journal(j: Dictionary) -> Dictionary:
	var char_id := str(j.get("char_id", ""))
	var day_survived := int(j.get("day_survived", 1))
	var sp_earned := int(j.get("sp_earned", 0))
	var talent_info: Dictionary = j.get("talent", {})
	var old_record := int(account_data.get("highest_day_record", 0))
	var processed: Array = account_data.get("processed_deaths", [])
	var already := char_id in processed
	var record_broken := day_survived > old_record

	# Bước 1: cập nhật Account (idempotent nhờ processed_deaths)
	if not already:
		account_data["total_games_played"] = int(account_data.get("total_games_played", 0)) + 1
		if record_broken:
			account_data["highest_day_record"] = day_survived
		if sp_earned > int(account_data.get("highest_sp_record", 0)):
			account_data["highest_sp_record"] = sp_earned
		if day_survived >= 5: add_title("Người Sống Sót Hoang Cổ")
		if day_survived >= 15: add_title("Chiến Binh Rừng Sâu")
		if day_survived >= 30: add_title("Bá Chủ Thú Triều")
		var logs: Array = account_data.get("history_logs", [])
		logs.push_front({
			"char_name": j.get("char_name", "Vô Danh"),
			"day_survived": day_survived,
			"sp_earned": sp_earned,
			"kills": j.get("kills", 0),
			"talent_rank": talent_info.get("rank_str", "F"),
			"talent_name": talent_info.get("name", "Vô Thiên Phú"),
			"record": record_broken,
			"date": j.get("date", ""),
		})
		while logs.size() > 20:
			logs.pop_back()
		account_data["history_logs"] = logs
		processed.append(char_id)
		while processed.size() > 50:
			processed.pop_front()
		account_data["processed_deaths"] = processed
		save_account()

	# Bước 2: xóa toàn bộ Character (vị trí, inventory, căn cứ, thiên phú)
	character_data = {}
	_delete(CHARACTER_PATH)
	_delete(CHARACTER_PATH + ".tmp")

	# Bước 3: commit — xóa journal
	_delete(DEATH_JOURNAL_PATH)

	last_death_summary = {
		"record_broken": record_broken and not already,
		"old_record": old_record,
		"new_record": int(account_data.get("highest_day_record", 0)),
		"day_survived": day_survived,
		"sp_earned": sp_earned,
		"talent": talent_info,
	}
	return last_death_summary
