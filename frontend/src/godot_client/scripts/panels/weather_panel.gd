extends PanelContainer

signal card_closed
signal weather_loaded(condition_name: String, temperature_c: float, summary: String, location: String)

enum State { IDLE, LOADING, SUCCESS, ERROR }

const API_URL := "http://localhost:8000/api/v1/briefings"
const MIN_CONTENT_HEIGHT := 640.0

@onready var http_req: HTTPRequest = $HTTPRequest
@onready var stage: Control = $Margin/Root/LeftColumn/StageFrame/WeatherStage
@onready var status_pill: Label = $Margin/Root/RightColumn/TopRow/StatusPill
@onready var location_label: Label = $Margin/Root/RightColumn/SnapshotCard/SnapshotMargin/SnapshotVBox/LocationLabel
@onready var temp_label: Label = $Margin/Root/RightColumn/SnapshotCard/SnapshotMargin/SnapshotVBox/TempLabel
@onready var condition_label: Label = $Margin/Root/RightColumn/SnapshotCard/SnapshotMargin/SnapshotVBox/ConditionLabel
@onready var summary_label: Label = $Margin/Root/RightColumn/SnapshotCard/SnapshotMargin/SnapshotVBox/SummaryLabel
@onready var recommendation_label: Label = $Margin/Root/RightColumn/SnapshotCard/SnapshotMargin/SnapshotVBox/RecommendationLabel
@onready var location_edit: LineEdit = $Margin/Root/RightColumn/ControlCard/ControlMargin/ControlVBox/FormGrid/LocationEdit
@onready var date_edit: LineEdit = $Margin/Root/RightColumn/ControlCard/ControlMargin/ControlVBox/FormGrid/DateEdit
@onready var fetch_btn: Button = $Margin/Root/RightColumn/ControlCard/ControlMargin/ControlVBox/FetchBtn
@onready var items_flow: HFlowContainer = $Margin/Root/RightColumn/ItemsCard/ItemsMargin/ItemsVBox/ItemsFlow
@onready var status_banner: Label = $Margin/Root/RightColumn/StatusBanner

var _has_loaded_once := false


func _ready() -> void:
	_install_outer_scroll(MIN_CONTENT_HEIGHT)
	modulate.a = 0.0
	visible = false
	http_req.request_completed.connect(_on_request_completed)
	fetch_btn.pressed.connect(_on_fetch_pressed)
	resized.connect(_fit_content_bounds)
	date_edit.text = Time.get_date_string_from_system()
	location_edit.text = "Seoul"
	_render_placeholder()
	call_deferred("_fit_content_bounds")


func _install_outer_scroll(minimum_content_height: float) -> void:
	var margin := $Margin
	var root: Control = $Margin/Root
	root.custom_minimum_size.y = minimum_content_height

	if root.get_parent() is ScrollContainer:
		return

	margin.remove_child(root)

	var scroll := ScrollContainer.new()
	scroll.name = "OuterScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	margin.add_child(scroll)
	scroll.add_child(root)


func _fit_content_bounds() -> void:
	var outer_scroll := get_node_or_null("Margin/OuterScroll") as ScrollContainer
	if outer_scroll == null or outer_scroll.get_child_count() == 0:
		return

	var root := outer_scroll.get_child(0) as Control
	if root == null:
		return

	var target_width := outer_scroll.size.x
	if target_width <= 0.0:
		target_width = size.x - 56.0
	if target_width <= 0.0:
		return

	root.custom_minimum_size = Vector2(target_width, max(root.custom_minimum_size.y, MIN_CONTENT_HEIGHT))
	root.size = Vector2(target_width, max(outer_scroll.size.y, MIN_CONTENT_HEIGHT))


func _set_state(state: State, message: String = "") -> void:
	match state:
		State.IDLE:
			fetch_btn.disabled = false
			fetch_btn.text = "날씨 무드 불러오기"
			status_banner.visible = false
			_set_status("READY", Color(0.5, 0.9, 1.0, 1.0))
		State.LOADING:
			fetch_btn.disabled = true
			fetch_btn.text = "스테이지 준비 중…"
			status_banner.visible = false
			_set_status("SYNCING", Color(1.0, 0.83, 0.45, 1.0))
		State.SUCCESS:
			fetch_btn.disabled = false
			fetch_btn.text = "다시 연출하기"
			status_banner.visible = false
		State.ERROR:
			fetch_btn.disabled = false
			fetch_btn.text = "다시 시도"
			status_banner.visible = true
			status_banner.text = "오류: " + message
			_set_status("OFFLINE", Color(1.0, 0.57, 0.5, 1.0))


func _set_status(text: String, color: Color) -> void:
	status_pill.text = "●  " + text
	status_pill.add_theme_color_override("font_color", color)


func _render_placeholder() -> void:
	location_label.text = "Seoul / Live Atmosphere"
	temp_label.text = "17°C"
	condition_label.text = "SUNNY"
	summary_label.text = "오늘의 날씨를 장면처럼 렌더링합니다. 위치와 날짜를 바꾸면 무드도 같이 달라집니다."
	recommendation_label.text = "가벼운 자켓과 셔츠 조합이 안정적입니다."
	_set_items(["light jacket", "shirt", "sneakers"])
	if stage and stage.has_method("set_weather"):
		stage.call("set_weather", "sunny", 17.0)


