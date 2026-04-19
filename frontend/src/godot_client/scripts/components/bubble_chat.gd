extends PanelContainer

# Bubble chat is FIXED in scene — no dynamic position tracking
var tween: Tween
var _thinking_tween: Tween = null
var _dot_count: int = 0

const CHAR_TIME = 0.05

@onready var text_node    = $BubbleMargin/BubbleChat
@onready var delayer      = $ChatDelayer

func _ready() -> void:
	visible = false
	delayer.timeout.connect(_on_timer_timeout)

# ── Normal speech ──────────────────────────────────────────────────────────────
func set_text(new_text: String, wait_time: float = 3.0):
	_stop_thinking()
	visible = true

	delayer.wait_time = wait_time
	delayer.stop()

	text_node.text = new_text
	text_node.visible_characters = 0

	if tween and tween.is_valid():
		tween.kill()
	tween = create_tween()
	tween.tween_property(text_node, "visible_characters", new_text.length(),
		new_text.length() * CHAR_TIME)
	tween.tween_callback(func(): delayer.start())

# ── Thinking state (● ● ●) ─────────────────────────────────────────────────────
func show_thinking():
	_stop_thinking()
	visible = true
	delayer.stop()

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

# ── Timer ──────────────────────────────────────────────────────────────────────
func _on_timer_timeout() -> void:
	visible = false
