extends Node2D

enum Mood {
	IDLE,
	THINKING,
	SPEAKING,
	HAPPY,
	SURPRISED,
	SAD,
	ERROR,
	ANGRY,
	EMBARRASSED,
}

const NEUTRAL_LED := Color(0.49, 0.94, 1.0, 1.0)
const HAPPY_LED := Color(0.53, 1.0, 0.74, 1.0)
const ALERT_LED := Color(1.0, 0.83, 0.43, 1.0)
const SAD_LED := Color(0.52, 0.71, 0.98, 0.9)
const ERROR_LED := Color(1.0, 0.43, 0.43, 1.0)
const ANGRY_LED := Color(1.0, 0.58, 0.3, 1.0)
const EMBARRASSED_LED := Color(1.0, 0.68, 0.84, 1.0)

@onready var robot: Node2D = $Robot
@onready var head: Panel = $Robot/Head
@onready var visor: Panel = $Robot/Head/Visor
@onready var brow_left: Panel = $Robot/Head/Visor/BrowLeft
@onready var brow_right: Panel = $Robot/Head/Visor/BrowRight
@onready var eye_left: Panel = $Robot/Head/Visor/EyeLeft
@onready var eye_right: Panel = $Robot/Head/Visor/EyeRight
@onready var mouth_frame: Panel = $Robot/Head/Visor/MouthFrame
@onready var mouth_bar: Panel = $Robot/Head/Visor/MouthFrame/MouthBar
@onready var cheek_left: Panel = $Robot/Head/Visor/CheekLeft
@onready var cheek_right: Panel = $Robot/Head/Visor/CheekRight
@onready var antenna_tip: Panel = $Robot/AntennaTip

var _blink_tween: Tween
var _mood_tween: Tween
var _micro_tween: Tween
var _time := 0.0
var _current_mood: Mood = Mood.IDLE
var _led_color := NEUTRAL_LED
var _base_robot_y := 0.0
var _base_head_rotation := 0.0
var _mouth_base := Vector2(9.0, 6.0)


func _ready() -> void:
	_base_robot_y = robot.position.y
	_base_head_rotation = head.rotation
	_mouth_base = mouth_bar.position
	_apply_led_color(_led_color)
	_start_idle()


func _process(delta: float) -> void:
	_time += delta

	var hover_amp := 5.8
	var sway_amp := 0.026
	var antenna_amp := 0.08
	match _current_mood:
		Mood.ERROR:
			hover_amp = 1.8
			sway_amp = 0.006
			antenna_amp = 0.02
		Mood.ANGRY:
			hover_amp = 3.0
			sway_amp = 0.01
			antenna_amp = 0.03
		Mood.EMBARRASSED:
			hover_amp = 6.4
			sway_amp = 0.03
			antenna_amp = 0.1

	var hover := sin(_time * 1.5) * hover_amp
	var sway := sin(_time * 1.18) * sway_amp
	robot.position.y = _base_robot_y + hover
	robot.rotation = sway * 0.45
	head.rotation = _base_head_rotation + sway

	var antenna_pulse := 1.0 + sin(_time * 3.9) * antenna_amp
	antenna_tip.scale = Vector2.ONE * antenna_pulse
	antenna_tip.modulate.a = 0.84 + sin(_time * 3.4) * 0.12


func set_mood_idle() -> void:
	_current_mood = Mood.IDLE
	_start_idle()


func set_mood_thinking() -> void:
	_current_mood = Mood.THINKING
	_start_thinking()


func set_mood_speaking() -> void:
	_current_mood = Mood.SPEAKING
	_start_speaking()


func set_mood_happy() -> void:
	_current_mood = Mood.HAPPY
	_start_happy()


func set_mood_surprised() -> void:
	_current_mood = Mood.SURPRISED
	_start_surprised()


func set_mood_sad() -> void:
	_current_mood = Mood.SAD
	_start_sad()


func set_mood_error() -> void:
	_current_mood = Mood.ERROR
	_start_error()


func set_mood_angry() -> void:
	_current_mood = Mood.ANGRY
	_start_angry()


func set_mood_embarrassed() -> void:
	_current_mood = Mood.EMBARRASSED
	_start_embarrassed()


func react_good_weather() -> void:
	_apply_led_color(HAPPY_LED)
	set_mood_happy()


