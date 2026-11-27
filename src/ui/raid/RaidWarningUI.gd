extends CanvasLayer

signal warning_dismissed()

@onready var panel: Control = $Control
@onready var label_title: Label = $Control/Panel/Title
@onready var label_status: Label = $Control/Panel/Status
@onready var label_countdown: Label = $Control/Panel/Countdown
@onready var label_estimate: Label = $Control/Panel/EstimateInfo
@onready var label_elite: Label = $Control/Panel/EliteInfo

# Compass Direction Labels
@onready var dir_north: Label = $Control/Panel/Compass/North
@onready var dir_east: Label = $Control/Panel/Compass/East
@onready var dir_south: Label = $Control/Panel/Compass/South
@onready var dir_west: Label = $Control/Panel/Compass/West

var remaining_countdown: float = 60.0
var is_active: bool = false

const COLOR_ACTIVE_DIR = Color(1.0, 0.25, 0.25, 1.0)
const COLOR_INACTIVE_DIR = Color(0.4, 0.4, 0.4, 0.4)

func _ready() -> void:
	visible = false
	var btn_dismiss = get_node_or_null("Control/Panel/DismissButton")
	if btn_dismiss:
		btn_dismiss.pressed.connect(dismiss)

func _process(delta: float) -> void:
	if not is_active or not visible:
		return
		
	remaining_countdown -= delta
	if remaining_countdown <= 0.0:
		remaining_countdown = 0.0
		is_active = false
		dismiss()
	else:
		var mins = int(remaining_countdown) / 60
		var secs = int(remaining_countdown) % 60
		label_countdown.text = "⏰ ĐÊM XUỐNG SAU: %02d:%02d" % [mins, secs]

# ==========================================
# SHOW PREVIEW CẢNH BÁO THÚ TRIỀU (HOÀNG HÔN)
# ==========================================
func show_preview(preview: Dictionary) -> void:
	var count = preview.get("count", 10)
	var directions = preview.get("directions", [0])
	var dir_names = preview.get("direction_names", [])
	var monster_type = preview.get("monster_type", "Ma Thú Rừng Rậm")
	var is_real = preview.get("is_real", true)
	var elite_chance = preview.get("elite_chance", 0.15)
	
	if is_real:
		label_title.text = "⚠️ [HOÀNG HÔN] CẢNH BÁO THÚ TRIỀU SẮP TỚI! ⚠️"
		label_title.modulate = Color(1.0, 0.3, 0.2)
		label_status.text = "THÚ TRIỀU CÀN QUÉT THẬT SỰ — HÃY GIA CỐ CĂN CỨ VÀ VŨ KHÍ!"
		label_status.modulate = Color(1.0, 0.5, 0.3)
	else:
		label_title.text = "🛡️ [TẬP DƯỢT TÂN THỦ] DÃ THÚ HOANG CỔ 🛡️"
		label_title.modulate = Color(0.4, 0.8, 1.0)
		label_status.text = "Đợt quái thăm dò tân thủ — Thích hợp làm quen cơ chế phòng thủ."
		label_status.modulate = Color(0.6, 0.9, 1.0)
		
	var dir_text = ", ".join(dir_names) if dir_names.size() > 0 else "Ngẫu nhiên"
	label_estimate.text = "Ước tính: %d Quái (%s)\nHướng tấn công: %s" % [count, monster_type, dir_text]
	
	var elite_pct = int(elite_chance * 100.0)
	label_elite.text = "Tỉ lệ xuất hiện Quái Tinh Anh: %d%%" % elite_pct
	
	# Update Compass Highlights (0: Bắc, 1: Đông, 2: Nam, 3: Tây)
	_update_compass_directions(directions)
	
	remaining_countdown = 60.0
	is_active = true
	visible = true

func _update_compass_directions(directions: Array) -> void:
	# North (0)
	var has_north = 0 in directions
	dir_north.modulate = COLOR_ACTIVE_DIR if has_north else COLOR_INACTIVE_DIR
	dir_north.text = "▲ BẮC (Đang Dồn Quái!)" if has_north else "▲ Bắc"
	
	# East (1)
	var has_east = 1 in directions
	dir_east.modulate = COLOR_ACTIVE_DIR if has_east else COLOR_INACTIVE_DIR
	dir_east.text = "ĐÔNG ▶" if has_east else "Đông ▶"
	
	# South (2)
	var has_south = 2 in directions
	dir_south.modulate = COLOR_ACTIVE_DIR if has_south else COLOR_INACTIVE_DIR
	dir_south.text = "▼ NAM (Đang Dồn Quái!)" if has_south else "▼ Nam"
	
	# West (3)
	var has_west = 3 in directions
	dir_west.modulate = COLOR_ACTIVE_DIR if has_west else COLOR_INACTIVE_DIR
	dir_west.text = "◀ TÂY" if has_west else "◀ Tây"

func dismiss() -> void:
	visible = false
	is_active = false
	warning_dismissed.emit()
