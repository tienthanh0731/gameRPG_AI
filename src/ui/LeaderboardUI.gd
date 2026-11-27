extends Control
## Bảng xếp hạng: 5 tab, phân trang (chỉ lấy 1 trang mỗi lần), highlight bản thân.
## Dữ liệu lấy từ ServerSim (Phase 2: thay bằng API sorted-set Redis).

signal closed()

const BOARD_NOTES: Array[String] = [
	"Ngày sống sót liên tục cao nhất (theo mùa)",
	"Tổng quái/elite/boss hạ gục (hàng tuần)",
	"Số nhà/outpost đang chiếm giữ (theo mùa)",
	"Điểm world boss + kiểm soát lãnh thổ (Phase 1: chưa có liên minh)",
	"Người đang sống mang thiên phú S/SSS (realtime)",
]

@onready var tab_bar: TabBar = $Panel/VBox/TabBar
@onready var item_list: ItemList = $Panel/VBox/ItemList
@onready var label_my_rank: Label = $Panel/VBox/LabelMyRank
@onready var btn_close: Button = $Panel/VBox/BtnClose
@onready var vbox: VBoxContainer = $Panel/VBox

var current_board: int = 0
var current_page: int = 0
var page_count: int = 1
var self_rank: int = 0
var label_note: Label
var label_page: Label
var btn_prev: Button
var btn_next: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	btn_close.pressed.connect(_on_btn_close_pressed)
	tab_bar.tab_changed.connect(_on_tab_changed)

	label_note = Label.new()
	label_note.add_theme_font_size_override("font_size", 12)
	label_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label_note)
	vbox.move_child(label_note, item_list.get_index())

	var pager := HBoxContainer.new()
	pager.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_prev = Button.new()
	btn_prev.text = "◀ Trang trước"
	btn_prev.pressed.connect(func(): _load_page(current_page - 1))
	label_page = Label.new()
	btn_next = Button.new()
	btn_next.text = "Trang sau ▶"
	btn_next.pressed.connect(func(): _load_page(current_page + 1))
	var btn_me := Button.new()
	btn_me.text = "Vị trí của tôi"
	btn_me.pressed.connect(_jump_to_self)
	pager.add_child(btn_prev)
	pager.add_child(label_page)
	pager.add_child(btn_next)
	pager.add_child(btn_me)
	vbox.add_child(pager)
	vbox.move_child(pager, label_my_rank.get_index())
	refresh()

func refresh() -> void:
	_on_tab_changed(tab_bar.current_tab)

func _on_tab_changed(tab_idx: int) -> void:
	current_board = tab_idx
	label_note.text = BOARD_NOTES[tab_idx]
	_load_page(0)

func _jump_to_self() -> void:
	if self_rank > 0:
		_load_page(ServerSim.page_of_rank(self_rank))

func _load_page(page: int) -> void:
	var res := ServerSim.get_board_page(current_board, page)
	current_page = res.page
	page_count = res.page_count
	self_rank = res.self_rank
	item_list.clear()
	for e in res.entries:
		var idx := item_list.add_item("#%d   %s  —  %s   %s" % [e.rank, e.name, e.display, e.badge])
		if e.is_self:
			item_list.set_item_custom_fg_color(idx, Color(1.0, 0.85, 0.2))
			item_list.set_item_custom_bg_color(idx, Color(0.35, 0.28, 0.05, 0.6))
	label_page.text = "  Trang %d / %d  " % [current_page + 1, page_count]
	btn_prev.disabled = current_page <= 0
	btn_next.disabled = current_page >= page_count - 1
	if self_rank > 0:
		label_my_rank.text = "Vị trí của bạn: Hạng #%d / %d" % [self_rank, res.total]
	else:
		label_my_rank.text = "Vị trí của bạn: Chưa xếp hạng"

func _on_btn_close_pressed() -> void:
	visible = false
	closed.emit()
