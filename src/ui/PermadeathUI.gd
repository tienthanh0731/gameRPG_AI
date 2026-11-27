extends Control

@onready var label_title: Label = $Panel/VBox/LabelTitle
@onready var label_status: Label = $Panel/VBox/LabelStatus
@onready var label_stats: Label = $Panel/VBox/LabelStats
@onready var label_record: Label = $Panel/VBox/LabelRecord
@onready var btn_restart: Button = $Panel/VBox/BtnRestart

func _ready() -> void:
	btn_restart.pressed.connect(_on_btn_restart_pressed)
	process_mode = Node.PROCESS_MODE_ALWAYS

func setup(summary_data: Dictionary) -> void:
	var day = summary_data.get("day_survived", 1)
	var sp = summary_data.get("sp_earned", 0)
	var record_broken = summary_data.get("record_broken", false)
	var old_record = summary_data.get("old_record", 0)
	var new_record = summary_data.get("new_record", 0)
	var talent = summary_data.get("talent", {})
	
	label_title.text = "☠ NHÂN VẬT ĐÃ TỬ TRẬN - MẤT VĨNH VIỄN ☠"
	label_status.text = "Toàn bộ căn cứ, vật phẩm, cấp độ và Thiên Phú [%s] %s đã tan biến thành tro bụi." % [
		talent.get("rank_str", "F"), talent.get("name", "")
	]
	
	label_stats.text = "• Số ngày sống sót: %d Ngày\n• Tổng Điểm Sinh Tồn (SP): %d SP\n• Thiên Phú mang theo: Bậc %s" % [
		day, sp, talent.get("rank_str", "F")
	]
	
	if record_broken:
		label_record.text = "★ KỶ LỤC MỚI ĐÃ LẬP VÀ LƯU VÀO TÀI KHOẢN VĨNH VIỄN: %d NGÀY! (Cũ: %d Ngày) ★" % [
			new_record, old_record
		]
		label_record.modulate = Color(1.0, 0.9, 0.3)
	else:
		label_record.text = "Kỷ lục cao nhất của tài khoản hiện tại: %d Ngày" % new_record
		label_record.modulate = Color(0.7, 0.8, 0.9)

func _on_btn_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://src/ui/CharacterCreationUI.tscn")
