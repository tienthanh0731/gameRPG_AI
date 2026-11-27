class_name HUD
extends CanvasLayer

@onready var health_bar: ProgressBar = $MarginContainer/VBoxContainer/HealthBar
@onready var stamina_bar: ProgressBar = $MarginContainer/VBoxContainer/StaminaBar
@onready var temp_label: Label = $MarginContainer/VBoxContainer/TempLabel
@onready var time_label: Label = $TopContainer/TimeLabel
@onready var phase_label: Label = $TopContainer/PhaseLabel

func update_health(current: float, max_val: float) -> void:
	if health_bar:
		health_bar.max_value = max_val
		health_bar.value = current

func update_stamina(current: float, max_val: float) -> void:
	if stamina_bar:
		stamina_bar.max_value = max_val
		stamina_bar.value = current

func update_temperature(temp: float) -> void:
	if temp_label:
		temp_label.text = "Thân nhiệt: %.1f°C" % temp
		if temp < 35.0:
			temp_label.modulate = Color(0.4, 0.7, 1.0) # Xanh lanh
		elif temp > 38.0:
			temp_label.modulate = Color(1.0, 0.4, 0.2) # Do nong
		else:
			temp_label.modulate = Color.WHITE

func update_time(hour: int, minute: int) -> void:
	if time_label:
		time_label.text = "Thời gian: %02d:%02d" % [hour, minute]

func update_phase(phase_name: String) -> void:
	if phase_label:
		match phase_name:
			"Day": phase_label.text = "[BAN NGÀY] Khám phá & Thu thập"
			"Dusk": phase_label.text = "[HOÀNG HÔN] Chuẩn bị thú triều!"
			"Night": phase_label.text = "[BAN ĐÊM] THÚ TRIỀU TẤN CÔNG!"
			"Dawn": phase_label.text = "[RẠNG ĐÔNG] Sống sót an toàn"
