extends PanelContainer

signal card_closed
signal summary_loaded(channel_name: String, msg_count: int)

enum State { IDLE, LOADING, SUCCESS, ERROR }

const API_URL    = "http://localhost:8000/api/v1/slack/summary"
const HEALTH_URL = "http://localhost:8000/api/v1/health"

@onready var http_req      = $HTTPRequest
@onready var health_req    = $HTTPRequestHealth
@onready var status_label  = $Margin/VBox/HeaderRow/StatusLabel
@onready var summary_list  = $Margin/VBox/ContentRow/LeftCol/SummaryPanel/SummaryScroll/SummaryList
@onready var channel_edit  = $Margin/VBox/ContentRow/RightCol/QueryBox/Grid/ChannelEdit
@onready var date_edit     = $Margin/VBox/ContentRow/RightCol/QueryBox/Grid/DateEdit
@onready var hours_spin    = $Margin/VBox/ContentRow/RightCol/QueryBox/Grid/HoursSpin
@onready var prompt_edit   = $Margin/VBox/ContentRow/RightCol/PromptBox/PromptEdit
@onready var submit_btn    = $Margin/VBox/ContentRow/RightCol/SubmitBtn
@onready var status_banner = $Margin/VBox/StatusBanner
@onready var msg_list      = $Margin/VBox/ContentRow/RightCol/RawBox/RawScroll/MsgList

func _ready():
	modulate.a = 0.0
	visible = false
	http_req.request_completed.connect(_on_request_completed)
	health_req.request_completed.connect(_on_health_completed)
	submit_btn.pressed.connect(_on_submit_pressed)
	_set_state(State.IDLE)

# ─── Status ─────────────────────────────────────────────────────────────────
func _set_status_unknown():
	status_label.text = "● Checking…"
	status_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.2, 1))

func _set_status_ok(model_name: String = ""):
	var label = "● Connected"
	if model_name != "": label = "● Connected / " + model_name
	status_label.text = label
	status_label.add_theme_color_override("font_color", Color(0.25, 0.75, 0.55, 1))

func _set_status_err():
	status_label.text = "● Disconnected"
	status_label.add_theme_color_override("font_color", Color(0.85, 0.3, 0.3, 1))

# ─── State ──────────────────────────────────────────────────────────────────
func _set_state(s: State, msg: String = ""):
	match s:
		State.IDLE:
			submit_btn.disabled = false
			submit_btn.text = "Slack 요약 불러오기"
			status_banner.visible = false
		State.LOADING:
			submit_btn.disabled = true
			submit_btn.text = "불러오는 중…"
			status_banner.visible = false
		State.SUCCESS:
			submit_btn.disabled = false
			submit_btn.text = "다시 불러오기"
			status_banner.visible = false
		State.ERROR:
			submit_btn.disabled = false
			submit_btn.text = "다시 시도"
			status_banner.visible = true
			status_banner.text = "오류: " + msg

# ─── Submit ─────────────────────────────────────────────────────────────────
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

# ─── Response ───────────────────────────────────────────────────────────────
func _on_request_completed(result: int, code: int, _h, body: PackedByteArray):
	if result != HTTPRequest.RESULT_SUCCESS:
		_set_state(State.ERROR, "네트워크 오류")
		return
	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		_set_state(State.ERROR, "응답 파싱 실패")
		return
	var data = json.get_data()
	var summary = data.get("summary", "")
	var messages = data.get("messages", [])
	var channel = data.get("channel_id", "unknown")

	_set_state(State.SUCCESS)
	_populate_summary(summary)
	_populate_messages(messages)
	summary_loaded.emit(channel, messages.size())

func _populate_summary(text: String):
	for c in summary_list.get_children():
		c.queue_free()
	var lbl = RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.text = text
	lbl.fit_content = true
	lbl.selection_enabled = true
	lbl.add_theme_color_override("default_color", Color(0.15, 0.22, 0.4, 1))
	lbl.add_theme_font_size_override("normal_font_size", 15)
	summary_list.add_child(lbl)

func _populate_messages(messages: Array):
	for c in msg_list.get_children(): c.queue_free()
	for msg in messages:
		var container = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.94, 0.96, 1.0, 1)
		style.set_corner_radius_all(10)
		style.content_margin_left = 12
		style.content_margin_top = 8
		style.content_margin_right = 12
		style.content_margin_bottom = 8
		container.add_theme_stylebox_override("panel", style)
		
		var lbl = Label.new()
		var user = msg.get("user", "?")
		var content = msg.get("text", "")
		lbl.text = "[ %s ]\n%s" % [user, content]
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.3, 0.4, 0.6, 1))
		
		container.add_child(lbl)
		msg_list.add_child(container)

func _clear_results():
	for c in summary_list.get_children(): c.queue_free()
	for c in msg_list.get_children(): c.queue_free()

# ─── Health check ────────────────────────────────────────────────────────────
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

# ─── Panel animation ─────────────────────────────────────────────────────────
func _get_panel_size() -> Vector2:
	var parent = get_parent()
	var w = parent.size.x
	var h = parent.size.y
	if w <= 0.0 or h <= 0.0:
		var vp = get_viewport_rect().size
		w = vp.x
		h = vp.y - 300.0
	return Vector2(w, h)

func show_card():
	_set_state(State.IDLE)
	_clear_results()
	visible = true
	modulate.a = 0.0
	await get_tree().process_frame
	await get_tree().process_frame

	var panel_size = _get_panel_size()
	custom_minimum_size = panel_size
	size = panel_size
	position = Vector2(0.0, panel_size.y)

	var tw = create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", 0.0, 0.55)
	tw.tween_property(self, "modulate:a", 1.0, 0.40)
	await get_tree().create_timer(0.35).timeout
	_run_health_check()

func hide_card():
	if not visible:
		card_closed.emit()
		return
	var panel_h = _get_panel_size().y
	var tw = create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "position:y", panel_h, 0.42)
	tw.tween_property(self, "modulate:a", 0.0, 0.28)
	tw.chain().tween_callback(func():
		visible = false
		card_closed.emit()
	)
