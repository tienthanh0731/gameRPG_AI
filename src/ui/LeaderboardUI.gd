extends Control

signal closed()

@onready var tab_bar: TabBar = $Panel/VBox/TabBar
@onready var item_list: ItemList = $Panel/VBox/ItemList
@onready var label_my_rank: Label = $Panel/VBox/LabelMyRank
@onready var btn_close: Button = $Panel/VBox/BtnClose

var leaderboard_data: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	btn_close.pressed.connect(_on_btn_close_pressed)
	tab_bar.tab_changed.connect(_on_tab_changed)
	_generate_mock_server_leaderboards()
	_update_tab_view(0)

func _generate_mock_server_leaderboards() -> void:
	var my_account = SaveSystem.account_data
	var my_name = my_account.get("survivor_name", "Bạn")
	var my_highest_day = my_account.get("highest_day_record", 1)
	var my_season_sp = my_account.get("season_sp", 50)
	
	# 1. Sinh Tồn (Highest Days)
	leaderboard_data[0] = [
		{ "rank": 1, "name": "Bắc Đẩu Ma Quân", "val": "42 Ngày", "badge": "[SSS] Bất Diệt Thần Thể", "is_self": false },
		{ "rank": 2, "name": "Vô Nhai Kiếm Thánh", "val": "36 Ngày", "badge": "[S] Đại Đạo Kiếm Thể", "is_self": false },
		{ "rank": 3, "name": "Tiêu Dao Du", "val": "28 Ngày", "badge": "[A] Linh Mộc Dục Hỏa", "is_self": false },
		{ "rank": 4, "name": my_name + " (Bản thân)", "val": str(my_highest_day) + " Ngày", "badge": "Tài khoản của bạn", "is_self": true },
		{ "rank": 5, "name": "Trấn Nam Vương", "val": "18 Ngày", "badge": "[B] Thần Lực Thổ Bá", "is_self": false },
		{ "rank": 6, "name": "Dạ Hành Khách", "val": "14 Ngày", "badge": "[C] Thần Hành Phong Bộ", "is_self": false },
	]
	
	# 2. Chiến Đấu (Monsters / Elites killed)
	leaderboard_data[1] = [
		{ "rank": 1, "name": "Đao Phách Hoang Cổ", "val": "412 Quái", "badge": "Hạng 1 Tuần", "is_self": false },
		{ "rank": 2, "name": "Vô Nhai Kiếm Thánh", "val": "345 Quái", "badge": "Hạng 2 Tuần", "is_self": false },
		{ "rank": 3, "name": my_name + " (Bản thân)", "val": str(my_season_sp / 2) + " Quái", "badge": "Bản thân", "is_self": true },
		{ "rank": 4, "name": "Thiết Quyền Thần Vương", "val": "180 Quái", "badge": "Hạng 4 Tuần", "is_self": false },
	]
	
	# 3. Lãnh Thổ (Captured Outposts)
	leaderboard_data[2] = [
		{ "rank": 1, "name": "Hắc Phong Sơn Trại", "val": "8 Căn cứ", "badge": "Chiếm đóng Vực Sâu", "is_self": false },
		{ "rank": 2, "name": "Vạn Tiên Minh", "val": "5 Căn cứ", "badge": "Chiếm đóng Rừng Cấm", "is_self": false },
		{ "rank": 3, "name": my_name + " (Bản thân)", "val": "1 Căn cứ", "badge": "Khu Rừng Nguyên Sinh", "is_self": true },
	]
	
	# 4. Liên Minh (Guild Points)
	leaderboard_data[3] = [
		{ "rank": 1, "name": "[THIÊN HẠ] Bang Hội", "val": "12,450 SP", "badge": "Top 1 Server", "is_self": false },
		{ "rank": 2, "name": "[TIÊU DAO] Minh Hội", "val": "9,800 SP", "badge": "Top 2 Server", "is_self": false },
		{ "rank": 3, "name": "[HOANG CỔ] Thợ Săn", "val": "6,200 SP", "badge": "Top 3 Server", "is_self": false },
	]
	
	# 5. Thiên Phú Hiếm (Living S & SSS survivors)
	leaderboard_data[4] = [
		{ "rank": 1, "name": "Bắc Đẩu Ma Quân", "val": "Đang Sống", "badge": "[SSS] Bất Diệt Thần Thể", "is_self": false },
		{ "rank": 2, "name": "Thái Hư Đạo Nhân", "val": "Đang Sống", "badge": "[SSS] Hoang Cổ Bá Chủ", "is_self": false },
		{ "rank": 3, "name": "Vô Nhai Kiếm Thánh", "val": "Đang Sống", "badge": "[S] Đại Đạo Kiếm Thể", "is_self": false },
		{ "rank": 4, "name": "Phượng Hoàng Niết Bàn", "val": "Đang Sống", "badge": "[S] Niết Bàn Thần Huyết", "is_self": false },
	]

func _on_tab_changed(tab_idx: int) -> void:
	_update_tab_view(tab_idx)

func _update_tab_view(tab_idx: int) -> void:
	item_list.clear()
	var entries = leaderboard_data.get(tab_idx, [])
	var my_rank_text = "Vị trí của bạn: Chưa xếp hạng"
	
	for entry in entries:
		var line = "#%d  |  %s  —  %s  [%s]" % [
			entry.rank, entry.name, entry.val, entry.badge
		]
		var idx = item_list.add_item(line)
		if entry.is_self:
			item_list.set_item_custom_fg_color(idx, Color(1.0, 0.85, 0.2))
			my_rank_text = "Vị trí của bạn: Hạng #%d (Thành tích: %s)" % [entry.rank, entry.val]
		else:
			item_list.set_item_custom_fg_color(idx, Color(0.9, 0.9, 0.9))
			
	label_my_rank.text = my_rank_text

func _on_btn_close_pressed() -> void:
	visible = false
	closed.emit()