func _on_fetch_pressed() -> void:
	var location := location_edit.text.strip_edges()
	var date := date_edit.text.strip_edges()
	if location.is_empty():
		location = "Seoul"
		location_edit.text = location
	if date.is_empty():
		date = Time.get_date_string_from_system()
		date_edit.text = date

	_set_state(State.LOADING)

	var user_name := "Jarvis User"
	var auth_session := get_node_or_null("/root/AuthSession")
	if auth_session and auth_session.has_method("get_display_name"):
		var display_name := String(auth_session.call("get_display_name")).strip_edges()
		if not display_name.is_empty():
			user_name = display_name

	var body := JSON.stringify({
		"user_input": "오늘 날씨 브리핑해줘",
		"location": location,
		"date": date,
		"user_name": user_name
	})

	var err := http_req.request(
		API_URL,
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		body
	)
	if err != OK:
		_set_state(State.ERROR, "HTTP 요청 실패 (%d)" % err)


func _on_request_completed(result: int, response_code: int, _headers, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_set_state(State.ERROR, "서버 응답 오류 (code: %d)" % response_code)
		return

	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		_set_state(State.ERROR, "응답 파싱 실패")
		return

	var data: Dictionary = json.get_data()
	var weather: Dictionary = data.get("weather", {})
	if weather.is_empty():
		_set_state(State.ERROR, "weather 섹션이 비어 있습니다")
		return

	_render_weather(weather)


func _render_weather(weather: Dictionary) -> void:
	var location := String(weather.get("location", location_edit.text.strip_edges()))
	var condition := String(weather.get("condition", "clear"))
	var summary := String(weather.get("summary", "요약 정보가 없습니다."))
	var recommendation := String(weather.get("recommendation", "추천 정보가 없습니다."))
	var temperature_c := float(weather.get("temperature_c", 0.0))
	var items: Array = weather.get("items", [])
	var uses_mock := bool(weather.get("uses_mock", false))

	var feed_label := "Live"
	if uses_mock:
		feed_label = "Mock"
	location_label.text = "%s / %s feed" % [location, feed_label]
	temp_label.text = "%d°C" % int(round(temperature_c))
	condition_label.text = _condition_display(condition)
	summary_label.text = summary
	recommendation_label.text = recommendation
	_set_items(items)

	if stage and stage.has_method("set_weather"):
		stage.call("set_weather", condition, temperature_c)

	_has_loaded_once = true
	_set_state(State.SUCCESS)
	var status_text := "LIVE FEED"
	if uses_mock:
		status_text = "MOCK FEED"
	_set_status(status_text, Color(0.5, 0.95, 0.88, 1.0))
	_animate_snapshot()
	weather_loaded.emit(condition, temperature_c, summary, location)


func _animate_snapshot() -> void:
	var elements: Array[Control] = [temp_label, condition_label, summary_label, recommendation_label]
	for i in range(elements.size()):
		var element := elements[i]
		element.modulate.a = 0.0
		element.scale = Vector2(0.98, 0.98)
		var tw := create_tween()
		tw.tween_interval(i * 0.05)
		tw.tween_property(element, "modulate:a", 1.0, 0.2)
		tw.parallel().tween_property(element, "scale", Vector2.ONE, 0.24)


func _condition_display(condition: String) -> String:
	var normalized := condition.strip_edges().to_lower()
	if normalized.contains("sun") or normalized.contains("clear"):
		return "SUNNY / CLEAR"
	if normalized.contains("cloud") or normalized.contains("fog"):
		return "CLOUDY / SOFT"
	if normalized.contains("storm"):
		return "STORM / ALERT"
	if normalized.contains("rain"):
		return "RAIN / COOL"
	if normalized.contains("snow"):
		return "SNOW / CHILL"
	return normalized.to_upper()


func _set_items(items: Array) -> void:
	for child in items_flow.get_children():
		child.queue_free()

	for i in range(items.size()):
		var chip := _make_item_chip(String(items[i]), i)
		items_flow.add_child(chip)
		var tw := create_tween()
		tw.tween_interval(i * 0.04)
		tw.tween_property(chip, "modulate:a", 1.0, 0.16)
		tw.parallel().tween_property(chip, "scale", Vector2.ONE, 0.2)


func _make_item_chip(text: String, index: int) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.modulate.a = 0.0
	chip.scale = Vector2(0.94, 0.94)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12 + index * 0.01, 0.19 + index * 0.015, 0.31 + index * 0.018, 1.0)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.38, 0.72, 0.98, 0.28)
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_right = 18
	style.corner_radius_bottom_left = 18
	style.content_margin_left = 14
	style.content_margin_top = 8
	style.content_margin_right = 14
	style.content_margin_bottom = 8
	chip.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.84, 0.95, 1.0, 1.0))
	chip.add_child(label)
	return chip


func _get_panel_size() -> Vector2:
	var parent := get_parent()
	var width: float = parent.size.x
	var height: float = parent.size.y
	if width <= 0.0 or height <= 0.0:
		var viewport_size := get_viewport_rect().size
		width = viewport_size.x
		height = viewport_size.y - 300.0
	return Vector2(width, height)


func show_card() -> void:
	_set_state(State.IDLE)
	visible = true
	modulate.a = 0.0
	await get_tree().process_frame
	await get_tree().process_frame

	var outer_scroll := get_node_or_null("Margin/OuterScroll")
	if outer_scroll and outer_scroll is ScrollContainer:
		outer_scroll.scroll_vertical = 0

	var panel_size := _get_panel_size()
	custom_minimum_size = panel_size
	size = panel_size
	position = Vector2(0.0, panel_size.y)
	_fit_content_bounds()

	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", 0.0, 0.55)
	tw.tween_property(self, "modulate:a", 1.0, 0.4)

	await get_tree().create_timer(0.22).timeout
	if not _has_loaded_once:
		_on_fetch_pressed()


func hide_card() -> void:
	if not visible:
		card_closed.emit()
		return

	var panel_height := _get_panel_size().y
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "position:y", panel_height, 0.42)
	tw.tween_property(self, "modulate:a", 0.0, 0.28)
	tw.chain().tween_callback(func():
		visible = false
		card_closed.emit()
	)
