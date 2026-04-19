extends PanelContainer

signal card_closed

enum State { IDLE, LOADING, SUCCESS, ERROR }

const BASE_URL       = "http://localhost:8000/api/v1"
const CALENDARS_URL  = BASE_URL + "/calendars"
const PROPOSALS_URL  = BASE_URL + "/calendar-operations/proposals"
const SUMMARY_SUFFIX = "/summary"
const MIN_CONTENT_HEIGHT := 560.0

@onready var http_req     = $HTTPRequest
@onready var date_edit    = $Margin/VBox/QueryRow/DateEdit
@onready var cal_id_edit  = $Margin/VBox/QueryRow/CalIdEdit
@onready var fetch_btn    = $Margin/VBox/QueryRow/FetchBtn
@onready var summary_lbl  = $Margin/VBox/MainContent/SummarySection/SummaryBox/SummaryScroll/SummaryLabel
@onready var events_list  = $Margin/VBox/MainContent/EventsSection/EventsBox/EventsScroll/EventsList
@onready var conflict_box = $Margin/VBox/ConflictBanner
@onready var status_banner= $Margin/VBox/StatusBanner

var _pending_action = ""   # "summary" or "events"

func _ready():
	_install_outer_scroll(MIN_CONTENT_HEIGHT)
	modulate.a = 0.0
	visible = false
	http_req.request_completed.connect(_on_request_completed)
	fetch_btn.pressed.connect(_on_fetch_pressed)
	resized.connect(_fit_content_bounds)
	# Set today's date
	date_edit.text = Time.get_date_string_from_system()
	call_deferred("_fit_content_bounds")


func _install_outer_scroll(minimum_content_height: float) -> void:
	var margin := $Margin
	var root: Control = $Margin/VBox
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
		target_width = size.x - 64.0
	if target_width <= 0.0:
		return

	root.custom_minimum_size = Vector2(target_width, max(root.custom_minimum_size.y, MIN_CONTENT_HEIGHT))
	root.size = Vector2(target_width, max(outer_scroll.size.y, MIN_CONTENT_HEIGHT))

# ─── State helpers ───────────────────────────────────────────────────────────
func _set_state(s: State, msg: String = ""):
	match s:
		State.IDLE:
			fetch_btn.disabled = false
			fetch_btn.text = "일정 조회"
			status_banner.visible = false
		State.LOADING:
			fetch_btn.disabled = true
			fetch_btn.text = "불러오는 중…"
			status_banner.visible = false
		State.SUCCESS:
			fetch_btn.disabled = false
			fetch_btn.text = "새로고침"
			status_banner.visible = false
		State.ERROR:
			fetch_btn.disabled = false
			fetch_btn.text = "재시도"
			status_banner.visible = true
			status_banner.text = "오류: " + msg

# ─── Fetch ───────────────────────────────────────────────────────────────────
func _on_fetch_pressed():
	var cal_id = cal_id_edit.text.strip_edges()
	if cal_id.is_empty(): cal_id = "primary"
	var date = date_edit.text.strip_edges()

	_set_state(State.LOADING)
	_pending_action = "summary"

	var url = "%s/%s%s?date=%s" % [CALENDARS_URL, cal_id, SUMMARY_SUFFIX, date]
	http_req.request(url)

# ─── Response ────────────────────────────────────────────────────────────────
func _on_request_completed(result: int, code: int, _h, body: PackedByteArray):
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_set_state(State.ERROR, "서버 응답 오류 (code: %d)" % code)
		return
	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		_set_state(State.ERROR, "파싱 오류")
		return
	var data = json.get_data()
	_set_state(State.SUCCESS)

	if _pending_action == "summary":
		_render_summary(data)

func _render_summary(data: Dictionary):
	# Summary text
	var summary = data.get("summary", "요약 정보 없음")
	summary_lbl.text = summary

	# Events list
	for c in events_list.get_children(): c.queue_free()
	var events = data.get("events", [])
	for ev in events:
		var lbl = Label.new()
		var title = ev.get("title", "제목 없음")
		var start = ev.get("start", "")
		lbl.text = "• %s  %s" % [start.substr(11, 5), title]
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.2, 0.25, 0.4, 1))
		events_list.add_child(lbl)

	# Conflicts
	var conflicts = data.get("conflicts", [])
	conflict_box.visible = conflicts.size() > 0
	if conflict_box.visible:
		var clbl = conflict_box.get_node_or_null("ConflictLabel")
		if clbl:
			clbl.text = "⚠ 일정 충돌 %d건" % conflicts.size()

# ─── Panel animation ──────────────────────────────────────────────────────────
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
	visible = true
	modulate.a = 0.0
	await get_tree().process_frame
	await get_tree().process_frame

	var outer_scroll := get_node_or_null("Margin/OuterScroll")
	if outer_scroll and outer_scroll is ScrollContainer:
		outer_scroll.scroll_vertical = 0

	var panel_size = _get_panel_size()
	custom_minimum_size = panel_size
	size = panel_size
	position = Vector2(0.0, panel_size.y)
	_fit_content_bounds()

	var tw = create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", 0.0, 0.55)
	tw.tween_property(self, "modulate:a", 1.0, 0.40)

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