func react_bad_weather() -> void:
	_apply_led_color(SAD_LED)
	set_mood_sad()


func react_weather(condition: String) -> void:
	var normalized := condition.to_lower()
	if normalized.contains("sun") or normalized.contains("clear"):
		react_good_weather()
	elif normalized.contains("storm") or normalized.contains("thunder"):
		_apply_led_color(ALERT_LED)
		set_mood_surprised()
	elif normalized.contains("rain") or normalized.contains("snow"):
		react_bad_weather()
	elif normalized.contains("cloud") or normalized.contains("fog") or normalized.contains("wind"):
		_apply_led_color(ALERT_LED)
		set_mood_thinking()
	else:
		_apply_led_color(NEUTRAL_LED)
		set_mood_idle()


func react_thinking() -> void:
	_apply_led_color(ALERT_LED)
	set_mood_thinking()


func react_card_open() -> void:
	_apply_led_color(ALERT_LED)
	set_mood_surprised()


func react_speaking() -> void:
	_apply_led_color(NEUTRAL_LED)
	set_mood_speaking()


func react_error() -> void:
	_apply_led_color(ERROR_LED)
	set_mood_error()


func react_angry() -> void:
	_apply_led_color(ANGRY_LED)
	set_mood_angry()


func react_embarrassed() -> void:
	_apply_led_color(EMBARRASSED_LED)
	set_mood_embarrassed()


func reset_anim() -> void:
	_apply_led_color(NEUTRAL_LED)
	set_mood_idle()


func _kill_tweens() -> void:
	if _blink_tween:
		_blink_tween.kill()
	if _mood_tween:
		_mood_tween.kill()
	if _micro_tween:
		_micro_tween.kill()


func _start_idle() -> void:
	_kill_tweens()
	_reset_face()
	_apply_led_color(NEUTRAL_LED)
	_schedule_blink(2.1, 4.1)


func _reset_face() -> void:
	cheek_left.visible = false
	cheek_right.visible = false
	cheek_left.modulate.a = 0.36
	cheek_right.modulate.a = 0.36

	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(eye_left, "scale", Vector2.ONE, 0.28)
	tw.tween_property(eye_right, "scale", Vector2.ONE, 0.28)
	tw.tween_property(brow_left, "rotation_degrees", 0.0, 0.28)
	tw.tween_property(brow_right, "rotation_degrees", 0.0, 0.28)
	tw.tween_property(brow_left, "position", Vector2(18.0, 14.0), 0.28)
	tw.tween_property(brow_right, "position", Vector2(74.0, 14.0), 0.28)
	tw.tween_property(mouth_frame, "scale", Vector2.ONE, 0.28)
	tw.tween_property(mouth_bar, "scale", Vector2.ONE, 0.28)
	tw.tween_property(mouth_bar, "position", _mouth_base, 0.28)
	tw.tween_property(head, "rotation_degrees", 0.0, 0.28)
	tw.tween_property(visor, "modulate", Color.WHITE, 0.28)


func _schedule_blink(min_delay: float, max_delay: float) -> void:
	_blink_tween = create_tween()
	_blink_tween.tween_interval(randf_range(min_delay, max_delay))
	_blink_tween.tween_callback(_do_blink)


func _do_blink() -> void:
	if _current_mood == Mood.ANGRY:
		_schedule_blink(2.8, 4.8)
		return

	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(eye_left, "scale:y", 0.12, 0.08)
	tw.tween_property(eye_right, "scale:y", 0.12, 0.08)
	tw.chain().set_parallel(true)
	tw.tween_property(eye_left, "scale:y", 1.0, 0.08)
	tw.tween_property(eye_right, "scale:y", 1.0, 0.08)
	tw.chain().tween_callback(func():
		_schedule_blink(2.1, 4.1)
	)


