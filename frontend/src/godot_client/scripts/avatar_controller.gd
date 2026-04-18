extends TextureRect
class_name AvatarController

@export var avatar_texture: Texture2D:
	set(val):
		avatar_texture = val
		texture = val
		queue_redraw()

var time_passed: float = 0.0
var base_y: float = 0.0
var base_x: float = 0.0
var target_x: float = 0.0
var fallback_color: Color = Color(0.18, 0.35, 0.65, 1)

func _ready():
	if avatar_texture:
		texture = avatar_texture
		
	# Wait one frame to let layout set
	call_deferred("_init_base_pos")

func _init_base_pos():
	base_x = position.x
	target_x = base_x
	base_y = position.y

func _process(delta):
	if base_y == 0.0:
		return
	time_passed += delta
	# Subtle floating/breathing effect using sine wave
	position.y = base_y + sin(time_passed * 1.5) * 8.0
	
	# Smoothly interpolate X towards target_x
	position.x = lerp(position.x, target_x, 5.0 * delta)

func _draw():
	# Draw placeholder color if no texture is assigned
	if texture == null:
		draw_rect(Rect2(Vector2.ZERO, size), fallback_color)

func move_to_left():
	# Shift by -300 pixels
	target_x = base_x - 300.0

func move_to_center():
	target_x = base_x
