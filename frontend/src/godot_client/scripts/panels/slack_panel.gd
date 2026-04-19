extends PanelContainer

signal card_closed
signal summary_loaded(channel_name: String, msg_count: int)

enum State { IDLE, LOADING, SUCCESS, ERROR }

const API_URL := "http://localhost:8000/api/v1/slack/summary"
const HEALTH_URL := "http://localhost:8000/api/v1/health"
const MIN_CONTENT_HEIGHT := 620.0

@onready var http_req: HTTPRequest = $HTTPRequest
@onready var health_req: HTTPRequest = $HTTPRequestHealth
@onready var status_label: Label = $Margin/Root/TopRow/StatusPill
@onready var summary_meta: Label = $Margin/Root/Body/LeftColumn/SummaryCard/SummaryMargin/SummaryVBox/SummaryHeader/SummaryMeta
@onready var summary_list: VBoxContainer = $Margin/Root/Body/LeftColumn/SummaryCard/SummaryMargin/SummaryVBox/SummaryScroll/SummaryList
@onready var channel_edit: LineEdit = $Margin/Root/Body/RightColumn/ControlCard/ControlMargin/ControlVBox/FormGrid/ChannelEdit
@onready var date_edit: LineEdit = $Margin/Root/Body/RightColumn/ControlCard/ControlMargin/ControlVBox/FormGrid/DateEdit
@onready var hours_spin: SpinBox = $Margin/Root/Body/RightColumn/ControlCard/ControlMargin/ControlVBox/FormGrid/HoursSpin
@onready var prompt_edit: TextEdit = $Margin/Root/Body/RightColumn/ControlCard/ControlMargin/ControlVBox/PromptEdit
@onready var submit_btn: Button = $Margin/Root/Body/RightColumn/ControlCard/ControlMargin/ControlVBox/SubmitBtn
@onready var count_label: Label = $Margin/Root/Body/RightColumn/FeedCard/FeedMargin/FeedVBox/FeedHeader/CountLabel
@onready var msg_list: VBoxContainer = $Margin/Root/Body/RightColumn/FeedCard/FeedMargin/FeedVBox/FeedScroll/MessageList
@onready var status_banner: Label = $Margin/Root/StatusBanner


func _ready() -> void:
	_install_outer_scroll(MIN_CONTENT_HEIGHT)
	modulate.a = 0.0
	visible = false
	http_req.request_completed.connect(_on_request_completed)
	health_req.request_completed.connect(_on_health_completed)
	submit_btn.pressed.connect(_on_submit_pressed)
	resized.connect(_fit_content_bounds)
	date_edit.text = Time.get_date_string_from_system()
	_set_state(State.IDLE)
	_render_idle_preview()
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
		target_width = size.x - 52.0
	if target_width <= 0.0:
		return

	root.custom_minimum_size = Vector2(target_width, max(root.custom_minimum_size.y, MIN_CONTENT_HEIGHT))
	root.size = Vector2(target_width, max(outer_scroll.size.y, MIN_CONTENT_HEIGHT))


func _set_status_unknown() -> void:
	status_label.text = "●  CHECKING"
	status_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45, 1.0))


func _set_status_ok(model_name: String = "") -> void:
	var label := "●  LINKED"
	if not model_name.is_empty():
		label += " / " + model_name
	status_label.text = label
	status_label.add_theme_color_override("font_color", Color(0.52, 0.95, 0.85, 1.0))


func _set_status_err() -> void:
	status_label.text = "●  OFFLINE"
	status_label.add_theme_color_override("font_color", Color(1.0, 0.57, 0.5, 1.0))


func _set_state(state: State, message: String = "") -> void:
	match state:
		State.IDLE:
			submit_btn.disabled = false
			submit_btn.text = "팀 신호 불러오기"
			status_banner.visible = false
		State.LOADING:
			submit_btn.disabled = true
			submit_btn.text = "신호 수집 중…"
			status_banner.visible = false
		State.SUCCESS:
			submit_btn.disabled = false
			submit_btn.text = "다시 브리핑"
			status_banner.visible = false
		State.ERROR:
			submit_btn.disabled = false
			submit_btn.text = "다시 시도"
			status_banner.visible = true
			status_banner.text = "오류: " + message


