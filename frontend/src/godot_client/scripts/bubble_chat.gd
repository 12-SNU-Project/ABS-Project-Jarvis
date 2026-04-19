extends CanvasLayer

var tween: Tween
var _thinking_tween: Tween = null
var _dot_count: int = 0

@onready var chat_bubble = $ChatBubble
@onready var text_node = $ChatBubble/MarginContainer/BubbleChat

var avatar_node: Node = null
const char_time = 0.05

func _ready() -> void:
	chat_bubble.visible = false
	if not $ChatBubble/ChatDelayer.timeout.is_connected(_on_Timer_timeout):
		$ChatBubble/ChatDelayer.timeout.connect(_on_Timer_timeout)
	# Get avatar from parent scene
	avatar_node = get_parent().get_node_or_null("Avatar")

# ── Position ──────────────────────────────────────────────────────────────────
func _reposition_bubble():
	if avatar_node == null:
		return
	var av_x = avatar_node.position.x
	var av_y = avatar_node.position.y  # base Y (without float offset)
	# Bubble sits just above the avatar
	chat_bubble.position.x = max(10.0, av_x)
	chat_bubble.position.y = av_y - 130.0   # rough offset; refined below

func _reposition_after_layout():
	if avatar_node == null:
		return
	await get_tree().process_frame
	var av_x = avatar_node.position.x
	var av_y = avatar_node.position.y
	chat_bubble.position.x = max(10.0, av_x)
	chat_bubble.position.y = av_y - chat_bubble.size.y - 16.0

# ── Normal speech ─────────────────────────────────────────────────────────────
func set_text(new_text: String, wait_time: float = 3.0):
	_stop_thinking()
	_reposition_bubble()
	chat_bubble.visible = true

	$ChatBubble/ChatDelayer.wait_time = wait_time
	$ChatBubble/ChatDelayer.stop()

	text_node.text = new_text
	text_node.visible_characters = 0

	var duration = new_text.length() * char_time
	if tween and tween.is_valid():
		tween.kill()
	tween = create_tween()
	tween.tween_property(text_node, "visible_characters", new_text.length(), duration)
	tween.tween_callback(func(): $ChatBubble/ChatDelayer.start())

	# Reposition once layout is computed
	_reposition_after_layout()

# ── Thinking state (● ● ●) ────────────────────────────────────────────────────
func show_thinking():
	_stop_thinking()
	_reposition_bubble()
	chat_bubble.visible = true
	$ChatBubble/ChatDelayer.stop()

	text_node.text = "●"
	text_node.visible_characters = -1
	_dot_count = 1

	_thinking_tween = create_tween().set_loops()
	_thinking_tween.tween_callback(_tick_dots).set_delay(0.45)

func _tick_dots():
	_dot_count = (_dot_count % 3) + 1
	text_node.text = " ".join(Array(range(_dot_count)).map(func(_i): return "●"))
	text_node.visible_characters = -1

func _stop_thinking():
	if _thinking_tween and _thinking_tween.is_valid():
		_thinking_tween.kill()
		_thinking_tween = null

# ── Timer ─────────────────────────────────────────────────────────────────────
func _on_Timer_timeout() -> void:
	chat_bubble.visible = false
