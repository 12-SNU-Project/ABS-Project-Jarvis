extends PanelContainer

signal card_closed
signal summary_loaded(channel_name: String, msg_count: int)

enum State { IDLE, LOADING, SUCCESS, ERROR }

const API_URL    = "http://localhost:8000/api/v1/slack/summary"
const HEALTH_URL = "http://localhost:8000/api/v1/health"

@onready var http_req      = $HTTPRequest
@onready var health_req    = $HTTPRequestHealth
@onready var status_label  = $MarginContainer/MainScroll/VBoxContainer/HeaderBox/StatusLabel
@onready var meta_box      = $MarginContainer/MainScroll/VBoxContainer/MetaBox
@onready var channel_badge = $MarginContainer/MainScroll/VBoxContainer/MetaBox/ChannelBadge
@onready var count_badge   = $MarginContainer/MainScroll/VBoxContainer/MetaBox/CountBadge
@onready var model_badge   = $MarginContainer/MainScroll/VBoxContainer/MetaBox/ModelBadge
@onready var status_banner = $MarginContainer/MainScroll/VBoxContainer/StatusBanner
@onready var summary_list  = $MarginContainer/MainScroll/VBoxContainer/ContentRow/LeftPanel/SummaryScroll/SummaryList
@onready var channel_edit  = $MarginContainer/MainScroll/VBoxContainer/ContentRow/LeftPanel/FormBox/ChannelBox/ChannelEdit
@onready var date_edit     = $MarginContainer/MainScroll/VBoxContainer/ContentRow/LeftPanel/FormBox/Row2/DateBox/DateEdit
@onready var hours_spin    = $MarginContainer/MainScroll/VBoxContainer/ContentRow/LeftPanel/FormBox/Row2/HoursBox/HoursSpin
@onready var prompt_edit   = $MarginContainer/MainScroll/VBoxContainer/ContentRow/LeftPanel/FormBox/PromptBox/PromptEdit
@onready var submit_btn    = $MarginContainer/MainScroll/VBoxContainer/ContentRow/LeftPanel/FormBox/SubmitBtn
@onready var msg_list      = $MarginContainer/MainScroll/VBoxContainer/ContentRow/RightPanel/MsgScroll/MsgList

func _ready():
	modulate.a = 0.0
	visible = false
	http_req.request_completed.connect(_on_request_completed)
	health_req.request_completed.connect(_on_health_completed)
	submit_btn.pressed.connect(_on_submit_pressed)
	_set_status_unknown()

# ─── Status helpers ────────────────────────────────────────────────────────
func _set_status_unknown():
	status_label.text = "● Checking..."
	status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.4, 1))

func _set_status_ok(model_name: String = ""):
	var label = "● Connected"
	if model_name != "":
		label = "● Connected  /  " + model_name
	status_label.text = label
	status_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.6, 1))

func _set_status_err():
	status_label.text = "● Disconnected"
	status_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4, 1))

# ─── State ─────────────────────────────────────────────────────────────────
func _set_state(s: State, msg: String = ""):
	match s:
		State.IDLE:
			submit_btn.disabled = false
			submit_btn.text = "Slack 요약 불러오기"
			status_banner.visible = false
		State.LOADING:
			submit_btn.disabled = true
			submit_btn.text = "불러오는 중..."
			status_banner.visible = false
			_set_status_unknown()
		State.SUCCESS:
			submit_btn.disabled = false
			submit_btn.text = "다시 불러오기"
			status_banner.visible = false
		State.ERROR:
			submit_btn.disabled = false
			submit_btn.text = "다시 시도"
			status_banner.visible = true
			status_banner.text = "오류: " + msg

# ─── Submit ────────────────────────────────────────────────────────────────
func _on_submit_pressed():
	_set_state(State.LOADING)
	_clear_results()

	var body = JSON.stringify({
		"channel_id":     channel_edit.text.strip_edges(),
		"user_input":     prompt_edit.text.strip_edges(),
		"date":           date_edit.text.strip_edges(),
		"lookback_hours": int(hours_spin.value)
	})

	var err = http_req.request(API_URL, ["Content-Type: application/json"],
		HTTPClient.METHOD_POST, body)
	if err != OK:
		_set_state(State.ERROR, "HTTP 요청 실패 (%d)" % err)

# ─── Response ──────────────────────────────────────────────────────────────
func _on_request_completed(result: int, code: int, _headers, body: PackedByteArray):
	if result != HTTPRequest.RESULT_SUCCESS:
		_set_state(State.ERROR, "네트워크 오류")
		return

	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		_set_state(State.ERROR, "응답 파싱 실패")
		return

	var data: Dictionary = json.get_data()

	if code != 200:
		_set_state(State.ERROR, data.get("detail", "오류 %d" % code))
		return

	_set_state(State.SUCCESS)
	_render_meta(data)
	_populate_messages(data.get("messages", []))
	_animate_summary(data.get("summary_lines", []))
	summary_loaded.emit(data.get("channel_name", ""), data.get("message_count", 0))

