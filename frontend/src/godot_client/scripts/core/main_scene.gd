extends Control

# ─────────────────────────────────────────────────────────────────────────────
# Main Scene — orchestrates all panels and the chatbot avatar
# ─────────────────────────────────────────────────────────────────────────────

@onready var avatar        = $TopZone/Avatar
@onready var chat_bubble   = $UI/ChatBubble
@onready var card_anchor   = $UI/CardAnchor
@onready var slack_panel   = $UI/CardAnchor/SlackPanel
@onready var calendar_panel= $UI/CardAnchor/CalendarPanel

# Dock buttons
@onready var btn_weather  = $UI/Dock/DockMargin/VBox/BtnWeather
@onready var btn_calendar = $UI/Dock/DockMargin/VBox/BtnCalendar
@onready var btn_slack    = $UI/Dock/DockMargin/VBox/BtnSlack
@onready var btn_admin    = $UI/Dock/DockMargin/VBox/BtnAdmin

var active_panel = null
var current_feature = ""
var is_switching = false

func _ready():
	btn_weather.pressed.connect(func(): _open_panel("weather"))
	btn_calendar.pressed.connect(func(): _open_panel("calendar"))
	btn_slack.pressed.connect(func(): _open_panel("slack"))
	btn_admin.pressed.connect(func(): _open_panel("admin"))

	card_anchor.gui_input.connect(_on_card_anchor_input)
	card_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE

	slack_panel.summary_loaded.connect(_on_slack_loaded)

	await get_tree().process_frame
	chat_bubble.set_text("AI: 안녕하세요! 무엇을 도와드릴까요?", 5.0)

# ─── Panel Orchestration ──────────────────────────────────────────────────────
func _open_panel(feature: String):
	if is_switching: return

	# Toggle off
	if current_feature == feature and active_panel != null:
		is_switching = true
		active_panel.hide_card()
		await active_panel.card_closed
		active_panel = null
		current_feature = ""
		avatar.reset_anim()
		chat_bubble.set_text("AI: 무엇을 도와드릴까요?", 4.0)
		is_switching = false
		card_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return

	is_switching = true
	current_feature = feature

	# Close existing panel
	if active_panel != null:
		active_panel.hide_card()
		await active_panel.card_closed
		active_panel = null
		avatar.reset_anim()

	# Show thinking
	chat_bubble.show_thinking()
	avatar.react_thinking()

	await get_tree().create_timer(0.4).timeout

	match feature:
		"slack":
			active_panel = slack_panel
			card_anchor.mouse_filter = Control.MOUSE_FILTER_STOP
			slack_panel.show_card()
			avatar.react_card_open()
			await get_tree().create_timer(0.7).timeout
			chat_bubble.set_text("AI: Slack 채널 요약을 요청해보세요!", 5.0)
			avatar.react_speaking()
		"calendar":
			active_panel = calendar_panel
			card_anchor.mouse_filter = Control.MOUSE_FILTER_STOP
			calendar_panel.show_card()
			avatar.react_card_open()
			await get_tree().create_timer(0.7).timeout
			chat_bubble.set_text("AI: 날짜를 선택하고 일정을 확인해보세요!", 5.0)
			avatar.react_speaking()
		"weather":
			chat_bubble.set_text("AI: 오늘 서울은 맑고 17°C 입니다. ☀", 5.0)
			avatar.react_speaking()
		"admin":
			chat_bubble.set_text("AI: 모든 서비스가 정상 작동 중입니다. ✓", 5.0)
			avatar.react_speaking()

	is_switching = false

func _on_card_anchor_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if active_panel and not is_switching:
			active_panel.hide_card()
			active_panel = null
			current_feature = ""
			avatar.reset_anim()
			card_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_slack_loaded(channel: String, count: int):
	avatar.react_speaking()
	chat_bubble.set_text("AI: %s 채널 메시지 %d개를 요약했어요! 👍" % [channel, count], 6.0)
	avatar.set_mood_happy()
