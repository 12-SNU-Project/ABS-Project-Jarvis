extends CanvasLayer

var tween : Tween
@onready var text_node = $ChatBubble/MarginContainer/BubbleChat

const char_time = 0.05

func _ready() -> void:
	$ChatBubble.visible = true
	if not $ChatBubble/ChatDelayer.timeout.is_connected(_on_Timer_timeout):
		$ChatBubble/ChatDelayer.timeout.connect(_on_Timer_timeout)

func set_text(new_text: String, wait_time: float = 3.0):
	$ChatBubble.visible = true
	
	$ChatBubble/ChatDelayer.wait_time = wait_time
	$ChatBubble/ChatDelayer.stop()
	
	text_node.text = new_text
	text_node.visible_characters = 0
	
	# duration: 글자 수 * 글자당 딜레이
	var duration = new_text.length() * char_time
	
	if tween and tween.is_valid():
		tween.kill()
	tween = create_tween()
	
	# 한 글자씩 나타나도록 visible_characters 속성을 Tween (부드러운 크기 변형 없음)
	tween.tween_property(text_node, "visible_characters", new_text.length(), duration)
	
	# 타이핑이 끝나면 타이머 시작
	tween.tween_callback(func(): $ChatBubble/ChatDelayer.start())

func _on_Timer_timeout() -> void:
	$ChatBubble.visible = false