# ─── Render helpers ────────────────────────────────────────────────────────
func _render_meta(data: Dictionary):
	meta_box.visible = true
	channel_badge.text = data.get("channel_name", channel_edit.text)
	count_badge.text   = "메시지 %d개" % data.get("message_count", 0)
	model_badge.text   = data.get("model", "")

func _clear_results():
	for c in summary_list.get_children(): c.queue_free()
	for c in msg_list.get_children():     c.queue_free()
	meta_box.visible = false

func _animate_summary(lines: Array):
	for i in range(lines.size()):
		await get_tree().create_timer(0.28).timeout
		_add_summary_item(i + 1, lines[i])

func _add_summary_item(idx: int, text: String):
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var num = Label.new()
	num.text = str(idx)
	num.custom_minimum_size = Vector2(28, 28)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	num.add_theme_color_override("font_color", Color(0.63, 0.83, 1.0))
	num.add_theme_font_size_override("font_size", 13)
	var num_style = StyleBoxFlat.new()
	num_style.bg_color = Color(0.23, 0.51, 0.96, 0.28)
	for corner in ["top_left","top_right","bottom_left","bottom_right"]:
		num_style.set("corner_radius_" + corner, 8)
	num.add_theme_stylebox_override("normal", num_style)

	var lbl = Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	lbl.add_theme_font_size_override("font_size", 13)

	row.add_child(num)
	row.add_child(lbl)
	summary_list.add_child(row)

	row.modulate.a = 0.0
	create_tween().tween_property(row, "modulate:a", 1.0, 0.4)

func _populate_messages(messages: Array):
	for msg in messages:
		var panel = PanelContainer.new()
		var ps = StyleBoxFlat.new()
		ps.bg_color = Color(0.059, 0.09, 0.165, 0.7)
		ps.border_width_left = 1
		ps.border_width_top = 1
		ps.border_width_right = 1
		ps.border_width_bottom = 1
		ps.border_color = Color(0.149, 0.169, 0.22, 1.0)
		for corner in ["top_left","top_right","bottom_left","bottom_right"]:
			ps.set("corner_radius_" + corner, 10)
		ps.content_margin_left = 12
		ps.content_margin_right = 12
		ps.content_margin_top = 9
		ps.content_margin_bottom = 9
		panel.add_theme_stylebox_override("panel", ps)

		var vb = VBoxContainer.new()
		vb.add_theme_constant_override("separation", 4)

		var u = Label.new()
		u.text = msg.get("user", "Unknown")
		u.add_theme_color_override("font_color", Color(0.55, 0.82, 1.0))
		u.add_theme_font_size_override("font_size", 11)

		var t = Label.new()
		t.text = msg.get("text", "")
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.add_theme_color_override("font_color", Color(0.86, 0.88, 0.94))
		t.add_theme_font_size_override("font_size", 13)

		vb.add_child(u)
		vb.add_child(t)
		panel.add_child(vb)
		msg_list.add_child(panel)

# ─── Health Check ─────────────────────────────────────────────────────────
func _run_health_check():
	_set_status_unknown()
	submit_btn.disabled = true
	health_req.request(HEALTH_URL)

func _on_health_completed(result: int, code: int, _h, body: PackedByteArray):
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_set_status_err()
		submit_btn.disabled = false
		return
	var json = JSON.new()
	var model_name = ""
	if json.parse(body.get_string_from_utf8()) == OK:
		model_name = json.get_data().get("model", "")
	_set_status_ok(model_name)
	submit_btn.disabled = false

# ─── Panel size helper ────────────────────────────────────────────────────
func _get_panel_size() -> Vector2:
	var parent = get_parent()
	var w = parent.size.x
	var h = parent.size.y
	if w <= 0.0 or h <= 0.0:
		var vp = get_viewport_rect().size
		w = vp.x
		h = vp.y - 300.0
	return Vector2(w, h)

# ─── Card show / hide ─────────────────────────────────────────────────────
func show_card():
	_set_state(State.IDLE)
	_clear_results()
	visible = true
	modulate.a = 0.0
	# 2프레임 대기 → CardAnchor 앱커 크기 확정
	await get_tree().process_frame
	await get_tree().process_frame

	var panel_size = _get_panel_size()
	custom_minimum_size = panel_size
	size = panel_size
	position = Vector2(0.0, panel_size.y)
	
	var tw = create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", 0.0, 0.6)
	tw.tween_property(self, "modulate:a", 1.0, 0.45)
	# Health check after slide completes
	await get_tree().create_timer(0.35).timeout
	_run_health_check()

func hide_card():
	if not visible:
		card_closed.emit()
		return
	var panel_h = _get_panel_size().y
	var tw = create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "position:y", panel_h, 0.45)
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(func():
		visible = false
		card_closed.emit()
	)
