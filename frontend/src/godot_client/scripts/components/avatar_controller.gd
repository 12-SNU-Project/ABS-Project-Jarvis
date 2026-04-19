extends TextureRect
class_name AvatarController

@export var avatar_texture: Texture2D:
	set(val):
		avatar_texture = val
		texture = val
		queue_redraw()

var time_passed: float = 0.0
var base_x: float = 0.0
var base_y: float = 0.0
var _y_offset: float = 0.0          # animated bounce offset
var fallback_color: Color = Color(0.18, 0.35, 0.65, 1)

var _move_tween: Tween = null
var _anim_tween: Tween = null

func _ready():
	if avatar_texture:
		texture = avatar_texture
	call_deferred("_init_base_pos")

func _init_base_pos():
	await get_tree().process_frame
	var screen = get_viewport_rect().size
	# Center horizontally within TopZone (exclude 148px dock on right)
	var avail_w = screen.x - 148.0
	base_x = (avail_w - size.x) / 2.0
	base_y = position.y
	position.x = base_x
	pivot_offset = size / 2.0

func _process(delta):
	if base_y == 0.0:
		return
	time_passed += delta
	# Idle floating + animated bounce offset
	position.y = base_y + sin(time_passed * 1.5) * 6.0 + _y_offset

func _draw():
	if texture == null:
		draw_rect(Rect2(Vector2.ZERO, size), fallback_color)

# ─────────────────────────────────────────────────────────────────────────────
# Layout movement: MINIMAL — only a subtle 24px nudge when a card is active
# ─────────────────────────────────────────────────────────────────────────────
func move_for_panel(panel: Control = null):
	await get_tree().process_frame
	if panel == null:
		_animate_x_to(base_x)
	else:
		_animate_x_to(max(10.0, base_x - 24.0))

func move_to_left():
	_animate_x_to(max(10.0, base_x - 24.0))

func move_to_center():
	_animate_x_to(base_x)

func _animate_x_to(dest_x: float):
	if _move_tween and _move_tween.is_running():
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_move_tween.tween_property(self, "position:x", dest_x, 0.4)

# ─────────────────────────────────────────────────────────────────────────────
# Intrinsic Avatar Animations
# ─────────────────────────────────────────────────────────────────────────────

# Thinking: gentle left-right tilt loop (loops until reset_anim is called)
func react_thinking():
	_kill_anim()
	_anim_tween = create_tween().set_loops()
	_anim_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_anim_tween.tween_property(self, "rotation_degrees", -3.0, 0.55)
	_anim_tween.tween_property(self, "rotation_degrees",  3.0, 0.55)

# Card open: upward bounce + slight scale pop
func react_card_open():
	_kill_anim()
	_anim_tween = create_tween()
	_anim_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Bounce up then settle
	_anim_tween.tween_method(_set_y_offset, 0.0, -22.0, 0.18)
	_anim_tween.tween_method(_set_y_offset, -22.0, 0.0, 0.38)
	# Scale pop on the same timeline
	_anim_tween.parallel().tween_property(self, "scale", Vector2(1.05, 1.05), 0.18)
	_anim_tween.parallel().tween_property(self, "scale", Vector2(1.0,  1.0),  0.38)

# Speaking: quick scale pulse to show "talking" energy
func react_speaking():
	_kill_anim()
	_anim_tween = create_tween()
	_anim_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_anim_tween.tween_property(self, "scale", Vector2(1.04, 1.04), 0.12)
	_anim_tween.tween_property(self, "scale", Vector2(1.0,  1.0),  0.28)

# Card close / idle: smooth return to neutral
func reset_anim():
	_kill_anim()
	_anim_tween = create_tween().set_parallel(true)
	_anim_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_anim_tween.tween_property(self, "scale",            Vector2(1.0, 1.0), 0.3)
	_anim_tween.tween_property(self, "rotation_degrees", 0.0,               0.3)
	_anim_tween.tween_method(_set_y_offset, _y_offset,   0.0,               0.3)

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────
func _set_y_offset(v: float):
	_y_offset = v

func _kill_anim():
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
