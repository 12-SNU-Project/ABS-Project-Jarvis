extends TextureRect
class_name AvatarController

@export var avatar_texture: Texture2D:
	set(val):
		avatar_texture = val
		texture = val
		queue_redraw()

var time_passed: float = 0.0
var base_y: float = 0.0
var fallback_color: Color = Color(0.18, 0.35, 0.65, 1)

var _move_tween: Tween = null

func _ready():
	if avatar_texture:
		texture = avatar_texture
	call_deferred("_init_base_pos")

func _init_base_pos():
	base_y = position.y

func _process(delta):
	if base_y == 0.0:
		return
	time_passed += delta
	# Floating breathing effect (Y only — X is owned by Tween)
	position.y = base_y + sin(time_passed * 1.5) * 8.0

func _draw():
	if texture == null:
		draw_rect(Rect2(Vector2.ZERO, size), fallback_color)

# Move avatar to best position given an active panel (or null = center).
# Computes panel's FINAL destination X directly — never reads mid-animation position.
func move_for_panel(panel: Control = null):
	# Wait one frame so our own size is fully computed
	await get_tree().process_frame

	var screen_size = get_viewport_rect().size

	if panel == null:
		# Return to horizontal center
		var center_x = (screen_size.x - size.x) / 2.0
		_animate_to(center_x)
	else:
		# Replicate show_card()'s final X formula so we don't read mid-tween position
		var panel_final_x = (screen_size.x - panel.size.x) / 2.0 + 50.0
		# Center avatar in the remaining space to the left of the panel
		var avatar_x = (panel_final_x - size.x) / 2.0
		_animate_to(avatar_x)

# Backward-compatible wrappers
func move_to_left():
	var screen_w = get_viewport_rect().size.x
	_animate_to((screen_w * 0.25) - size.x / 2.0)

func move_to_center():
	var screen_w = get_viewport_rect().size.x
	_animate_to((screen_w - size.x) / 2.0)

func _animate_to(dest_x: float):
	if _move_tween and _move_tween.is_running():
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_move_tween.tween_property(self, "position:x", dest_x, 0.55)
