extends PanelContainer

signal card_closed

@onready var summary_content = $MarginContainer/VBoxContainer/ContentRow/LeftPanel/SummaryScroll/SummaryContent
@onready var submit_btn = $MarginContainer/VBoxContainer/ContentRow/LeftPanel/SubmitBtn

const MOCK_SUMMARY = """[b]1.[/b] 핀테크와 암호 과제 1,2는 내일까지 제출이고, 암호문 제출 과제와 24일까지인 과제도 있어 마감일을 과제별로 다시 확인하기로 했어.

[b]2.[/b] 암호문 과제는 설명 PDF를 다시 읽어봐야 할 정도로 이해가 부족해 보이며, 연습문제와 파이썬 코딩 과제가 섞여 있어 혼선이 있었어.

[b]3.[/b] 기업 배정 결과는 빠르면 금요일, 늦어도 주말 안에 안내받기로 했지만 아직 연락이 없어 다들 기다리고 있어."""

func _ready():
	modulate.a = 0.0
	visible = false
	submit_btn.pressed.connect(_on_submit_pressed)

func _on_submit_pressed():
	submit_btn.text = "불러오는 중..."
	submit_btn.disabled = true

	# Simulate API delay with mock data
	await get_tree().create_timer(1.2).timeout
	summary_content.text = MOCK_SUMMARY
	summary_content.visible_characters = 0

	var tween = create_tween()
	tween.tween_property(summary_content, "visible_characters", len(MOCK_SUMMARY), 2.0)
	tween.tween_callback(func():
		submit_btn.text = "Slack 요약 불러오기"
		submit_btn.disabled = false
	)

func show_card():
	# Reset summary on each open
	summary_content.text = "[color=#888]결과가 여기에 표시됩니다.\n요약 버튼을 눌러 Slack 데이터를 불러오세요.[/color]"
	submit_btn.text = "Slack 요약 불러오기"
	submit_btn.disabled = false

	visible = true
	modulate.a = 0.0
	await get_tree().process_frame

	var screen_size = get_viewport_rect().size
	var center_x = (screen_size.x - size.x) / 2.0 + 50.0
	var center_y = (screen_size.y - size.y) / 2.0

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
