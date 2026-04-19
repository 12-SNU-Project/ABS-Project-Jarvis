extends Node2D

# ─── Advanced Emotional Hologram Orb ──────────────────────────────────────────

enum Mood { IDLE, THINKING, SPEAKING, HAPPY, SURPRISED, SAD }

@onready var body        = $Body
@onready var eye_left    = $Body/Face/EyeLeft
@onready var eye_right   = $Body/Face/EyeRight
@onready var mouth       = $Body/Face/Mouth
@onready var dots_particles = $GlowParticles
@onready var wave_particles = $WaveParticles

var _blink_tween:  Tween
var _mood_tween:   Tween
var _time: float = 0.0
var _current_mood: Mood = Mood.IDLE

func _ready():
	_start_idle()

func _process(delta):
	_time += delta
	# Floating & Pulsing base
	var float_y = sin(_time * 1.5) * 8.0
	var pulse = 1.0 + sin(_time * 2.0) * 0.02
	body.position.y = -70.0 + float_y
	body.scale = Vector2(pulse, pulse)
	
	# Procedural Wave Motion
	# Rotate the wave particle system itself for extra dynamism
	if wave_particles:
		wave_particles.rotation += delta * 1.5
		# Pulse the emission radius slightly with waves
		var wave_radius = 72.0 + sin(_time * 3.0) * 4.0
		wave_particles.process_material.emission_sphere_radius = wave_radius

# ─── Mood API ───────────────────────────────────────────────────────────────
func set_mood_idle():
	_current_mood = Mood.IDLE
	_start_idle()

func set_mood_thinking():
	_current_mood = Mood.THINKING
	_start_thinking()

func set_mood_speaking():
	_current_mood = Mood.SPEAKING
	_start_speaking()

func set_mood_happy():
	_current_mood = Mood.HAPPY
	_start_happy()

func set_mood_surprised():
	_current_mood = Mood.SURPRISED
	_start_surprised()

func set_mood_sad():
	_current_mood = Mood.SAD
	_start_sad()

# Special Contextual Moods
func react_good_weather(): set_mood_happy()
func react_bad_weather():  set_mood_sad()

# Bridge for existing calls
func react_thinking():    set_mood_thinking()
func react_card_open():   set_mood_surprised()
func react_speaking():    set_mood_speaking()
func reset_anim():         set_mood_idle()

# ─── Animations ─────────────────────────────────────────────────────────────
func _kill_tweens():
	if _blink_tween: _blink_tween.kill()
	if _mood_tween:  _mood_tween.kill()

func _start_idle():
	_kill_tweens()
	_reset_face()
	_schedule_blink()

func _reset_face():
	var tw = create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(eye_left,  "scale", Vector2.ONE, 0.3)
	tw.tween_property(eye_right, "scale", Vector2.ONE, 0.3)
	tw.tween_property(eye_left,  "rotation", 0.0, 0.3)
	tw.tween_property(eye_right, "rotation", 0.0, 0.3)
	tw.tween_property(mouth,     "scale", Vector2.ONE, 0.3)
	tw.tween_property(body, "modulate", Color.WHITE, 0.5)

func _schedule_blink():
	_blink_tween = create_tween()
	_blink_tween.tween_interval(randf_range(2.0, 5.0))
	_blink_tween.tween_callback(_do_blink)

func _do_blink():
	var tw = create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(eye_left,  "scale:y", 0.1, 0.08)
	tw.tween_property(eye_right, "scale:y", 0.1, 0.08)
	tw.chain().set_parallel(true)
	tw.tween_property(eye_left,  "scale:y", 1.0, 0.08)
	tw.tween_property(eye_right, "scale:y", 1.0, 0.08)
	if _current_mood == Mood.IDLE:
		tw.chain().tween_callback(_schedule_blink)

func _start_thinking():
	_kill_tweens()
	_mood_tween = create_tween().set_loops()
	_mood_tween.set_trans(Tween.TRANS_SINE)
	_mood_tween.tween_property(mouth, "scale:x", 0.5, 0.5)
	_mood_tween.tween_property(mouth, "scale:x", 1.0, 0.5)

func _start_speaking():
	_kill_tweens()
	_mood_tween = create_tween().set_loops()
	_mood_tween.set_trans(Tween.TRANS_SINE)
	_mood_tween.tween_property(mouth, "scale:y", 2.2, 0.12)
	_mood_tween.tween_property(mouth, "scale:y", 1.0, 0.12)

func _start_happy():
	_kill_tweens()
	var tw = create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Smiling eyes
	tw.tween_property(eye_left,  "scale:y", 0.4, 0.3)
	tw.tween_property(eye_right, "scale:y", 0.4, 0.3)
	tw.tween_property(mouth,     "scale:x", 1.8, 0.3)
	# Happy bounce
	var b_tw = create_tween().set_loops(2)
	b_tw.tween_property(body, "scale", Vector2(1.15, 0.9), 0.1)
	b_tw.tween_property(body, "scale", Vector2(1.0, 1.0), 0.1)

func _start_surprised():
	_kill_tweens()
	var tw = create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(eye_left,  "scale", Vector2(1.5, 1.5), 0.4)
	tw.tween_property(eye_right, "scale", Vector2(1.5, 1.5), 0.4)
	tw.tween_property(mouth,     "scale", Vector2(0.4, 0.4), 0.4)

func _start_sad():
	_kill_tweens()
	var tw = create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Droopy eyes
	tw.tween_property(eye_left,  "rotation_degrees", 15.0, 0.5)
	tw.tween_property(eye_right, "rotation_degrees", -15.0, 0.5)
	tw.tween_property(body, "modulate", Color(0.7, 0.8, 1.0, 0.8), 0.5) # Duller blue
	tw.tween_property(mouth, "scale:x", 0.7, 0.5)