func _on_submit_pressed() -> void:
	_set_state(State.LOADING)
	_clear_results()

	var body := JSON.stringify({
		"channel_id": channel_edit.text.strip_edges(),
		"user_input": prompt_edit.text.strip_edges(),
		"date": date_edit.text.strip_edges(),
		"lookback_hours": int(hours_spin.value)
	})

	var err := http_req.request(
		API_URL,
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		body
	)
	if err != OK:
		_set_state(State.ERROR, "HTTP 요청 실패 (%d)" % err)


func _on_request_completed(result: int, code: int, _headers, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_set_state(State.ERROR, "네트워크 오류")
		return
	if code != 200:
		_set_state(State.ERROR, "서버 응답 오류 (code: %d)" % code)
		return

	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		_set_state(State.ERROR, "응답 파싱 실패")
		return

	var data: Dictionary = json.get_data()
	var summary := String(data.get("summary", ""))
	var messages: Array = data.get("messages", [])
	var channel := String(data.get("channel_id", "unknown"))

	_set_state(State.SUCCESS)
	_populate_summary(summary)
	_populate_messages(messages)
	summary_loaded.emit(channel, messages.size())


func _populate_summary(text: String) -> void:
	for child in summary_list.get_children():
		child.queue_free()

	var points := _extract_summary_points(text)
	summary_meta.text = "%d signal cards" % points.size()

	for i in range(points.size()):
		var card := _make_summary_card(i, points[i])
		summary_list.add_child(card)
		_animate_entry(card, i)


func _extract_summary_points(text: String) -> Array[String]:
	var cleaned := text.strip_edges()
	var points: Array[String] = []

	if cleaned.is_empty():
		return ["요약 결과가 비어 있습니다. 프롬프트를 조금 더 구체적으로 입력해보세요."]

	for raw_line in cleaned.split("\n", false):
		var line := raw_line.strip_edges()
		if line.is_empty():
			continue
		if line.begins_with("-") or line.begins_with("•") or line.begins_with("*"):
			line = line.substr(1).strip_edges()
		points.append(line)
		if points.size() >= 6:
			return points

	if points.size() <= 1:
		points.clear()
		var sentence_text := cleaned.replace("\n", " ")
		for raw_sentence in sentence_text.split(". ", false):
			var sentence := raw_sentence.strip_edges()
			if sentence.is_empty():
				continue
			points.append(sentence)
			if points.size() >= 5:
				break

	if points.is_empty():
		points.append(cleaned)
	return points


func _make_summary_card(index: int, text: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.modulate.a = 0.0
	card.scale = Vector2(0.97, 0.97)
	card.custom_minimum_size = Vector2(0.0, 94.0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09 + index * 0.012, 0.13 + index * 0.01, 0.2 + index * 0.012, 1.0)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.42, 0.74, 0.98, 0.18)
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_right = 20
	style.corner_radius_bottom_left = 20
	card.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var kicker := Label.new()
	kicker.text = "POINT %02d" % int(index + 1)
	kicker.add_theme_font_size_override("font_size", 11)
	kicker.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0, 0.82))
	vbox.add_child(kicker)

	var body := Label.new()
	body.text = text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", Color(0.9, 0.96, 1.0, 0.96))
	vbox.add_child(body)
	return card


func _populate_messages(messages: Array) -> void:
	for child in msg_list.get_children():
		child.queue_free()

	count_label.text = "%d raw messages" % messages.size()

	for i in range(messages.size()):
		var card := _make_message_card(messages[i], i)
		msg_list.add_child(card)
		_animate_entry(card, i)


