extends Node2D

@onready var chat_bubble = $SimsSceneNode/AIChatBubble

# Weather
@onready var weather_label = $CanvasLayer/Control/MarginContainer/VBoxContainer/UIContainer/MarginContainer/TabContainer/Weather/Label
@onready var weather_btn = $CanvasLayer/Control/MarginContainer/VBoxContainer/UIContainer/MarginContainer/TabContainer/Weather/Button

# Calendar
@onready var calendar_label = $CanvasLayer/Control/MarginContainer/VBoxContainer/UIContainer/MarginContainer/TabContainer/Calendar/Label
@onready var calendar_btn = $CanvasLayer/Control/MarginContainer/VBoxContainer/UIContainer/MarginContainer/TabContainer/Calendar/Button

# Slack
@onready var slack_label = $CanvasLayer/Control/MarginContainer/VBoxContainer/UIContainer/MarginContainer/TabContainer/Slack/Label
@onready var slack_btn = $CanvasLayer/Control/MarginContainer/VBoxContainer/UIContainer/MarginContainer/TabContainer/Slack/Button

# Admin
@onready var admin_label = $CanvasLayer/Control/MarginContainer/VBoxContainer/UIContainer/MarginContainer/TabContainer/Admin/Label
@onready var admin_btn = $CanvasLayer/Control/MarginContainer/VBoxContainer/UIContainer/MarginContainer/TabContainer/Admin/Button

# Presentation
@onready var presentation_label = $CanvasLayer/Control/MarginContainer/VBoxContainer/UIContainer/MarginContainer/TabContainer/Presentation/Label
@onready var presentation_btn = $CanvasLayer/Control/MarginContainer/VBoxContainer/UIContainer/MarginContainer/TabContainer/Presentation/Button

# HTTP Request for actual API calls
var http_request: HTTPRequest

func _ready():
	# Setup HTTP Request node
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)
	
	# Connect buttons
	weather_btn.pressed.connect(func(): _fetch_mock_data("weather"))
	calendar_btn.pressed.connect(func(): _fetch_mock_data("calendar"))
	slack_btn.pressed.connect(func(): _fetch_mock_data("slack"))
	admin_btn.pressed.connect(func(): _fetch_mock_data("admin"))
	presentation_btn.pressed.connect(func(): _fetch_mock_data("presentation"))

func _fetch_mock_data(feature: String):
	chat_bubble.text = "AI: Fetching data for " + feature + "..."
	
	# Here we would normally make a request to localhost FastAPI
	# For prototype, we will just simulate a response based on the spec
	
	var mock_response = ""
	match feature:
		"weather":
			mock_response = "{\n  \"owner\": \"조수빈\",\n  \"feature\": \"weather\",\n  \"location\": \"Seoul\",\n  \"temperature_c\": 17,\n  \"summary\": \"Seoul 기준 맑고 일교차가 있어 가벼운 겉옷이 필요합니다.\"\n}"
			weather_label.text = "Response:\n" + mock_response
		"calendar":
			mock_response = "{\n  \"owner\": \"김재희\",\n  \"feature\": \"calendar\",\n  \"date\": \"2026-04-18\",\n  \"summary\": \"오늘 3개의 일정이 있습니다.\"\n}"
			calendar_label.text = "Response:\n" + mock_response
		"slack":
			mock_response = "{\n  \"owner\": \"문이현\",\n  \"feature\": \"slack\",\n  \"summary\": \"읽지 않은 메시지 요약입니다.\"\n}"
			slack_label.text = "Response:\n" + mock_response
		"admin":
			mock_response = "{\n  \"owner\": \"나정연\",\n  \"feature\": \"admin\",\n  \"summary\": \"시스템 지표 상태입니다.\"\n}"
			admin_label.text = "Response:\n" + mock_response
		"presentation":
			mock_response = "{\n  \"owner\": \"오승담\",\n  \"feature\": \"presentation\",\n  \"demo_title\": \"Jarvis MVP Demo\",\n  \"closing_message\": \"감사합니다.\"\n}"
			presentation_label.text = "Response:\n" + mock_response
			
	chat_bubble.text = "AI: Received JSON data for " + feature + ". Check the UI panel below."

func _on_request_completed(result, response_code, headers, body):
	# Example handler for actual backend connection
	if response_code == 200:
		var json = JSON.new()
		var parse_result = json.parse(body.get_string_from_utf8())
		if parse_result == OK:
			chat_bubble.text = "AI: Backend data received successfully!"
