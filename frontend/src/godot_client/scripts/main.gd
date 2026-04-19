extends Control

@onready var ui_layer = $UI
@onready var ui_card = $UI/CardAnchor/UICard
@onready var slack_panel = $UI/CardAnchor/SlackDemoPanel
@onready var card_anchor = $UI/CardAnchor
@onready var avatar = $Avatar

# Buttons
@onready var weather_btn = $UI/Dock/VBoxContainer/BtnWeather
@onready var calendar_btn = $UI/Dock/VBoxContainer/BtnCalendar
@onready var slack_btn = $UI/Dock/VBoxContainer/BtnSlack
@onready var admin_btn = $UI/Dock/VBoxContainer/BtnAdmin

var http_request: HTTPRequest
var active_card = null
var is_switching = false

func _ready():
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)
	
	weather_btn.pressed.connect(func(): _fetch_mock_data("weather"))
	calendar_btn.pressed.connect(func(): _fetch_mock_data("calendar"))
	slack_btn.pressed.connect(func(): _fetch_mock_data("slack"))
	admin_btn.pressed.connect(func(): _fetch_mock_data("admin"))
	
	# Close card when clicking outside
	card_anchor.gui_input.connect(_on_card_anchor_gui_input)
	# By default, don't block clicks unless card is visible
	card_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _fetch_mock_data(feature: String):
	if is_switching:
		return
		
	is_switching = true
	
	if active_card:
		active_card.hide_card()
		await active_card.card_closed
		active_card = null
	
	ui_layer.set_text("AI: " + feature + " 정보를 불러오는 중입니다...")
	
	var title = ""
	var content = ""
	
	match feature:
		"weather":
			title = "Weather Briefing"
			content = "Location: Seoul\nTemperature: 17°C\n\nSummary: 서울 기준 맑고 일교차가 있어 가벼운 겉옷이 필요합니다."
		"calendar":
			title = "Schedule Briefing"
			content = "Date: 2026-04-18\n\n오늘 3개의 일정이 있습니다:\n1. 10:00 AM - 주간 회의\n2. 1:00 PM - 클라이언트 미팅\n3. 4:00 PM - 프로젝트 리뷰"
		"slack":
			ui_layer.set_text("AI: Slack 데모 패널을 엽니다.")
			card_anchor.mouse_filter = Control.MOUSE_FILTER_STOP
			slack_panel.show_card()
			active_card = slack_panel
			avatar.move_for_panel(slack_panel)
			is_switching = false
			return
		"admin":
			title = "Admin Dashboard"
			content = "시스템 지표 상태:\n- CPU 사용량: 45%\n- 메모리 사용량: 60%\n- 모든 서비스 정상 작동 중."
			
	ui_layer.set_text("AI: " + feature + " 데이터를 요약해 드립니다.")
	
	# Enable blocking clicks outside the card
	card_anchor.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_card.show_card(title, content)
	active_card = ui_card
	avatar.move_for_panel(ui_card)
	
	is_switching = false

func _on_card_anchor_gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if active_card and not is_switching:
			active_card.hide_card()
			active_card = null
			avatar.move_for_panel(null)
			card_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_request_completed(result, response_code, headers, body):
	if response_code == 200:
		pass
