extends PanelContainer
class_name UICard

signal card_closed

@export var background_texture: Texture2D

@onready var title_label   = $MarginContainer/VBoxContainer/Title
@onready var content_label = $MarginContainer/VBoxContainer/ScrollContainer/Content

func _ready():
	if background_texture:
		var style = StyleBoxTexture.new()
		style.texture = background_texture
		add_theme_stylebox_override("panel", style)
	modulate.a = 0.0
	visible = false

# ── 부모(CardAnchor) 실제 크기 읽기 ────────────────────────────────────────────
func _get_panel_size() -> Vector2:
	# 2프레임 대기로 앵커 레이아웃이 확정된 뒤 읽는다
	var parent = get_parent()
	var w = parent.size.x
	var h = parent.size.y
	# 폴백: 아직 0이면 viewport 기반으로 직접 계산
	if w <= 0.0 or h <= 0.0:
		var vp = get_viewport_rect().size
		w = vp.x
		h = vp.y - 300.0  # TopZone 300px 제외
	return Vector2(w, h)

func show_card(title: String, content: String):
	title_label.text = "[center]" + title + "[/center]"
	content_label.text = content

	visible = true
	modulate.a = 0.0

	# 2프레임 대기 → CardAnchor 앵커 크기 확정
	await get_tree().process_frame
	await get_tree().process_frame

	var panel_size = _get_panel_size()
	custom_minimum_size = panel_size
	size = panel_size

	# CardAnchor 하단에서 시작 → y=0으로 슬라이드 업
	position = Vector2(0.0, panel_size.y)

	var tw = create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", 0.0, 0.55)
	tw.tween_property(self, "modulate:a", 1.0, 0.4)

func hide_card():
	if not visible:
		card_closed.emit()
		return

	var panel_h = _get_panel_size().y
	var tw = create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "position:y", panel_h, 0.4)
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(func():
		visible = false
		card_closed.emit()
	)
