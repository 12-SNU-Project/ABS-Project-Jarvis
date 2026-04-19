extends Control

const MAIN_SCENE = "res://scenes/core/main_scene.tscn"

@onready var login_btn    = $CenterContainer/Card/VBox/Margin/InnerVBox/LoginBtn
@onready var status_label = $CenterContainer/Card/VBox/Margin/InnerVBox/StatusLabel
@onready var avatar       = $CenterContainer/Card/VBox/Margin/AvatarArea

var _float_tween: Tween

func _ready():
	print("[Title] Scene ready")
	login_btn.pivot_offset = login_btn.size / 2.0
	login_btn.pressed.connect(_on_login_pressed)
	_start_float_anim()

func _start_float_anim():
	_float_tween = create_tween().set_loops()
	_float_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_float_tween.tween_property(avatar, "position:y", avatar.position.y - 12.0, 1.4)
	_float_tween.tween_property(avatar, "position:y", avatar.position.y,         1.4)

func _on_login_pressed():
	print("[Title] Login button pressed")
	# Juicy press animation
	var tw = create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(login_btn, "scale", Vector2(0.92, 0.92), 0.08)
	tw.chain().tween_property(login_btn, "scale", Vector2(1.0, 1.0), 0.22)

	login_btn.disabled = true
	status_label.text = "Connecting to Google…"

	# Simulate OAuth delay
	print("[Title] Waiting for simulated auth...")
	await get_tree().create_timer(1.4).timeout
	status_label.text = "✓ Logged in!"
	print("[Title] Auth success, switching to main scene...")
	await get_tree().create_timer(0.6).timeout
	
	var err = get_tree().change_scene_to_file(MAIN_SCENE)
	if err != OK:
		print("[Title] ERROR: Failed to change scene! Error code: ", err)