func _start_thinking() -> void:
	_kill_tweens()
	_reset_face()
	_apply_led_color(ALERT_LED)

	var intro := create_tween().set_parallel(true)
	intro.tween_property(brow_left, "rotation_degrees", -12.0, 0.24)
	intro.tween_property(brow_right, "rotation_degrees", 8.0, 0.24)
	intro.tween_property(brow_right, "position:y", 11.0, 0.24)
	intro.tween_property(eye_left, "scale:x", 0.84, 0.24)
	intro.tween_property(eye_right, "scale:x", 1.14, 0.24)

	_mood_tween = create_tween().set_loops()
	_mood_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_mood_tween.tween_property(head, "rotation_degrees", -4.0, 0.42)
	_mood_tween.parallel().tween_property(mouth_bar, "scale:x", 0.52, 0.42)
	_mood_tween.parallel().tween_property(mouth_bar, "position:x", 19.0, 0.42)
	_mood_tween.tween_property(head, "rotation_degrees", 3.0, 0.42)
	_mood_tween.parallel().tween_property(mouth_bar, "scale:x", 1.0, 0.42)
	_mood_tween.parallel().tween_property(mouth_bar, "position:x", _mouth_base.x, 0.42)


func _start_speaking() -> void:
	_kill_tweens()
	_reset_face()
	_apply_led_color(NEUTRAL_LED)

	var intro := create_tween().set_parallel(true)
	intro.tween_property(brow_left, "position:y", 13.0, 0.18)
	intro.tween_property(brow_right, "position:y", 13.0, 0.18)

	_mood_tween = create_tween().set_loops()
	_mood_tween.set_trans(Tween.TRANS_SINE)
	_mood_tween.tween_property(mouth_frame, "scale:y", 1.2, 0.12)
	_mood_tween.parallel().tween_property(mouth_bar, "scale:y", 1.95, 0.12)
	_mood_tween.parallel().tween_property(head, "rotation_degrees", 2.2, 0.12)
	_mood_tween.tween_property(mouth_frame, "scale:y", 1.0, 0.12)
	_mood_tween.parallel().tween_property(mouth_bar, "scale:y", 1.0, 0.12)
	_mood_tween.parallel().tween_property(head, "rotation_degrees", -1.7, 0.12)


func _start_happy() -> void:
	_kill_tweens()
	_reset_face()
	_apply_led_color(HAPPY_LED)
	cheek_left.visible = true
	cheek_right.visible = true

	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(brow_left, "rotation_degrees", -18.0, 0.28)
	tw.tween_property(brow_right, "rotation_degrees", 18.0, 0.28)
	tw.tween_property(eye_left, "scale:y", 0.58, 0.28)
	tw.tween_property(eye_right, "scale:y", 0.58, 0.28)
	tw.tween_property(mouth_bar, "scale:x", 1.35, 0.28)
	tw.tween_property(mouth_bar, "position:x", 2.0, 0.28)

	_mood_tween = create_tween().set_loops()
	_mood_tween.tween_property(robot, "scale", Vector2(1.06, 0.95), 0.1)
	_mood_tween.tween_property(robot, "scale", Vector2.ONE, 0.12)


func _start_surprised() -> void:
	_kill_tweens()
	_reset_face()
	_apply_led_color(ALERT_LED)

	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(brow_left, "position:y", 6.0, 0.42)
	tw.tween_property(brow_right, "position:y", 6.0, 0.42)
	tw.tween_property(eye_left, "scale", Vector2(1.18, 1.26), 0.42)
	tw.tween_property(eye_right, "scale", Vector2(1.18, 1.26), 0.42)
	tw.tween_property(mouth_frame, "scale", Vector2(0.82, 1.45), 0.42)
	tw.tween_property(mouth_bar, "scale", Vector2(0.44, 1.9), 0.42)


func _start_sad() -> void:
	_kill_tweens()
	_reset_face()
	_apply_led_color(SAD_LED)

	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(brow_left, "rotation_degrees", 16.0, 0.32)
	tw.tween_property(brow_right, "rotation_degrees", -16.0, 0.32)
	tw.tween_property(brow_left, "position:y", 18.0, 0.32)
	tw.tween_property(brow_right, "position:y", 18.0, 0.32)
	tw.tween_property(eye_left, "scale:y", 0.46, 0.32)
	tw.tween_property(eye_right, "scale:y", 0.46, 0.32)
	tw.tween_property(mouth_bar, "scale:x", 0.55, 0.32)
	tw.tween_property(mouth_bar, "position:x", 18.0, 0.32)
	tw.tween_property(visor, "modulate", Color(0.82, 0.88, 1.0, 0.88), 0.32)
	tw.tween_property(head, "rotation_degrees", -3.0, 0.32)


