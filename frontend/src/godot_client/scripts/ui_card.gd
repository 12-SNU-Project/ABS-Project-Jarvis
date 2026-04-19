extends PanelContainer
class_name UICard

signal card_closed

@export var background_texture: Texture2D

@onready var title_label = $MarginContainer/VBoxContainer/Title
@onready var content_label = $MarginContainer/VBoxContainer/ScrollContainer/Content

func _ready():
	if background_texture:
		var style = StyleBoxTexture.new()
		style.texture = background_texture
		add_theme_stylebox_override("panel", style)
	
	modulate.a = 0.0
	visible = false

func show_card(title: String, content: String):
	title_label.text = "[center]" + title + "[/center]"
	content_label.text = content
	
	visible = true
	modulate.a = 0.0
	# Wait one frame so Godot computes the correct size
	await get_tree().process_frame
	
	var screen_size = get_viewport_rect().size
	var center_x = (screen_size.x - size.x) / 2.0 + 50.0
	var center_y = (screen_size.y - size.y) / 2.0
	
	# Start off-screen to the right
	position = Vector2(screen_size.x, center_y)
	
	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:x", center_x, 0.6)
	tween.tween_property(self, "modulate:a", 1.0, 0.4)

func hide_card():
	if not visible:
		card_closed.emit()
		return
	
	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	
	var target_x = get_viewport_rect().size.x
	tween.tween_property(self, "position:x", target_x, 0.4)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	
	tween.chain().tween_callback(func():
		visible = false
		card_closed.emit()
	)
