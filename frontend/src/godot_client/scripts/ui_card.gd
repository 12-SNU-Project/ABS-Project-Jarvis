extends PanelContainer
class_name UICard

@export var background_texture: Texture2D

@onready var title_label = $MarginContainer/VBoxContainer/Title
@onready var content_label = $MarginContainer/VBoxContainer/ScrollContainer/Content

func _ready():
	if background_texture:
		var style = StyleBoxTexture.new()
		style.texture = background_texture
		add_theme_stylebox_override("panel", style)
	
	# Start hidden
	modulate.a = 0.0
	visible = false

func show_card(title: String, content: String):
	title_label.text = "[center]" + title + "[/center]"
	content_label.text = content
	
	visible = true
	var screen_size = get_viewport_rect().size
	
	# Start from right
	position.x = screen_size.x
	position.y = screen_size.y / 2.0 - size.y / 2.0
	modulate.a = 0.0
	
	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	
	# Fly in to center-right
	var target_x = screen_size.x / 2.0 + 50.0
	tween.tween_property(self, "position:x", target_x, 0.6)
	tween.tween_property(self, "modulate:a", 1.0, 0.4)

func hide_card():
	if not visible:
		return
		
	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	
	var target_x = get_viewport_rect().size.x
	tween.tween_property(self, "position:x", target_x, 0.4)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	
	tween.chain().tween_callback(func(): visible = false)
