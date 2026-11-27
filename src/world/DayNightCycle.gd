class_name DayNightCycle
extends CanvasModulate

signal time_changed(hour: int, minute: int)
signal phase_changed(phase_name: String)

@export var day_duration_seconds: float = 300.0 # 5 phut 1 ngay
@export var current_time_hours: float = 8.0 # Bat dau 8 gio sang

var day_color: Color = Color(1.0, 1.0, 1.0, 1.0)
var dusk_color: Color = Color(0.9, 0.55, 0.35, 1.0)
var night_color: Color = Color(0.08, 0.08, 0.18, 1.0)
var dawn_color: Color = Color(0.85, 0.7, 0.5, 1.0)

var current_phase: String = "Day"

func _process(delta: float) -> void:
	var hours_per_second = 24.0 / day_duration_seconds
	current_time_hours += hours_per_second * delta
	if current_time_hours >= 24.0:
		current_time_hours -= 24.0
		
	var hour_int = int(current_time_hours)
	var minute_int = int((current_time_hours - hour_int) * 60)
	time_changed.emit(hour_int, minute_int)
	
	_update_lighting_and_phase()

func _update_lighting_and_phase() -> void:
	# 06:00 - 17:00: Ban Ngay
	# 17:00 - 19:30: Hoang Hon
	# 19:30 - 04:30: Ban Dem (Thu Trieu hoat dong)
	# 04:30 - 06:00: Rang Dong
	if current_time_hours >= 6.0 and current_time_hours < 17.0:
		color = day_color
		_set_phase("Day")
	elif current_time_hours >= 17.0 and current_time_hours < 19.5:
		var t = (current_time_hours - 17.0) / 2.5
		color = day_color.lerp(dusk_color, t)
		_set_phase("Dusk")
	elif current_time_hours >= 19.5 or current_time_hours < 4.5:
		color = night_color
		_set_phase("Night")
	else:
		var t = (current_time_hours - 4.5) / 1.5
		color = night_color.lerp(dawn_color, t)
		_set_phase("Dawn")

func _set_phase(new_phase: String) -> void:
	if current_phase != new_phase:
		current_phase = new_phase
		phase_changed.emit(current_phase)

func get_ambient_temperature() -> float:
	match current_phase:
		"Day": return 30.0
		"Dusk": return 24.0
		"Night": return 12.0 # Ret buot ban dem
		"Dawn": return 20.0
		_: return 25.0