func _make_message_card(message: Dictionary, index: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.modulate.a = 0.0
	card.scale = Vector2(0.975, 0.975)
	card.custom_minimum_size = Vector2(0.0, 108.0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12 + index * 0.005, 0.18 + index * 0.008, 0.98)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.38, 0.68, 0.92, 0.16)
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_right = 20
	style.corner_radius_bottom_left = 20
	card.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	card.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)

	var user_name := String(message.get("user", "?"))
	var avatar_chip := PanelContainer.new()
	avatar_chip.custom_minimum_size = Vector2(44.0, 44.0)
	var avatar_style := StyleBoxFlat.new()
	avatar_style.bg_color = Color(0.16, 0.28, 0.42, 1.0)
	avatar_style.corner_radius_top_left = 999
	avatar_style.corner_radius_top_right = 999
	avatar_style.corner_radius_bottom_right = 999
	avatar_style.corner_radius_bottom_left = 999
	avatar_chip.add_theme_stylebox_override("panel", avatar_style)
	row.add_child(avatar_chip)

	var avatar_center := CenterContainer.new()
	avatar_chip.add_child(avatar_center)
	var initials := Label.new()
	initials.text = _initials_from_user(user_name)
	initials.add_theme_font_size_override("font_size", 13)
	initials.add_theme_color_override("font_color", Color(0.88, 0.97, 1.0, 1.0))
	avatar_center.add_child(initials)

	var body_box := VBoxContainer.new()
	body_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_box.add_theme_constant_override("separation", 4)
	row.add_child(body_box)

	var user_label := Label.new()
	user_label.text = user_name
	user_label.add_theme_font_size_override("font_size", 13)
	user_label.add_theme_color_override("font_color", Color(0.56, 0.9, 1.0, 0.82))
	body_box.add_child(user_label)

	var content_label := Label.new()
	content_label.text = String(message.get("text", ""))
	content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_label.add_theme_font_size_override("font_size", 14)
	content_label.add_theme_color_override("font_color", Color(0.9, 0.96, 1.0, 0.95))
	body_box.add_child(content_label)

	var ts_value := String(message.get("ts", "")).strip_edges()
	if not ts_value.is_empty():
		var ts_label := Label.new()
		ts_label.text = ts_value
		ts_label.add_theme_font_size_override("font_size", 11)
		ts_label.add_theme_color_override("font_color", Color(0.62, 0.76, 0.88, 0.65))
		body_box.add_child(ts_label)

	return card


func _initials_from_user(user_name: String) -> String:
	var trimmed := user_name.strip_edges()
	if trimmed.is_empty():
		return "?"

	var parts := trimmed.split(" ", false)
	if parts.size() >= 2:
		return (parts[0].substr(0, 1) + parts[1].substr(0, 1)).to_upper()
	return trimmed.substr(0, min(2, trimmed.length())).to_upper()


func _animate_entry(control: Control, index: int) -> void:
	var tw := create_tween()
	tw.tween_interval(index * 0.05)
	tw.tween_property(control, "modulate:a", 1.0, 0.18)
	tw.parallel().tween_property(control, "scale", Vector2.ONE, 0.22)


func _clear_results() -> void:
	for child in summary_list.get_children():
		child.queue_free()
	for child in msg_list.get_children():
		child.queue_free()
	summary_meta.text = "0 signal cards"
	count_label.text = "0 raw messages"


func _render_idle_preview() -> void:
	_clear_results()

	var preview_card := _make_summary_card(0, "채널을 선택하면 최근 대화를 카드 단위 브리프로 분해해서 보여줍니다.")
	summary_list.add_child(preview_card)
	_animate_entry(preview_card, 0)
	summary_meta.text = "preview"

	var preview_msg := {
		"user": "Jarvis",
		"text": "요청을 보내면 raw 메시지 피드가 이 영역에서 순차적으로 등장합니다."
	}
	var preview_card_msg := _make_message_card(preview_msg, 0)
	msg_list.add_child(preview_card_msg)
	_animate_entry(preview_card_msg, 0)
	count_label.text = "preview"


func _run_health_check() -> void:
	_set_status_unknown()
	submit_btn.disabled = true
	health_req.request(HEALTH_URL)


func _on_health_completed(result: int, code: int, _headers, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_set_status_err()
		submit_btn.disabled = false
		return

	var json := JSON.new()
	var model_name := ""
	if json.parse(body.get_string_from_utf8()) == OK:
		model_name = String(json.get_data().get("model", ""))
	_set_status_ok(model_name)
	submit_btn.disabled = false


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

	await get_tree().create_timer(0.26).timeout
	_run_health_check()


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