func _start_error() -> void:
	_kill_tweens()
	_reset_face()
	_apply_led_color(ERROR_LED)

	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(brow_left, "rotation_degrees", 23.0, 0.2)
	tw.tween_property(brow_right, "rotation_degrees", -23.0, 0.2)
	tw.tween_property(eye_left, "scale", Vector2(1.06, 0.4), 0.2)
	tw.tween_property(eye_right, "scale", Vector2(1.06, 0.4), 0.2)
	tw.tween_property(mouth_bar, "scale", Vector2(1.2, 0.75), 0.2)
	tw.tween_property(mouth_bar, "position", Vector2(4.0, 8.0), 0.2)
	tw.tween_property(visor, "modulate", Color(1.0, 0.78, 0.78, 1.0), 0.2)

	_mood_tween = create_tween().set_loops()
	_mood_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_mood_tween.tween_property(head, "position:x", -2.0, 0.07)
	_mood_tween.tween_property(head, "position:x", 2.0, 0.07)
	_mood_tween.tween_property(head, "position:x", 0.0, 0.05)


func _start_angry() -> void:
	_kill_tweens()
	_reset_face()
	_apply_led_color(ANGRY_LED)

	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(brow_left, "rotation_degrees", 24.0, 0.22)
	tw.tween_property(brow_right, "rotation_degrees", -24.0, 0.22)
	tw.tween_property(brow_left, "position:y", 12.0, 0.22)
	tw.tween_property(brow_right, "position:y", 12.0, 0.22)
	tw.tween_property(eye_left, "scale", Vector2(1.22, 0.44), 0.22)
	tw.tween_property(eye_right, "scale", Vector2(1.22, 0.44), 0.22)
	tw.tween_property(mouth_bar, "scale", Vector2(1.5, 0.72), 0.22)
	tw.tween_property(mouth_bar, "position", Vector2(-2.0, 8.0), 0.22)

	_mood_tween = create_tween().set_loops()
	_mood_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_mood_tween.tween_property(head, "rotation_degrees", -4.0, 0.09)
	_mood_tween.tween_property(head, "rotation_degrees", 4.0, 0.09)
	_mood_tween.tween_property(head, "rotation_degrees", 0.0, 0.06)


func _start_embarrassed() -> void:
	_kill_tweens()
	_reset_face()
	_apply_led_color(EMBARRASSED_LED)
	cheek_left.visible = true
	cheek_right.visible = true
	cheek_left.modulate.a = 0.62
	cheek_right.modulate.a = 0.62

	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(brow_left, "position:y", 9.0, 0.24)
	tw.tween_property(brow_right, "position:y", 9.0, 0.24)
	tw.tween_property(brow_left, "rotation_degrees", -8.0, 0.24)
	tw.tween_property(brow_right, "rotation_degrees", 8.0, 0.24)
	tw.tween_property(eye_left, "scale", Vector2(0.86, 0.66), 0.24)
	tw.tween_property(eye_right, "scale", Vector2(0.98, 0.58), 0.24)
	tw.tween_property(mouth_bar, "scale", Vector2(0.58, 0.85), 0.24)
	tw.tween_property(mouth_bar, "position", Vector2(18.0, 7.0), 0.24)
	tw.tween_property(head, "rotation_degrees", 4.0, 0.24)

	_mood_tween = create_tween().set_loops()
	_mood_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_mood_tween.tween_property(head, "rotation_degrees", 6.0, 0.42)
	_mood_tween.parallel().tween_property(cheek_left, "modulate:a", 0.72, 0.42)
	_mood_tween.parallel().tween_property(cheek_right, "modulate:a", 0.72, 0.42)
	_mood_tween.tween_property(head, "rotation_degrees", 2.0, 0.42)
	_mood_tween.parallel().tween_property(cheek_left, "modulate:a", 0.54, 0.42)
	_mood_tween.parallel().tween_property(cheek_right, "modulate:a", 0.54, 0.42)


func _apply_led_color(color: Color) -> void:
	_led_color = color
	eye_left.modulate = color
	eye_right.modulate = color
	mouth_bar.modulate = color
	cheek_left.modulate = Color(color.r, color.g, color.b, cheek_left.modulate.a)
	cheek_right.modulate = Color(color.r, color.g, color.b, cheek_right.modulate.a)
	antenna_tip.modulate = Color(color.r, color.g, color.b, 0.95)
