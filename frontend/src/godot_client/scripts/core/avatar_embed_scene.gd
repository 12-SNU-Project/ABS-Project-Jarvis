extends Control

const MOOD_METHODS := [
	"set_mood_idle",
	"set_mood_thinking",
	"set_mood_speaking",
	"set_mood_happy",
	"set_mood_surprised",
	"set_mood_sad",
	"set_mood_error",
	"set_mood_angry",
	"set_mood_embarrassed",
]

const NAV_STATUS := {
	"NavHome": "Overview mode active",
	"NavAlerts": "Alert stream focused",
	"NavAgent": "Agent command context",
	"NavSystem": "Admin diagnostics active",
}

const NAV_MOOD := {
	"NavHome": "set_mood_idle",
	"NavAlerts": "set_mood_surprised",
	"NavAgent": "set_mood_thinking",
	"NavSystem": "set_mood_embarrassed",
}

const NAV_SIDEBAR_TITLE := {
	"NavHome": "Overview Feed",
	"NavAlerts": "Notifications",
	"NavAgent": "Agent Activity",
	"NavSystem": "Admin Status",
}

const NAV_MINI_INFO_TITLE := {
	"NavHome": "Overview Info",
	"NavAlerts": "Alert Metrics",
	"NavAgent": "Agent Metrics",
	"NavSystem": "Admin Metrics",
}

const ALERT_SOURCE_CALENDAR := "Calendar"
const ALERT_SOURCE_SLACK := "Slack"
const ALERT_SOURCE_SYSTEM := "System"
const ALERT_SOURCE_VOICE := "Voice"
const MIC_CAPTURE_BUS := "MicCapture"
const PRIORITY_IDLE_BRIEF := 30
const PRIORITY_MONITOR_ALERT := 50
const PRIORITY_SYSTEM_ERROR := 75
const PRIORITY_VOICE := 100
const ALERT_CARD_MAX_CHARS := 88
const BUBBLE_TEXT_MAX_CHARS := 150
const TOOL_CALL_MAX_QUEUE := 8
const TOOL_RESULT_DEDUP_WINDOW_MS := 12000
const TTS_ESTIMATED_CHARS_PER_SECOND := 7.5
const TTS_ESTIMATED_MIN_SEC := 2.8
const TTS_ESTIMATED_MAX_SEC := 24.0

const TOOL_CALL_ALLOWLIST := {
	"health_check": {"method": "GET", "exact": "/api/v1/health"},
	"list_calendars": {"method": "GET", "exact": "/api/v1/calendars"},
	"get_calendar": {"method": "GET", "prefix": "/api/v1/calendars/"},
	"list_calendar_events": {"method": "GET", "suffix": "/events", "prefix": "/api/v1/calendars/"},
	"list_calendar_conflicts": {"method": "GET", "suffix": "/conflicts", "prefix": "/api/v1/calendars/"},
	"get_calendar_summary": {"method": "GET", "suffix": "/summary", "prefix": "/api/v1/calendars/"},
	"list_calendar_operation_proposals": {"method": "GET", "exact": "/api/v1/calendar-operations"},
	"get_calendar_operation_proposal": {"method": "GET", "prefix": "/api/v1/calendar-operations/"},
	"list_calendar_operation_audit_records": {"method": "GET", "exact": "/api/v1/calendar-operation-audit"},
	"create_briefing": {"method": "POST", "exact": "/api/v1/briefings"},
	"create_calendar_operation_proposal": {"method": "POST", "exact": "/api/v1/calendar-operations/proposals"},
	"execute_calendar_operation_proposal": {"method": "POST", "suffix": "/execute", "prefix": "/api/v1/calendar-operations/"},
	"reject_calendar_operation_proposal": {"method": "POST", "suffix": "/reject", "prefix": "/api/v1/calendar-operations/"},
	"slack_summary": {"method": "POST", "exact": "/api/v1/slack/summary"},
	"slack_activity": {"method": "GET", "exact": "/api/v1/slack/activity"},
	"admin_summary": {"method": "GET", "exact": "/api/v1/admin/summary"},
	"health_sleep_summary": {"method": "GET", "exact": "/api/v1/health/sleep"},
	"presentation_demo": {"method": "GET", "exact": "/api/v1/presentation/demo"},
}

@export var backend_base_url := "http://127.0.0.1:8000"
@export var calendar_id := "primary"
@export var slack_channel_id := ""
@export_range(10.0, 600.0, 1.0) var monitor_interval_sec := 45.0
@export_range(1, 168, 1) var slack_lookback_hours := 24
@export var tts_enabled := true
@export var tts_voice_id := ""
@export_range(1.0, 12.0, 0.1) var bubble_visible_sec := 4.0
@export var voice_enabled := true
@export var stt_language := "ko"
@export var stt_prompt := "회의/슬랙/캘린더 관련 용어를 정확히 인식해줘."
@export_range(1.0, 20.0, 0.5) var mic_record_max_sec := 7.0
@export_range(3.0, 60.0, 1.0) var request_timeout_sec := 12.0
@export_range(0, 3, 1) var monitor_retry_limit := 1
@export var idle_brief_enabled := true
@export_range(30.0, 3600.0, 1.0) var idle_brief_interval_sec := 180.0
@export_range(60.0, 7200.0, 1.0) var idle_brief_repeat_sec := 900.0
@export var idle_brief_location := "Seoul"
@export var idle_brief_prompt := "Idle 상태 짧은 브리핑을 알려줘."
@export var mock_showcase_enabled := true
@export var mock_showcase_loop := false
@export_range(1.0, 120.0, 0.5) var mock_showcase_step_sec := 9.0
@export_range(0.0, 30.0, 0.5) var mock_showcase_start_delay_sec := 2.0
@export_range(2.0, 24.0, 0.5) var mock_showcase_bubble_min_sec := 5.5
@export var mock_showcase_date := "2026-04-21"

@onready var avatar: Node2D = $MainLayout/RootVBox/TopRow/WorkspaceColumn/ArenaPanel/ArenaStage/Avatar
@onready var arena_stage: Control = $MainLayout/RootVBox/TopRow/WorkspaceColumn/ArenaPanel/ArenaStage
@onready var speech_bubble: PanelContainer = $MainLayout/RootVBox/TopRow/WorkspaceColumn/ArenaPanel/ArenaStage/SpeechBubble
@onready var speech_label: Label = $MainLayout/RootVBox/TopRow/WorkspaceColumn/ArenaPanel/ArenaStage/SpeechBubble/BubbleMargin/SpeechLabel
@onready var nav_indicator: Panel = $MainLayout/RootVBox/TopRow/LeftNav/NavMargin/NavVBox/NavStack/NavIndicator
@onready var nav_home: Button = $MainLayout/RootVBox/TopRow/LeftNav/NavMargin/NavVBox/NavStack/NavButtons/NavHome
@onready var nav_alerts: Button = $MainLayout/RootVBox/TopRow/LeftNav/NavMargin/NavVBox/NavStack/NavButtons/NavAlerts
@onready var nav_agent: Button = $MainLayout/RootVBox/TopRow/LeftNav/NavMargin/NavVBox/NavStack/NavButtons/NavAgent
@onready var nav_system: Button = $MainLayout/RootVBox/TopRow/LeftNav/NavMargin/NavVBox/NavStack/NavButtons/NavSystem
@onready var right_sidebar: PanelContainer = $MainLayout/RootVBox/TopRow/RightSidebar
@onready var sidebar_content: VBoxContainer = $MainLayout/RootVBox/TopRow/RightSidebar/SidebarMargin/SidebarStack/SidebarContent
@onready var sidebar_compact: VBoxContainer = $MainLayout/RootVBox/TopRow/RightSidebar/SidebarMargin/SidebarStack/SidebarCompact
@onready var sidebar_toggle_button: Button = $MainLayout/RootVBox/TopRow/RightSidebar/SidebarMargin/SidebarStack/SidebarContent/SidebarHeader/SidebarToggleButton
@onready var sidebar_expand_button: Button = $MainLayout/RootVBox/TopRow/RightSidebar/SidebarMargin/SidebarStack/SidebarCompact/SidebarExpandButton
@onready var sidebar_title: Label = $MainLayout/RootVBox/TopRow/RightSidebar/SidebarMargin/SidebarStack/SidebarContent/SidebarHeader/SidebarTitle
@onready var alert_card_1_label: Label = $MainLayout/RootVBox/TopRow/RightSidebar/SidebarMargin/SidebarStack/SidebarContent/AlertCard1/AlertCard1Margin/AlertCard1Label
@onready var alert_card_2_label: Label = $MainLayout/RootVBox/TopRow/RightSidebar/SidebarMargin/SidebarStack/SidebarContent/AlertCard2/AlertCard2Margin/AlertCard2Label
@onready var alert_card_3_label: Label = $MainLayout/RootVBox/TopRow/RightSidebar/SidebarMargin/SidebarStack/SidebarContent/AlertCard3/AlertCard3Margin/AlertCard3Label
@onready var mini_info_title: Label = $MainLayout/RootVBox/TopRow/RightSidebar/SidebarMargin/SidebarStack/SidebarContent/MiniInfoCard/MiniInfoMargin/MiniInfoVBox/MiniInfoTitle
@onready var mini_info_line_1: Label = $MainLayout/RootVBox/TopRow/RightSidebar/SidebarMargin/SidebarStack/SidebarContent/MiniInfoCard/MiniInfoMargin/MiniInfoVBox/MiniInfoLine1
@onready var mini_info_line_2: Label = $MainLayout/RootVBox/TopRow/RightSidebar/SidebarMargin/SidebarStack/SidebarContent/MiniInfoCard/MiniInfoMargin/MiniInfoVBox/MiniInfoLine2
@onready var mini_info_line_3: Label = $MainLayout/RootVBox/TopRow/RightSidebar/SidebarMargin/SidebarStack/SidebarContent/MiniInfoCard/MiniInfoMargin/MiniInfoVBox/MiniInfoLine3
@onready var tray_status_label: Label = $MainLayout/RootVBox/TrayBar/TrayMargin/TrayRow/TrayStatusLabel
@onready var tray_sidebar_button: Button = $MainLayout/RootVBox/TrayBar/TrayMargin/TrayRow/TraySidebarToggleButton
@onready var tray_roam_button: Button = $MainLayout/RootVBox/TrayBar/TrayMargin/TrayRow/TrayRoamToggleButton
@onready var tray_mood_button: Button = $MainLayout/RootVBox/TrayBar/TrayMargin/TrayRow/TrayMoodButton
@onready var tray_monitor_button: Button = $MainLayout/RootVBox/TrayBar/TrayMargin/TrayRow/TrayMonitorToggleButton
@onready var tray_mic_button: Button = $MainLayout/RootVBox/TrayBar/TrayMargin/TrayRow/TrayMicToggleButton
@onready var clock_label: Label = $MainLayout/RootVBox/TrayBar/TrayMargin/TrayRow/ClockLabel
@onready var mood_timer: Timer = $MoodTimer
@onready var clock_timer: Timer = $ClockTimer
@onready var poll_timer: Timer = $PollTimer
@onready var idle_brief_timer: Timer = $IdleBriefTimer
@onready var bubble_timer: Timer = $BubbleTimer
@onready var watchdog_tick_timer: Timer = $WatchdogTickTimer
@onready var mic_record_timer: Timer = $MicRecordTimer
@onready var calendar_request: HTTPRequest = $CalendarRequest
@onready var slack_request: HTTPRequest = $SlackRequest
@onready var idle_brief_request: HTTPRequest = $IdleBriefRequest
@onready var stt_request: HTTPRequest = $SttRequest
@onready var agent_request: HTTPRequest = $AgentInterpretRequest
@onready var tool_call_request: HTTPRequest = $ToolCallRequest

@onready var nav_buttons: Array[Button] = [nav_home, nav_alerts, nav_agent, nav_system]

var _rng := RandomNumberGenerator.new()
var _roam_tween: Tween
var _indicator_tween: Tween
var _sidebar_tween: Tween
var _mood_index := 0
var _active_nav_name := "NavHome"
var _roam_enabled := true
var _monitor_enabled := true
var _sidebar_expanded := true
var _arena_rect := Rect2()
var _calendar_signature := ""
var _slack_signature := ""
var _calendar_request_in_flight := false
var _slack_request_in_flight := false
var _idle_brief_request_in_flight := false
var _calendar_error_notified := false
var _slack_error_notified := false
var _idle_brief_error_notified := false
var _alert_feed: Array[String] = []
var _agent_activity_feed: Array[String] = []
var _unread_alert_count := 0
var _last_poll_time := "--:--"
var _status_indicator_id := -1
var _status_indicator_supported := false
var _status_icon_normal: Texture2D
var _status_icon_alert: Texture2D
var _bubble_tween: Tween
var _tts_available := false
var _tts_guard_until_ms := 0
var _mic_bus_index := -1
var _mic_record_effect: AudioEffectRecord
var _mic_capture_player: AudioStreamPlayer
var _mic_recording := false
var _stt_request_in_flight := false
var _agent_request_in_flight := false
var _calendar_request_started_at_ms := 0
var _slack_request_started_at_ms := 0
var _idle_brief_request_started_at_ms := 0
var _stt_request_started_at_ms := 0
var _agent_request_started_at_ms := 0
var _calendar_timeout_retry_count := 0
var _slack_timeout_retry_count := 0
var _idle_brief_timeout_retry_count := 0
var _idle_brief_signature := ""
var _idle_brief_initialized := false
var _last_idle_brief_announcement_unix := 0
var _last_transcript := ""
var _agent_last_status := "idle"
var _agent_last_command := ""
var _agent_last_explanation := ""
var _agent_last_updated := "--:--"
var _announcement_queue: Array[Dictionary] = []
var _current_announcement_priority := -1
var _tool_call_queue: Array[Dictionary] = []
var _tool_call_request_in_flight := false
var _tool_call_request_started_at_ms := 0
var _active_tool_call: Dictionary = {}
var _mock_showcase_timer: Timer
var _mock_showcase_steps: Array[Dictionary] = []
var _mock_showcase_step_index := 0
var _mock_showcase_running := false
var _showcase_weather_summary := ""
var _showcase_calendar_summary := ""
var _showcase_slack_summary := ""
var _showcase_briefing_summary := ""
var _showcase_presentation_schedule := ""
var _last_tool_result_line := ""
var _last_tool_result_at_ms := 0


func _ready() -> void:
	_rng.randomize()
	resized.connect(_on_resized)
	mood_timer.timeout.connect(_on_mood_timer_timeout)
	clock_timer.timeout.connect(_update_clock)
	poll_timer.timeout.connect(_on_poll_timer_timeout)
	idle_brief_timer.timeout.connect(_on_idle_brief_timer_timeout)
	bubble_timer.timeout.connect(_on_bubble_timer_timeout)
	watchdog_tick_timer.timeout.connect(_on_watchdog_tick_timeout)
	mic_record_timer.timeout.connect(_on_mic_record_timeout)
	calendar_request.request_completed.connect(_on_calendar_request_completed)
	slack_request.request_completed.connect(_on_slack_request_completed)
	idle_brief_request.request_completed.connect(_on_idle_brief_request_completed)
	stt_request.request_completed.connect(_on_stt_request_completed)
	agent_request.request_completed.connect(_on_agent_request_completed)
	tool_call_request.request_completed.connect(_on_tool_call_request_completed)

	tray_sidebar_button.pressed.connect(_toggle_sidebar)
	tray_roam_button.pressed.connect(_toggle_roam)
	tray_mood_button.pressed.connect(_step_mood)
	tray_monitor_button.pressed.connect(_toggle_monitoring)
	tray_mic_button.pressed.connect(_toggle_voice_recording)
	sidebar_toggle_button.pressed.connect(_toggle_sidebar)
	sidebar_expand_button.pressed.connect(_expand_sidebar_from_compact)

	for nav_button in nav_buttons:
		nav_button.pressed.connect(_on_nav_pressed.bind(nav_button))

	if slack_channel_id.strip_edges().is_empty():
		var env_channel := OS.get_environment("SLACK_CHANNEL_ID")
		if not env_channel.strip_edges().is_empty():
			slack_channel_id = env_channel.strip_edges()

	_initialize_status_indicator()
	_setup_background_close_behavior()
	_initialize_tts()
	_initialize_voice_capture()
	_setup_mock_showcase_timer()
	_update_clock()
	_refresh_alert_cards()
	_update_monitor_info_labels()
	call_deferred("_bootstrap_layout")


func _process(_delta: float) -> void:
	if speech_bubble.visible:
		_update_speech_bubble_position()


func _bootstrap_layout() -> void:
	_update_arena_rect()
	_set_sidebar_expanded(true, false)
	_select_nav(nav_home, false)
	avatar.position = _arena_rect.get_center()
	avatar.scale = Vector2.ONE * 0.8
	_queue_next_roam()
	poll_timer.wait_time = monitor_interval_sec
	idle_brief_timer.wait_time = idle_brief_interval_sec
	watchdog_tick_timer.wait_time = 1.0
	watchdog_tick_timer.start()
	if idle_brief_enabled:
		idle_brief_timer.start()
		_request_idle_brief()
	_poll_backend_now()
	mood_timer.start()
	_start_mock_showcase_if_needed()


func _setup_mock_showcase_timer() -> void:
	if _mock_showcase_timer:
		return
	_mock_showcase_timer = Timer.new()
	_mock_showcase_timer.one_shot = false
	_mock_showcase_timer.autostart = false
	add_child(_mock_showcase_timer)
	_mock_showcase_timer.timeout.connect(_on_mock_showcase_timer_timeout)


func _start_mock_showcase_if_needed() -> void:
	if not mock_showcase_enabled:
		return
	if _mock_showcase_running:
		return
	if not _monitor_enabled:
		return

	_mock_showcase_steps = _build_mock_showcase_steps()
	if _mock_showcase_steps.is_empty():
		return

	_mock_showcase_running = true
	_mock_showcase_step_index = 0
	_showcase_weather_summary = ""
	_showcase_calendar_summary = ""
	_showcase_slack_summary = ""
	_showcase_briefing_summary = ""
	_showcase_presentation_schedule = ""
	_mock_showcase_timer.wait_time = maxf(1.0, mock_showcase_step_sec)
	_mock_showcase_timer.start()

	if mock_showcase_start_delay_sec <= 0.0:
		_run_next_mock_showcase_step()
		return

	var kickoff := get_tree().create_timer(mock_showcase_start_delay_sec)
	kickoff.timeout.connect(func() -> void:
		if _mock_showcase_running:
			_run_next_mock_showcase_step()
	)


func _on_mock_showcase_timer_timeout() -> void:
	if not _mock_showcase_running:
		return
	if _is_tts_speaking():
		return
	if _mic_recording or _stt_request_in_flight or _agent_request_in_flight:
		return
	if _tool_call_request_in_flight:
		return
	if not _tool_call_queue.is_empty():
		return
	if speech_bubble.visible:
		return
	if not _announcement_queue.is_empty():
		return
	_run_next_mock_showcase_step()


func _run_next_mock_showcase_step() -> void:
	if _mock_showcase_steps.is_empty():
		return

	if _mock_showcase_step_index >= _mock_showcase_steps.size():
		if mock_showcase_loop:
			_mock_showcase_step_index = 0
		else:
			_mock_showcase_running = false
			if _mock_showcase_timer:
				_mock_showcase_timer.stop()
			tray_status_label.text = "Mock showcase complete"
			return

	var step: Dictionary = _mock_showcase_steps[_mock_showcase_step_index]
	_mock_showcase_step_index += 1
	_apply_mock_showcase_step_wait(step)

	var nav_name := str(step.get("nav", "")).strip_edges()
	if not nav_name.is_empty():
		_select_nav_by_name(nav_name)

	var run_orchestration_variant: Variant = step.get("orchestrate", false)
	if run_orchestration_variant is bool and run_orchestration_variant:
		_announce_mock_orchestration_result()
		tray_status_label.text = "Mock orchestration delivered"
		return

	var announce_line := str(step.get("announce", "")).strip_edges()
	if not announce_line.is_empty():
		var compact_line := _truncate_line(_compact_briefing_text(announce_line), BUBBLE_TEXT_MAX_CHARS)
		_dispatch_announcement(
			compact_line,
			"set_mood_thinking",
			PRIORITY_MONITOR_ALERT,
			compact_line,
		)

	var accepted_calls := _enqueue_tool_calls(step.get("tool_calls", []))
	if accepted_calls > 0:
		tray_status_label.text = "Mock showcase running (%d queued)" % accepted_calls
	else:
		tray_status_label.text = "Mock showcase step has no runnable calls"


func _build_mock_showcase_steps() -> Array[Dictionary]:
	var date_label := _resolve_showcase_date_label()
	var channel := slack_channel_id.strip_edges()
	if channel.is_empty():
		channel = "C-MOCK-DEMO"

	var steps: Array[Dictionary] = []
	steps.append({
		"nav": "NavHome",
		"announce": "4월 21일 오전 9시 프로젝트 발표 일정 중심으로 캘린더를 확인합니다.",
		"wait_sec": 12.0,
		"tool_calls": [
			{
				"name": "list_calendar_events",
				"method": "GET",
				"path": "/api/v1/calendars/%s/events" % calendar_id,
				"query": {"date": date_label},
				"body": null,
			},
			{
				"name": "get_calendar_summary",
				"method": "GET",
				"path": "/api/v1/calendars/%s/summary" % calendar_id,
				"query": {"date": date_label},
				"body": null,
			},
		],
	})

	steps.append({
		"nav": "NavAlerts",
		"announce": "슬랙 활동과 요약 데이터를 확인합니다.",
		"tool_calls": [
			{
				"name": "slack_activity",
				"method": "GET",
				"path": "/api/v1/slack/activity",
				"query": {
					"channel_id": channel,
					"lookback_hours": slack_lookback_hours,
					"date": date_label,
				},
				"body": null,
			},
			{
				"name": "slack_summary",
				"method": "POST",
				"path": "/api/v1/slack/summary",
				"query": {},
				"body": {
					"channel_id": channel,
					"user_input": "최근 대화 핵심만 5줄로 요약해줘",
					"date": date_label,
					"lookback_hours": slack_lookback_hours,
				},
			},
		],
	})

	steps.append({
		"nav": "NavHome",
		"announce": "4월 21일 아침 날씨와 09:00 발표 일정을 기준으로 브리핑을 생성합니다.",
		"wait_sec": 18.0,
		"tool_calls": [
			{
				"name": "create_briefing",
				"method": "POST",
				"path": "/api/v1/briefings",
				"query": {},
				"body": {
					"user_input": "오늘 브리핑을 생성해줘",
					"location": idle_brief_location,
					"date": date_label,
					"user_name": "Team Jarvis",
				},
			},
		],
	})

	steps.append({
		"nav": "NavHome",
		"orchestrate": true,
		"wait_sec": 16.0,
	})

	steps.append({
		"nav": "NavSystem",
		"announce": "어드민 지표와 프레젠테이션 데모를 조회합니다.",
		"tool_calls": [
			{
				"name": "admin_summary",
				"method": "GET",
				"path": "/api/v1/admin/summary",
				"query": {},
				"body": null,
			},
			{
				"name": "presentation_demo",
				"method": "GET",
				"path": "/api/v1/presentation/demo",
				"query": {},
				"body": null,
			},
			{
				"name": "health_sleep_summary",
				"method": "GET",
				"path": "/api/v1/health/sleep",
				"query": {},
				"body": null,
			},
		],
	})

	steps.append({
		"nav": "NavAgent",
		"announce": "캘린더 작업 제안 및 감사 로그를 확인합니다.",
		"tool_calls": [
			{
				"name": "list_calendar_operation_proposals",
				"method": "GET",
				"path": "/api/v1/calendar-operations",
				"query": {},
				"body": null,
			},
			{
				"name": "list_calendar_operation_audit_records",
				"method": "GET",
				"path": "/api/v1/calendar-operation-audit",
				"query": {},
				"body": null,
			},
		],
	})

	return steps


func _apply_mock_showcase_step_wait(step: Dictionary) -> void:
	if not _mock_showcase_timer:
		return
	var step_wait := mock_showcase_step_sec
	var wait_variant: Variant = step.get("wait_sec", step_wait)
	if wait_variant is float or wait_variant is int:
		step_wait = maxf(1.0, float(wait_variant))
	_mock_showcase_timer.wait_time = step_wait


func _resolve_showcase_date_label() -> String:
	var candidate := mock_showcase_date.strip_edges()
	var parts := candidate.split("-")
	if parts.size() == 3 and parts[0].length() == 4 and parts[1].length() == 2 and parts[2].length() == 2:
		var year := int(parts[0])
		var month := int(parts[1])
		var day := int(parts[2])
		if year >= 2000 and month >= 1 and month <= 12 and day >= 1 and day <= 31:
			return candidate
	return Time.get_date_string_from_system()


func _announce_mock_orchestration_result() -> void:
	var orchestration_line := _build_mock_orchestration_line()
	if orchestration_line.is_empty():
		return
	var bubble_line := _truncate_line(_normalize_whitespace(orchestration_line), BUBBLE_TEXT_MAX_CHARS)
	var emitted := _record_tool_result("Orchestration • %s" % _truncate_line(bubble_line, 72))
	if not emitted:
		return
	_dispatch_announcement(
		bubble_line,
		"set_mood_happy",
		PRIORITY_MONITOR_ALERT,
		bubble_line,
	)


func _build_mock_orchestration_line() -> String:
	var schedule := _showcase_presentation_schedule
	if _mock_showcase_running:
		schedule = "4월 21일 09:00 프로젝트 발표"
	elif schedule.is_empty():
		schedule = "4월 21일 09:00 프로젝트 발표"

	var weather_brief := _showcase_weather_summary
	if weather_brief.is_empty():
		weather_brief = "서울 기준 오전에 온화한 날씨"

	var slack_brief := _showcase_slack_summary
	if slack_brief.is_empty():
		slack_brief = "슬랙 핵심 액션은 발표 자료 최종 점검"

	var calendar_brief := _showcase_calendar_summary
	if calendar_brief.is_empty():
		calendar_brief = "캘린더에는 오전 9시 프로젝트 발표 1건이 배치됨"

	var briefing_hint := _showcase_briefing_summary
	if briefing_hint.is_empty():
		briefing_hint = "발표 시작 10분 전 입장을 최우선으로 설정"

	var template := (
		"시나리오: %s를 기준으로 진행합니다. "
		+ "날씨는 %s 이므로 08:30 장비 점검 후 08:50 발표장 입장을 권장합니다. "
		+ "일정 참고: %s. 슬랙 체크: %s. 최종 오케스트레이션: %s."
	)
	return template % [
		schedule,
		_truncate_line(weather_brief, 42),
		_truncate_line(calendar_brief, 42),
		_truncate_line(slack_brief, 42),
		_truncate_line(briefing_hint, 42),
	]


func _select_nav_by_name(nav_name: String) -> void:
	for nav_button in nav_buttons:
		if nav_button.name == nav_name:
			_select_nav(nav_button, true)
			return


func _on_resized() -> void:
	_update_arena_rect()
	if not _arena_rect.has_point(avatar.position):
		avatar.position = _arena_rect.get_center()
	if speech_bubble.visible:
		_update_speech_bubble_position()


func _update_arena_rect() -> void:
	var inset := 82.0
	var stage_size := arena_stage.size
	if stage_size.x <= inset * 2.0 or stage_size.y <= inset * 2.0:
		_arena_rect = Rect2(Vector2.ZERO, stage_size)
		return
	_arena_rect = Rect2(
		Vector2(inset, inset),
		stage_size - Vector2(inset * 2.0, inset * 2.0)
	)


func _on_nav_pressed(button: Button) -> void:
	_select_nav(button, true)


func _select_nav(button: Button, animate: bool) -> void:
	for nav_button in nav_buttons:
		nav_button.button_pressed = nav_button == button
	_move_indicator(button, animate)
	_apply_nav_context(button.name)


func _move_indicator(button: Button, animate: bool) -> void:
	var target_position := Vector2(button.position.x - 4.0, button.position.y)
	var target_size := Vector2(button.size.x + 8.0, button.size.y)

	if _indicator_tween:
		_indicator_tween.kill()

	if not animate:
		nav_indicator.position = target_position
		nav_indicator.size = target_size
		return

	_indicator_tween = create_tween().set_parallel(true)
	_indicator_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_indicator_tween.tween_property(nav_indicator, "position", target_position, 0.18)
	_indicator_tween.tween_property(nav_indicator, "size", target_size, 0.18)


func _apply_nav_context(nav_name: String) -> void:
	_active_nav_name = nav_name
	tray_status_label.text = String(NAV_STATUS.get(nav_name, "Workspace stable"))
	sidebar_title.text = String(NAV_SIDEBAR_TITLE.get(nav_name, "Notifications"))
	mini_info_title.text = String(NAV_MINI_INFO_TITLE.get(nav_name, "Quick Info"))
	var mood_method := String(NAV_MOOD.get(nav_name, "set_mood_idle"))
	_play_avatar_method(mood_method)
	if nav_name == "NavAlerts":
		_set_sidebar_expanded(true)
		_clear_unread_alerts()
	_refresh_alert_cards()
	_update_monitor_info_labels()


func _queue_next_roam() -> void:
	if not _roam_enabled:
		return
	if _arena_rect.size.x < 16.0 or _arena_rect.size.y < 16.0:
		return

	var target := Vector2(
		_rng.randf_range(_arena_rect.position.x, _arena_rect.end.x),
		_rng.randf_range(_arena_rect.position.y, _arena_rect.end.y)
	)
	var duration := _rng.randf_range(1.8, 3.2)
	var travel_scale := Vector2.ONE * _rng.randf_range(0.74, 0.86)

	if _roam_tween:
		_roam_tween.kill()

	_roam_tween = create_tween()
	_roam_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_roam_tween.tween_property(avatar, "position", target, duration)
	_roam_tween.parallel().tween_property(avatar, "scale", travel_scale, duration * 0.46)
	_roam_tween.chain().tween_property(avatar, "scale", Vector2.ONE * 0.8, duration * 0.32)
	_roam_tween.chain().tween_callback(_on_roam_arrived)


func _on_roam_arrived() -> void:
	_apply_random_mood()
	_queue_next_roam()


func _toggle_roam() -> void:
	_roam_enabled = not _roam_enabled
	if _roam_enabled:
		tray_roam_button.text = "Pause Roam"
		tray_status_label.text = "Roaming active"
		_queue_next_roam()
	else:
		tray_roam_button.text = "Resume Roam"
		tray_status_label.text = "Roaming paused"
		if _roam_tween:
			_roam_tween.kill()
		_play_avatar_method("set_mood_thinking")


func _toggle_sidebar() -> void:
	_set_sidebar_expanded(not _sidebar_expanded)


func _expand_sidebar_from_compact() -> void:
	_set_sidebar_expanded(true)


func _set_sidebar_expanded(expanded: bool, animate: bool = true) -> void:
	_sidebar_expanded = expanded
	var target_width := 308.0 if expanded else 82.0

	if _sidebar_tween:
		_sidebar_tween.kill()

	if animate:
		_sidebar_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_sidebar_tween.tween_property(right_sidebar, "custom_minimum_size:x", target_width, 0.22)
	else:
		right_sidebar.custom_minimum_size = Vector2(target_width, right_sidebar.custom_minimum_size.y)

	sidebar_content.visible = expanded
	sidebar_compact.visible = not expanded
	tray_sidebar_button.text = "Hide Alerts" if expanded else "Show Alerts"
	sidebar_toggle_button.text = "<<" if expanded else ">>"
	if expanded and nav_alerts.button_pressed:
		_clear_unread_alerts()


func _on_mood_timer_timeout() -> void:
	if MOOD_METHODS.is_empty():
		return
	if _is_tts_speaking():
		return
	_mood_index = (_mood_index + 1) % MOOD_METHODS.size()
	_play_avatar_method(MOOD_METHODS[_mood_index])


func _step_mood() -> void:
	_on_mood_timer_timeout()


func _apply_random_mood() -> void:
	if MOOD_METHODS.is_empty():
		return
	if _is_tts_speaking():
		return
	var random_index := _rng.randi_range(0, MOOD_METHODS.size() - 1)
	_play_avatar_method(MOOD_METHODS[random_index])


func _play_avatar_method(method_name: String) -> void:
	var avatar_method := StringName(method_name)
	if avatar.has_method(avatar_method):
		avatar.call(avatar_method)


func _update_clock() -> void:
	var time_text := Time.get_time_string_from_system()
	clock_label.text = time_text.substr(0, 5)


func _on_poll_timer_timeout() -> void:
	if _monitor_enabled:
		_poll_backend_now()


func _on_idle_brief_timer_timeout() -> void:
	if not idle_brief_enabled:
		return
	if not _monitor_enabled:
		return
	if _is_tts_speaking():
		return
	if _active_nav_name != "NavHome":
		return
	if _calendar_request_in_flight or _slack_request_in_flight or _idle_brief_request_in_flight:
		return
	if _mic_recording or _stt_request_in_flight or _agent_request_in_flight or _tool_call_request_in_flight:
		return
	_request_idle_brief()


func _on_watchdog_tick_timeout() -> void:
	var timeout_ms := int(request_timeout_sec * 1000.0)
	_check_request_timeout("calendar", _calendar_request_in_flight, _calendar_request_started_at_ms, timeout_ms)
	_check_request_timeout("slack", _slack_request_in_flight, _slack_request_started_at_ms, timeout_ms)
	_check_request_timeout("idle_brief", _idle_brief_request_in_flight, _idle_brief_request_started_at_ms, timeout_ms)
	_check_request_timeout("stt", _stt_request_in_flight, _stt_request_started_at_ms, timeout_ms)
	_check_request_timeout("agent", _agent_request_in_flight, _agent_request_started_at_ms, timeout_ms)
	_check_request_timeout("tool_call", _tool_call_request_in_flight, _tool_call_request_started_at_ms, timeout_ms)
	if not speech_bubble.visible:
		_flush_announcement_queue()


func _check_request_timeout(
	request_key: String,
	in_flight: bool,
	started_at_ms: int,
	timeout_ms: int,
) -> void:
	if not in_flight:
		return
	if started_at_ms <= 0:
		return
	var elapsed_ms := Time.get_ticks_msec() - started_at_ms
	if elapsed_ms < timeout_ms:
		return
	_handle_request_timeout(request_key)


func _handle_request_timeout(request_key: String) -> void:
	match request_key:
		"calendar":
			if calendar_request.has_method("cancel_request"):
				calendar_request.cancel_request()
			_calendar_request_in_flight = false
			_calendar_request_started_at_ms = 0
			if _calendar_timeout_retry_count < monitor_retry_limit:
				_calendar_timeout_retry_count += 1
				tray_status_label.text = "Calendar retrying..."
				_request_calendar_snapshot()
				return
			_calendar_timeout_retry_count = 0
			if not _calendar_error_notified:
				_calendar_error_notified = true
				_notify_monitor_error(ALERT_SOURCE_CALENDAR, "Calendar monitor timeout.")
		"slack":
			if slack_request.has_method("cancel_request"):
				slack_request.cancel_request()
			_slack_request_in_flight = false
			_slack_request_started_at_ms = 0
			if _slack_timeout_retry_count < monitor_retry_limit:
				_slack_timeout_retry_count += 1
				tray_status_label.text = "Slack retrying..."
				_request_slack_activity()
				return
			_slack_timeout_retry_count = 0
			if not _slack_error_notified:
				_slack_error_notified = true
				_notify_monitor_error(ALERT_SOURCE_SLACK, "Slack monitor timeout.")
		"idle_brief":
			if idle_brief_request.has_method("cancel_request"):
				idle_brief_request.cancel_request()
			_idle_brief_request_in_flight = false
			_idle_brief_request_started_at_ms = 0
			if _idle_brief_timeout_retry_count < monitor_retry_limit:
				_idle_brief_timeout_retry_count += 1
				tray_status_label.text = "Idle briefing retrying..."
				_request_idle_brief()
				return
			_idle_brief_timeout_retry_count = 0
			if not _idle_brief_error_notified:
				_idle_brief_error_notified = true
				_notify_monitor_error(ALERT_SOURCE_SYSTEM, "Idle briefing timeout.")
		"stt":
			if stt_request.has_method("cancel_request"):
				stt_request.cancel_request()
			_stt_request_in_flight = false
			_stt_request_started_at_ms = 0
			_notify_monitor_error(ALERT_SOURCE_VOICE, "STT request timeout.")
			tray_status_label.text = "Voice request timeout"
		"agent":
			if agent_request.has_method("cancel_request"):
				agent_request.cancel_request()
			_agent_request_in_flight = false
			_agent_request_started_at_ms = 0
			_notify_monitor_error(ALERT_SOURCE_VOICE, "Agent request timeout.")
			tray_status_label.text = "Voice command timeout"
		"tool_call":
			if tool_call_request.has_method("cancel_request"):
				tool_call_request.cancel_request()
			_tool_call_request_in_flight = false
			_tool_call_request_started_at_ms = 0
			var tool_name := str(_active_tool_call.get("name", "tool"))
			_notify_monitor_error(ALERT_SOURCE_VOICE, "Tool call timeout: %s" % tool_name)
			_update_agent_panel_state(
				_last_transcript,
				"error",
				_agent_last_command,
				"Tool call timed out: %s" % tool_name,
			)
			_active_tool_call = {}
			_start_next_tool_call_if_needed()
	_update_monitor_info_labels()


func _toggle_monitoring() -> void:
	_monitor_enabled = not _monitor_enabled
	if _monitor_enabled:
		tray_monitor_button.text = "Pause Monitor"
		tray_status_label.text = "Monitoring active"
		poll_timer.start()
		if idle_brief_enabled:
			idle_brief_timer.start()
			_request_idle_brief()
		_poll_backend_now()
		_start_mock_showcase_if_needed()
	else:
		tray_monitor_button.text = "Resume Monitor"
		tray_status_label.text = "Monitoring paused"
		poll_timer.stop()
		idle_brief_timer.stop()
		_mock_showcase_running = false
		if _mock_showcase_timer:
			_mock_showcase_timer.stop()
	_update_monitor_info_labels()


func _initialize_voice_capture() -> void:
	if not voice_enabled:
		tray_mic_button.disabled = true
		tray_mic_button.text = "Voice Off"
		return

	_mic_bus_index = AudioServer.get_bus_index(MIC_CAPTURE_BUS)
	if _mic_bus_index < 0:
		AudioServer.add_bus(AudioServer.get_bus_count())
		_mic_bus_index = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(_mic_bus_index, MIC_CAPTURE_BUS)
		AudioServer.set_bus_send(_mic_bus_index, "Master")

	if AudioServer.get_bus_effect_count(_mic_bus_index) == 0:
		_mic_record_effect = AudioEffectRecord.new()
		AudioServer.add_bus_effect(_mic_bus_index, _mic_record_effect, 0)
	else:
		var effect := AudioServer.get_bus_effect(_mic_bus_index, 0)
		if effect is AudioEffectRecord:
			_mic_record_effect = effect
		else:
			_mic_record_effect = AudioEffectRecord.new()
			AudioServer.add_bus_effect(_mic_bus_index, _mic_record_effect, 0)

	_mic_capture_player = AudioStreamPlayer.new()
	_mic_capture_player.bus = MIC_CAPTURE_BUS
	_mic_capture_player.stream = AudioStreamMicrophone.new()
	_mic_capture_player.volume_db = -80.0
	add_child(_mic_capture_player)

	if AudioServer.has_method("set_input_device_active"):
		AudioServer.call("set_input_device_active", true)


func _toggle_voice_recording() -> void:
	if not voice_enabled:
		return
	if _stt_request_in_flight or _agent_request_in_flight:
		tray_status_label.text = "Voice processing in progress"
		return
	if _mic_recording:
		_stop_voice_recording_and_transcribe()
		return
	_start_voice_recording()


func _start_voice_recording() -> void:
	if _mic_capture_player == null or _mic_record_effect == null:
		_notify_monitor_error(ALERT_SOURCE_VOICE, "Microphone capture is not initialized.")
		return

	_mic_recording = true
	tray_mic_button.text = "Stop Voice"
	tray_status_label.text = "Listening..."
	_update_agent_panel_state("", "listening", "", "Microphone capture started.")
	_play_avatar_method("set_mood_thinking")
	_show_speech_bubble("말씀해 주세요. 버튼을 다시 누르면 전송됩니다.")

	if _mic_capture_player.playing:
		_mic_capture_player.stop()
	_mic_capture_player.play()
	_mic_record_effect.set_recording_active(true)
	mic_record_timer.start(mic_record_max_sec)


func _stop_voice_recording_and_transcribe() -> void:
	if not _mic_recording:
		return

	_mic_recording = false
	mic_record_timer.stop()
	tray_mic_button.text = "Start Voice"
	tray_status_label.text = "Processing voice..."

	if _mic_record_effect:
		_mic_record_effect.set_recording_active(false)
	if _mic_capture_player and _mic_capture_player.playing:
		_mic_capture_player.stop()

	if _mic_record_effect == null:
		_notify_monitor_error(ALERT_SOURCE_VOICE, "Recorder effect is unavailable.")
		return

	var recording := _mic_record_effect.get_recording()
	if recording == null:
		_notify_monitor_error(ALERT_SOURCE_VOICE, "No microphone data captured.")
		return

	var wav_path := "user://jarvis-mic-input.wav"
	var save_result := recording.save_to_wav(wav_path)
	if save_result != OK:
		_notify_monitor_error(ALERT_SOURCE_VOICE, "Failed to serialize microphone data.")
		return

	var audio_bytes := FileAccess.get_file_as_bytes(wav_path)
	if audio_bytes.is_empty():
		_notify_monitor_error(ALERT_SOURCE_VOICE, "Captured microphone audio is empty.")
		return

	_request_stt_transcription(Marshalls.raw_to_base64(audio_bytes))


func _on_mic_record_timeout() -> void:
	if _mic_recording:
		_stop_voice_recording_and_transcribe()


func _request_stt_transcription(audio_base64: String) -> void:
	if _stt_request_in_flight:
		return

	var payload := {
		"audio_base64": audio_base64,
		"mime_type": "audio/wav",
		"language": stt_language,
	}
	var prompt_text := stt_prompt.strip_edges()
	if not prompt_text.is_empty():
		payload["prompt"] = prompt_text

	var headers := PackedStringArray(["Content-Type: application/json"])
	var url := "%s/api/v1/stt/transcribe" % _backend_root()
	var request_body := JSON.stringify(payload)
	var err := stt_request.request(url, headers, HTTPClient.METHOD_POST, request_body)
	if err != OK:
		_notify_monitor_error(ALERT_SOURCE_VOICE, "Failed to send STT request.")
		tray_status_label.text = "Voice request failed"
		return

	_stt_request_in_flight = true
	_stt_request_started_at_ms = Time.get_ticks_msec()
	_update_agent_panel_state(_last_transcript, "transcribing", "", "Sending audio to STT.")
	_update_monitor_info_labels()


func _on_stt_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
) -> void:
	_stt_request_in_flight = false
	_stt_request_started_at_ms = 0
	_update_monitor_info_labels()
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		var error_payload_variant: Variant = JSON.parse_string(body.get_string_from_utf8())
		var error_payload: Dictionary = error_payload_variant if error_payload_variant is Dictionary else {}
		var message := _standardized_error_message(
			"STT",
			response_code,
			error_payload,
			"STT request failed.",
		)
		_notify_monitor_error(ALERT_SOURCE_VOICE, message)
		_update_agent_panel_state(_last_transcript, "error", "", message)
		tray_status_label.text = "Voice request failed"
		return

	var payload_variant: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (payload_variant is Dictionary):
		_notify_monitor_error(ALERT_SOURCE_VOICE, "STT response parsing failed.")
		return

	var payload: Dictionary = payload_variant
	if payload.has("error"):
		var message := _standardized_error_message("STT", response_code, payload, "STT error")
		_notify_monitor_error(ALERT_SOURCE_VOICE, message)
		_update_agent_panel_state(_last_transcript, "error", "", message)
		tray_status_label.text = "Voice request failed"
		return

	var transcript := str(payload.get("transcript", "")).strip_edges()
	if transcript.is_empty():
		_notify_monitor_error(ALERT_SOURCE_VOICE, "STT returned empty transcript.")
		_update_agent_panel_state(_last_transcript, "error", "", "STT returned empty transcript.")
		tray_status_label.text = "Voice request failed"
		_update_monitor_info_labels()
		return

	_last_transcript = transcript
	_update_agent_panel_state(transcript, "transcribed", "", "Voice recognized.")
	tray_status_label.text = "Transcript ready"
	_dispatch_announcement("인식: %s" % transcript, "set_mood_speaking", PRIORITY_VOICE, transcript)
	_request_agent_interpretation(transcript)
	_update_monitor_info_labels()


func _request_agent_interpretation(transcript: String) -> void:
	if _agent_request_in_flight:
		return

	var payload := {
		"input": transcript,
		"date": Time.get_date_string_from_system(),
		"calendar_id": calendar_id,
	}
	var headers := PackedStringArray(["Content-Type: application/json"])
	var url := "%s/api/v1/agent/interpret" % _backend_root()
	var request_body := JSON.stringify(payload)
	var err := agent_request.request(url, headers, HTTPClient.METHOD_POST, request_body)
	if err != OK:
		_notify_monitor_error(ALERT_SOURCE_VOICE, "Agent interpretation request failed.")
		return

	_agent_request_in_flight = true
	_agent_request_started_at_ms = Time.get_ticks_msec()
	_update_agent_panel_state(_last_transcript, "interpreting", "", "Sending transcript to agent.")
	tray_status_label.text = "Interpreting voice command..."
	_update_monitor_info_labels()


func _on_agent_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
) -> void:
	_agent_request_in_flight = false
	_agent_request_started_at_ms = 0
	_update_monitor_info_labels()
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		var error_payload_variant: Variant = JSON.parse_string(body.get_string_from_utf8())
		var error_payload: Dictionary = error_payload_variant if error_payload_variant is Dictionary else {}
		var message := _standardized_error_message(
			"Agent",
			response_code,
			error_payload,
			"Agent interpretation failed.",
		)
		_notify_monitor_error(ALERT_SOURCE_VOICE, message)
		_update_agent_panel_state(_last_transcript, "error", "", message)
		tray_status_label.text = "Voice command failed"
		return

	var payload_variant: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (payload_variant is Dictionary):
		_notify_monitor_error(ALERT_SOURCE_VOICE, "Invalid agent response payload.")
		return

	var payload: Dictionary = payload_variant
	if payload.has("error"):
		var message := _standardized_error_message(
			"Agent",
			response_code,
			payload,
			"Agent interpretation error",
		)
		_notify_monitor_error(ALERT_SOURCE_VOICE, message)
		_update_agent_panel_state(_last_transcript, "error", "", message)
		tray_status_label.text = "Voice command failed"
		return

	var status_label := str(payload.get("status", ""))
	var explanation := str(payload.get("explanation", "")).strip_edges()
	var command := str(payload.get("command", "")).strip_edges()
	var tool_calls_variant: Variant = payload.get("tool_calls", [])
	var output_text := explanation if not explanation.is_empty() else "요청 해석을 완료했습니다."
	var agent_state := status_label if not status_label.is_empty() else "interpreted"
	if status_label == "interpreted" and not command.is_empty():
		output_text = "%s\n→ %s" % [output_text, command]
		agent_state = "interpreted"
	else:
		agent_state = "clarify"

	_update_agent_panel_state(
		_last_transcript,
		agent_state,
		command,
		explanation if not explanation.is_empty() else output_text,
	)
	_dispatch_announcement(
		output_text,
		"set_mood_happy" if agent_state == "interpreted" else "set_mood_thinking",
		PRIORITY_VOICE,
		explanation if not explanation.is_empty() else "요청 해석이 완료되었습니다.",
	)
	if agent_state == "interpreted":
		var accepted_tool_calls := _enqueue_tool_calls(tool_calls_variant)
		if accepted_tool_calls > 0:
			_update_agent_panel_state(
				_last_transcript,
				"executing",
				command,
				"Queued %d action(s) from tool_calls." % accepted_tool_calls,
			)
			tray_status_label.text = "Executing %d action(s)..." % accepted_tool_calls
		else:
			tray_status_label.text = "Voice command ready"
	else:
		tray_status_label.text = "Voice command ready"
	_update_monitor_info_labels()


func _poll_backend_now() -> void:
	_last_poll_time = Time.get_time_string_from_system().substr(0, 5)
	_request_calendar_snapshot()
	_request_slack_activity()
	_update_monitor_info_labels()


func _request_calendar_snapshot() -> void:
	if _calendar_request_in_flight:
		return
	var date_label := Time.get_date_string_from_system()
	var url := "%s/api/v1/calendars/%s/events?date=%s" % [
		_backend_root(),
		calendar_id,
		date_label,
	]
	var err := calendar_request.request(url)
	if err != OK:
		_notify_monitor_error(ALERT_SOURCE_SYSTEM, "Calendar monitor request failed.")
		return
	_calendar_request_in_flight = true
	_calendar_request_started_at_ms = Time.get_ticks_msec()
	_update_monitor_info_labels()


func _request_slack_activity() -> void:
	if _slack_request_in_flight:
		return
	if slack_channel_id.strip_edges().is_empty():
		return
	var date_label := Time.get_date_string_from_system()
	var url := "%s/api/v1/slack/activity?channel_id=%s&lookback_hours=%d&date=%s" % [
		_backend_root(),
		slack_channel_id,
		slack_lookback_hours,
		date_label,
	]
	var err := slack_request.request(url)
	if err != OK:
		_notify_monitor_error(ALERT_SOURCE_SYSTEM, "Slack monitor request failed.")
		return
	_slack_request_in_flight = true
	_slack_request_started_at_ms = Time.get_ticks_msec()
	_update_monitor_info_labels()


func _request_idle_brief() -> void:
	if _idle_brief_request_in_flight:
		return
	if _calendar_request_in_flight or _slack_request_in_flight:
		return

	var payload := {
		"user_input": idle_brief_prompt,
		"location": idle_brief_location,
		"date": Time.get_date_string_from_system(),
		"user_name": "Jarvis Desktop",
	}
	var headers := PackedStringArray(["Content-Type: application/json"])
	var url := "%s/api/v1/briefings" % _backend_root()
	var err := idle_brief_request.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if err != OK:
		if not _idle_brief_error_notified:
			_idle_brief_error_notified = true
			_notify_monitor_error(ALERT_SOURCE_SYSTEM, "Idle briefing request failed.")
		return

	_idle_brief_request_in_flight = true
	_idle_brief_request_started_at_ms = Time.get_ticks_msec()
	_update_monitor_info_labels()


func _on_idle_brief_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
) -> void:
	_idle_brief_request_in_flight = false
	_idle_brief_request_started_at_ms = 0
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		var error_payload_variant: Variant = JSON.parse_string(body.get_string_from_utf8())
		var error_payload: Dictionary = error_payload_variant if error_payload_variant is Dictionary else {}
		var message := _standardized_error_message(
			"Idle briefing",
			response_code,
			error_payload,
			"Idle briefing disconnected.",
		)
		if not _idle_brief_error_notified:
			_idle_brief_error_notified = true
			_notify_monitor_error(ALERT_SOURCE_SYSTEM, message)
		_update_monitor_info_labels()
		return

	_idle_brief_error_notified = false
	_idle_brief_timeout_retry_count = 0

	var payload_variant: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (payload_variant is Dictionary):
		_update_monitor_info_labels()
		return
	var payload: Dictionary = payload_variant
	if payload.has("error"):
		var message := _standardized_error_message(
			"Idle briefing",
			response_code,
			payload,
			"Idle briefing returned an error.",
		)
		if not _idle_brief_error_notified:
			_idle_brief_error_notified = true
			_notify_monitor_error(ALERT_SOURCE_SYSTEM, message)
		_update_monitor_info_labels()
		return

	var signature := _signature_from_briefing(payload)
	var summary := _extract_idle_brief_summary(payload)
	if summary.is_empty():
		_update_monitor_info_labels()
		return

	var now_unix := int(Time.get_unix_time_from_system())
	var is_first := not _idle_brief_initialized
	var changed := signature != _idle_brief_signature
	var cooldown_elapsed := (
		now_unix - _last_idle_brief_announcement_unix
	) >= int(idle_brief_repeat_sec)

	_idle_brief_signature = signature
	_idle_brief_initialized = true

	if is_first or changed or cooldown_elapsed:
		_last_idle_brief_announcement_unix = now_unix
		_announce_idle_brief(summary)

	_update_monitor_info_labels()


func _signature_from_briefing(payload: Dictionary) -> String:
	return "%s|%s|%s|%s|%s" % [
		str(payload.get("headline", "")),
		str(payload.get("final_summary", "")),
		_nested_summary(payload, "weather"),
		_nested_summary(payload, "calendar"),
		_nested_summary(payload, "slack"),
	]


func _nested_summary(payload: Dictionary, section: String) -> String:
	var section_variant: Variant = payload.get(section, {})
	if not (section_variant is Dictionary):
		return ""
	var section_dict: Dictionary = section_variant
	return str(section_dict.get("summary", "")).strip_edges()


func _extract_idle_brief_summary(payload: Dictionary) -> String:
	var final_summary := str(payload.get("final_summary", "")).strip_edges()
	if not final_summary.is_empty():
		return _truncate_line(_compact_briefing_text(final_summary), 120)

	var headline := str(payload.get("headline", "")).strip_edges()
	var weather_summary := _nested_summary(payload, "weather")
	var calendar_summary := _nested_summary(payload, "calendar")
	var slack_summary := _nested_summary(payload, "slack")

	var segments: Array[String] = []
	if not headline.is_empty():
		segments.append(headline)
	if not weather_summary.is_empty():
		segments.append(weather_summary)
	if not calendar_summary.is_empty():
		segments.append(calendar_summary)
	if not slack_summary.is_empty():
		segments.append(slack_summary)

	return _truncate_line(_compact_briefing_text(" ".join(segments)), 120)


func _truncate_line(text: String, max_length: int) -> String:
	var trimmed := text.strip_edges()
	if trimmed.length() <= max_length:
		return trimmed
	return trimmed.substr(0, max_length) + "..."


func _compact_briefing_text(text: String) -> String:
	var compact := text.strip_edges()
	if compact.is_empty():
		return ""
	compact = _normalize_whitespace(compact)

	var delimiters := [". ", "! ", "? ", "。"]
	for delimiter in delimiters:
		var cut_index := compact.find(delimiter)
		if cut_index > 0:
			return compact.substr(0, cut_index).strip_edges()
	return compact


func _normalize_whitespace(text: String) -> String:
	var normalized := text.strip_edges()
	if normalized.is_empty():
		return ""
	normalized = normalized.replace("\n", " ")
	normalized = normalized.replace("\t", " ")
	return " ".join(normalized.split(" ", false))


func _announce_idle_brief(summary: String) -> void:
	var brief_line := "Idle • %s" % summary
	_alert_feed.push_front(brief_line)
	if _alert_feed.size() > 3:
		_alert_feed.resize(3)
	_refresh_alert_cards()
	tray_status_label.text = "Idle briefing delivered"
	var bubble_text := _truncate_line(_compact_briefing_text(summary), BUBBLE_TEXT_MAX_CHARS)
	_dispatch_announcement(bubble_text, "set_mood_happy", PRIORITY_IDLE_BRIEF, bubble_text)


func _on_calendar_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
) -> void:
	_calendar_request_in_flight = false
	_calendar_request_started_at_ms = 0
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		var error_payload_variant: Variant = JSON.parse_string(body.get_string_from_utf8())
		var error_payload: Dictionary = error_payload_variant if error_payload_variant is Dictionary else {}
		var message := _standardized_error_message(
			"Calendar monitor",
			response_code,
			error_payload,
			"Calendar monitor disconnected.",
		)
		if not _calendar_error_notified:
			_calendar_error_notified = true
			_notify_monitor_error(ALERT_SOURCE_CALENDAR, message)
		_update_monitor_info_labels()
		return
	_calendar_error_notified = false
	_calendar_timeout_retry_count = 0

	var payload: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (payload is Dictionary):
		return
	var payload_dict: Dictionary = payload
	if payload_dict.has("error"):
		var message := _standardized_error_message(
			"Calendar monitor",
			response_code,
			payload_dict,
			"Calendar monitor returned an error.",
		)
		if not _calendar_error_notified:
			_calendar_error_notified = true
			_notify_monitor_error(ALERT_SOURCE_CALENDAR, message)
		_update_monitor_info_labels()
		return

	var events_variant: Variant = payload_dict.get("events", [])
	var events: Array = events_variant if events_variant is Array else []
	var signature := _signature_from_events(events)
	if not _calendar_signature.is_empty() and signature != _calendar_signature:
		_push_alert(
			ALERT_SOURCE_CALENDAR,
			"Schedule changed (%d event(s) today)." % events.size(),
			"set_mood_surprised"
		)
	_calendar_signature = signature
	mini_info_line_2.text = "Today events: %d" % events.size()
	_update_monitor_info_labels()


func _on_slack_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
) -> void:
	_slack_request_in_flight = false
	_slack_request_started_at_ms = 0
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		var error_payload_variant: Variant = JSON.parse_string(body.get_string_from_utf8())
		var error_payload: Dictionary = error_payload_variant if error_payload_variant is Dictionary else {}
		var message := _standardized_error_message(
			"Slack monitor",
			response_code,
			error_payload,
			"Slack monitor disconnected.",
		)
		if not _slack_error_notified:
			_slack_error_notified = true
			_notify_monitor_error(ALERT_SOURCE_SLACK, message)
		_update_monitor_info_labels()
		return
	_slack_error_notified = false
	_slack_timeout_retry_count = 0

	var payload: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (payload is Dictionary):
		return
	var payload_dict: Dictionary = payload
	if payload_dict.has("error"):
		var message := _standardized_error_message(
			"Slack monitor",
			response_code,
			payload_dict,
			"Slack monitor returned an error.",
		)
		if not _slack_error_notified:
			_slack_error_notified = true
			_notify_monitor_error(ALERT_SOURCE_SLACK, message)
		_update_monitor_info_labels()
		return

	var message_count := int(payload_dict.get("message_count", 0))
	var latest_ts := str(payload_dict.get("latest_message_ts", ""))
	var signature := "%d|%s" % [message_count, latest_ts]
	if not _slack_signature.is_empty() and signature != _slack_signature:
		var preview := str(payload_dict.get("latest_message_preview", "")).strip_edges()
		if preview.length() > 42:
			preview = preview.substr(0, 42) + "..."
		var message := "New Slack activity (%d msg)." % message_count
		if not preview.is_empty():
			message = "%s %s" % [message, preview]
		_push_alert(ALERT_SOURCE_SLACK, message, "set_mood_happy")
	_slack_signature = signature
	_update_monitor_info_labels()


func _signature_from_events(events: Array) -> String:
	var chunks: Array[String] = []
	for event_variant in events:
		if not (event_variant is Dictionary):
			continue
		var event: Dictionary = event_variant
		chunks.append(
			"%s|%s|%s|%s" % [
				str(event.get("id", "")),
				str(event.get("start", "")),
				str(event.get("end", "")),
				str(event.get("title", "")),
			]
		)
	chunks.sort()
	return "%d#%s" % [chunks.size(), "|".join(chunks)]


func _push_alert(source: String, message: String, mood_method: String) -> void:
	var alert_line := "%s • %s" % [source, message]
	_alert_feed.push_front(alert_line)
	if _alert_feed.size() > 3:
		_alert_feed.resize(3)

	_unread_alert_count += 1
	tray_status_label.text = alert_line
	_refresh_alert_cards()
	_set_status_indicator_alert(true, "Jarvis alert: %s" % message)
	var priority := PRIORITY_MONITOR_ALERT
	if source == ALERT_SOURCE_VOICE:
		priority = PRIORITY_VOICE
	elif source == ALERT_SOURCE_SYSTEM:
		priority = PRIORITY_SYSTEM_ERROR
	_dispatch_announcement(message, mood_method, priority, "%s alert. %s" % [source, message])


func _notify_monitor_error(source: String, message: String) -> void:
	_push_alert(source, message, "set_mood_error")


func _refresh_alert_cards() -> void:
	if _active_nav_name == "NavAgent":
		_render_agent_cards()
		_update_monitor_info_labels()
		return

	_render_alert_cards()
	_update_monitor_info_labels()


func _render_alert_cards() -> void:
	var fallback := [
		"Waiting for backend monitor...",
		"No recent alerts.",
		"Slack/Calendar polling active.",
	]
	var lines: Array[String] = []
	for alert_line in _alert_feed:
		lines.append(alert_line)
	while lines.size() < 3:
		lines.append(fallback[lines.size()])

	alert_card_1_label.text = _truncate_line(lines[0], ALERT_CARD_MAX_CHARS)
	alert_card_2_label.text = _truncate_line(lines[1], ALERT_CARD_MAX_CHARS)
	alert_card_3_label.text = _truncate_line(lines[2], ALERT_CARD_MAX_CHARS)


func _render_agent_cards() -> void:
	var fallback := [
		"Agent status: %s" % _agent_last_status,
		"Last command: %s" % (_agent_last_command if not _agent_last_command.is_empty() else "-"),
		"Last transcript: %s" % (_last_transcript if not _last_transcript.is_empty() else "-"),
	]
	var lines: Array[String] = []
	for line in _agent_activity_feed:
		lines.append(line)
	while lines.size() < 3:
		lines.append(fallback[lines.size()])

	alert_card_1_label.text = _truncate_line(lines[0], ALERT_CARD_MAX_CHARS)
	alert_card_2_label.text = _truncate_line(lines[1], ALERT_CARD_MAX_CHARS)
	alert_card_3_label.text = _truncate_line(lines[2], ALERT_CARD_MAX_CHARS)


func _update_agent_panel_state(
	transcript: String,
	status: String,
	command: String,
	explanation: String,
) -> void:
	_last_transcript = transcript.strip_edges()
	_agent_last_status = status.strip_edges()
	_agent_last_command = command.strip_edges()
	_agent_last_explanation = explanation.strip_edges()
	_agent_last_updated = Time.get_time_string_from_system().substr(0, 5)

	var line_1 := "Status %s • %s" % [_agent_last_status, _agent_last_updated]
	var line_2 := "Cmd: %s" % (
		_agent_last_command if not _agent_last_command.is_empty() else "-"
	)
	var line_3 := "Explain: %s" % (
		_truncate_line(_agent_last_explanation, 72)
		if not _agent_last_explanation.is_empty()
		else "-"
	)

	_agent_activity_feed = [line_1, line_2, line_3]
	_refresh_alert_cards()


func _clear_unread_alerts() -> void:
	_unread_alert_count = 0
	_set_status_indicator_alert(false, "Jarvis monitor active")
	_update_monitor_info_labels()


func _update_monitor_info_labels() -> void:
	var monitor_state := "active" if _monitor_enabled else "paused"
	var slack_state := "off" if slack_channel_id.strip_edges().is_empty() else "on"
	var pending_requests := 0
	if _calendar_request_in_flight:
		pending_requests += 1
	if _slack_request_in_flight:
		pending_requests += 1
	if _idle_brief_request_in_flight:
		pending_requests += 1
	if _stt_request_in_flight:
		pending_requests += 1
	if _agent_request_in_flight:
		pending_requests += 1
	if _tool_call_request_in_flight:
		pending_requests += 1

	var idle_state := "on" if idle_brief_enabled else "off"
	mini_info_line_1.text = "Monitor: %s (Slack %s / Idle %s) • %s" % [
		monitor_state,
		slack_state,
		idle_state,
		_last_poll_time,
	]
	mini_info_line_3.text = "Pending alerts: %d • Requests: %d • Queue: %d" % [
		_unread_alert_count,
		pending_requests,
		_tool_call_queue.size(),
	]


func _backend_root() -> String:
	return backend_base_url.rstrip("/")


func _enqueue_tool_calls(tool_calls_variant: Variant) -> int:
	if not (tool_calls_variant is Array):
		return 0

	var accepted := 0
	for item in tool_calls_variant:
		if not (item is Dictionary):
			continue
		var normalized := _normalize_tool_call(item)
		if normalized.is_empty():
			continue
		if not _is_tool_call_allowed(normalized):
			var rejected_name := str(normalized.get("name", "unknown_tool"))
			_notify_monitor_error(ALERT_SOURCE_VOICE, "Rejected tool call: %s" % rejected_name)
			continue
		if _tool_call_queue.size() >= TOOL_CALL_MAX_QUEUE:
			_notify_monitor_error(ALERT_SOURCE_VOICE, "Tool call queue is full.")
			break
		_tool_call_queue.append(normalized)
		accepted += 1

	_start_next_tool_call_if_needed()
	_update_monitor_info_labels()
	return accepted


func _normalize_tool_call(raw: Dictionary) -> Dictionary:
	var tool_name := str(raw.get("name", "")).strip_edges()
	var method := str(raw.get("method", "GET")).strip_edges().to_upper()
	var path := str(raw.get("path", "")).strip_edges()
	if tool_name.is_empty() or method.is_empty() or path.is_empty():
		return {}
	if not path.begins_with("/api/v1/"):
		return {}

	var query_value: Variant = raw.get("query", {})
	var body_value: Variant = raw.get("body", null)
	var normalized := {
		"name": tool_name,
		"method": method,
		"path": path,
		"query": query_value if query_value is Dictionary else {},
		"body": body_value,
	}
	return normalized


func _is_tool_call_allowed(tool_call: Dictionary) -> bool:
	var tool_name := str(tool_call.get("name", ""))
	var method := str(tool_call.get("method", "")).to_upper()
	var path := str(tool_call.get("path", ""))
	if not TOOL_CALL_ALLOWLIST.has(tool_name):
		return false

	var rule_variant: Variant = TOOL_CALL_ALLOWLIST.get(tool_name, {})
	if not (rule_variant is Dictionary):
		return false
	var rule: Dictionary = rule_variant
	if str(rule.get("method", "")).to_upper() != method:
		return false

	var exact := str(rule.get("exact", "")).strip_edges()
	if not exact.is_empty():
		return path == exact

	var prefix := str(rule.get("prefix", "")).strip_edges()
	if not prefix.is_empty() and not path.begins_with(prefix):
		return false

	var suffix := str(rule.get("suffix", "")).strip_edges()
	if not suffix.is_empty() and not path.ends_with(suffix):
		return false

	return not prefix.is_empty() or not suffix.is_empty()


func _start_next_tool_call_if_needed() -> void:
	if _tool_call_request_in_flight:
		return
	if _tool_call_queue.is_empty():
		return

	_active_tool_call = _tool_call_queue.pop_front()
	var method_name := str(_active_tool_call.get("method", "GET")).to_upper()
	var method := _http_method_from_string(method_name)
	if method < 0:
		var invalid_name := str(_active_tool_call.get("name", "unknown_tool"))
		_notify_monitor_error(ALERT_SOURCE_VOICE, "Unsupported HTTP method: %s" % method_name)
		_update_agent_panel_state(
			_last_transcript,
			"error",
			_agent_last_command,
			"Tool %s rejected due to invalid method." % invalid_name,
		)
		_active_tool_call = {}
		_start_next_tool_call_if_needed()
		return

	var path := str(_active_tool_call.get("path", ""))
	var query_variant: Variant = _active_tool_call.get("query", {})
	var query: Dictionary = query_variant if query_variant is Dictionary else {}
	var url := _build_url_with_query(path, query)
	var headers := PackedStringArray()
	var request_body := ""
	if method_name == "POST":
		headers.append("Content-Type: application/json")
		var body_variant: Variant = _active_tool_call.get("body", null)
		if not (body_variant == null):
			request_body = JSON.stringify(body_variant)

	var err := tool_call_request.request(url, headers, method, request_body)
	if err != OK:
		var request_name := str(_active_tool_call.get("name", "unknown_tool"))
		_notify_monitor_error(ALERT_SOURCE_VOICE, "Tool call request failed: %s" % request_name)
		_update_agent_panel_state(
			_last_transcript,
			"error",
			_agent_last_command,
			"Tool request failed to start: %s" % request_name,
		)
		_active_tool_call = {}
		_start_next_tool_call_if_needed()
		return

	_tool_call_request_in_flight = true
	_tool_call_request_started_at_ms = Time.get_ticks_msec()
	var running_name := str(_active_tool_call.get("name", "tool"))
	_update_agent_panel_state(
		_last_transcript,
		"executing",
		_agent_last_command,
		"Running tool: %s" % running_name,
	)
	_update_monitor_info_labels()


func _on_tool_call_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
) -> void:
	_tool_call_request_in_flight = false
	_tool_call_request_started_at_ms = 0

	var tool_name := str(_active_tool_call.get("name", "tool"))
	var ok := result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300
	var payload_variant: Variant = JSON.parse_string(body.get_string_from_utf8())
	var payload: Dictionary = payload_variant if payload_variant is Dictionary else {}
	if ok and payload.has("error"):
		ok = false

	if ok:
		_capture_mock_showcase_context(tool_name, payload)
		var result_line := _summarize_tool_call_result(tool_name, payload)
		var should_announce := _should_announce_tool_result(tool_name, result_line)
		var emitted := false
		if should_announce:
			emitted = _record_tool_result(result_line)
		_update_agent_panel_state(
			_last_transcript,
			"executed",
			_agent_last_command,
			result_line,
		)
		if should_announce and emitted:
			_dispatch_announcement(
				result_line,
				"set_mood_happy",
				PRIORITY_MONITOR_ALERT,
				result_line,
			)
	else:
		var message := _standardized_error_message(
			tool_name,
			response_code,
			payload,
			"Tool call failed: %s" % tool_name,
		)
		_notify_monitor_error(ALERT_SOURCE_VOICE, message)
		_update_agent_panel_state(
			_last_transcript,
			"error",
			_agent_last_command,
			message,
		)

	_active_tool_call = {}
	_start_next_tool_call_if_needed()
	if _tool_call_queue.is_empty() and not _tool_call_request_in_flight:
		tray_status_label.text = "Mock showcase running" if _mock_showcase_running else "Voice command ready"
	_update_monitor_info_labels()


func _capture_mock_showcase_context(tool_name: String, payload: Dictionary) -> void:
	match tool_name:
		"list_calendar_events":
			var events_variant: Variant = payload.get("events", [])
			if _mock_showcase_running:
				_showcase_presentation_schedule = "4월 21일 09:00 프로젝트 발표"
				_showcase_calendar_summary = "1 scheduled event for 2026-04-21: Project presentation at 09:00."
			else:
				var schedule := _extract_presentation_schedule(events_variant)
				if not schedule.is_empty():
					_showcase_presentation_schedule = schedule
		"get_calendar_summary":
			var raw_calendar_summary := str(payload.get("summary", "")).strip_edges()
			if _mock_showcase_running and raw_calendar_summary.to_lower().find("no scheduled events") >= 0:
				_showcase_calendar_summary = "1 scheduled event for 2026-04-21: Project presentation at 09:00."
			else:
				_showcase_calendar_summary = raw_calendar_summary
		"slack_summary":
			var slack_summary := str(payload.get("summary", "")).strip_edges()
			_showcase_slack_summary = _compact_briefing_text(slack_summary)
		"create_briefing":
			var weather_variant: Variant = payload.get("weather", {})
			if weather_variant is Dictionary:
				var weather_dict: Dictionary = weather_variant
				_showcase_weather_summary = str(weather_dict.get("summary", "")).strip_edges()

				var calendar_variant: Variant = payload.get("calendar", {})
				if calendar_variant is Dictionary:
					var calendar_dict: Dictionary = calendar_variant
					_showcase_calendar_summary = str(calendar_dict.get("summary", "")).strip_edges()
					if _mock_showcase_running and _showcase_calendar_summary.to_lower().find("no scheduled events") >= 0:
						_showcase_calendar_summary = "1 scheduled event for 2026-04-21: Project presentation at 09:00."
					var cal_events_variant: Variant = calendar_dict.get("events", [])
					var schedule := _extract_presentation_schedule(cal_events_variant)
					if not _mock_showcase_running and not schedule.is_empty():
						_showcase_presentation_schedule = schedule
					elif _mock_showcase_running:
						_showcase_presentation_schedule = "4월 21일 09:00 프로젝트 발표"

				var slack_variant: Variant = payload.get("slack", {})
				if slack_variant is Dictionary:
					var slack_dict: Dictionary = slack_variant
					_showcase_slack_summary = str(slack_dict.get("summary", "")).strip_edges()
					_showcase_slack_summary = _compact_briefing_text(_showcase_slack_summary)

				var final_summary := str(payload.get("final_summary", "")).strip_edges()
				_showcase_briefing_summary = _compact_briefing_text(final_summary)
				if _mock_showcase_running and _showcase_briefing_summary.to_lower().find("no scheduled events") >= 0:
					_showcase_briefing_summary = "오전 9시 프로젝트 발표 1건 기준으로 준비 상태를 점검했습니다."


func _extract_presentation_schedule(events_variant: Variant) -> String:
	if not (events_variant is Array):
		return ""
	var events: Array = events_variant
	for event_variant in events:
		if not (event_variant is Dictionary):
			continue
		var event_dict: Dictionary = event_variant
		var title := str(event_dict.get("title", "")).strip_edges()
		if title.find("발표") == -1:
			continue
		var start_text := str(event_dict.get("start", "")).strip_edges()
		var schedule := _format_schedule_slot(start_text)
		if schedule.is_empty():
			schedule = "4월 21일 09:00"
		return "%s %s" % [schedule, title]
	return ""


func _format_schedule_slot(start_iso: String) -> String:
	if start_iso.length() < 16:
		return ""
	var date_part := start_iso.substr(0, 10)
	var time_part := start_iso.substr(11, 5)
	if date_part.length() != 10:
		return ""
	var year_month_day := date_part.split("-")
	if year_month_day.size() != 3:
		return ""
	var month := int(year_month_day[1])
	var day := int(year_month_day[2])
	return "%d월 %d일 %s" % [month, day, time_part]


func _summarize_tool_call_result(tool_name: String, payload: Dictionary) -> String:
	match tool_name:
		"list_calendar_events":
			var events_variant: Variant = payload.get("events", [])
			if _mock_showcase_running:
				return "Calendar • 1 event loaded: 09:00 프로젝트 발표."
			var count: int = int(events_variant.size()) if events_variant is Array else 0
			return "Calendar • %d event(s) loaded." % count
		"get_calendar_summary":
			if _mock_showcase_running:
				return "Calendar • 1 scheduled event: 09:00 프로젝트 발표."
			var summary := str(payload.get("summary", "")).strip_edges()
			if summary.is_empty():
				return "Calendar summary loaded."
			return "Calendar • %s" % _truncate_line(summary, 72)
		"slack_activity":
			var message_count := int(payload.get("message_count", 0))
			var preview := str(payload.get("latest_message_preview", "")).strip_edges()
			if preview.is_empty():
				return "Slack • %d message(s) checked." % message_count
			return "Slack • %d message(s), latest: %s" % [
				message_count,
				_truncate_line(preview, 52),
			]
		"slack_summary":
			var summary := str(payload.get("summary", "")).strip_edges()
			if summary.is_empty():
				return "Slack summary loaded."
			return "Slack summary • %s" % _truncate_line(_compact_briefing_text(summary), 72)
		"create_briefing":
			var final_summary := str(payload.get("final_summary", "")).strip_edges()
			if final_summary.is_empty():
				return "Briefing generated."
			return "Briefing • %s" % _truncate_line(_compact_briefing_text(final_summary), 72)
		"admin_summary":
			var top_feature := str(payload.get("top_token_feature", "")).strip_edges()
			if top_feature.is_empty():
				return "Admin summary loaded."
			return "Admin • Top token feature: %s" % _truncate_line(top_feature, 56)
		"presentation_demo":
			var closing := str(payload.get("closing_message", "")).strip_edges()
			if closing.is_empty():
				return "Presentation demo loaded."
			return "Presentation • %s" % _truncate_line(closing, 72)
		"health_sleep_summary":
			var wake_time := str(payload.get("wake_time", "")).strip_edges()
			var recommendation := str(payload.get("today_sleep_recommendation", "")).strip_edges()
			if not wake_time.is_empty():
				return "Health • wake time %s" % wake_time
			if not recommendation.is_empty():
				return "Health • %s" % _truncate_line(recommendation, 72)
			var summary := str(payload.get("summary", "")).strip_edges()
			if not summary.is_empty():
				return "Health • %s" % _truncate_line(summary, 72)
			return "Health summary loaded."
		"list_calendar_operation_proposals":
			var ops_variant: Variant = payload.get("operations", [])
			var count: int = int(ops_variant.size()) if ops_variant is Array else 0
			return "Calendar ops • %d proposal(s)." % count
		"list_calendar_operation_audit_records":
			var records_variant: Variant = payload.get("records", [])
			var count: int = int(records_variant.size()) if records_variant is Array else 0
			return "Calendar audit • %d record(s)." % count
		"health_check":
			var status_text := str(payload.get("status", "")).strip_edges()
			return "Health check • %s" % (status_text if not status_text.is_empty() else "ok")
		_:
			var summary := str(payload.get("summary", "")).strip_edges()
			if summary.is_empty():
				return "Action completed: %s" % tool_name
			return "%s • %s" % [tool_name, _truncate_line(_compact_briefing_text(summary), 68)]


func _should_announce_tool_result(tool_name: String, line: String) -> bool:
	if line.strip_edges().is_empty():
		return false
	if _mock_showcase_running and tool_name == "get_calendar_summary":
		return false
	return true


func _record_tool_result(line: String) -> bool:
	var normalized := line.strip_edges()
	if normalized.is_empty():
		return false
	var now_ms := Time.get_ticks_msec()
	if normalized == _last_tool_result_line and (now_ms - _last_tool_result_at_ms) < TOOL_RESULT_DEDUP_WINDOW_MS:
		return false
	_last_tool_result_line = normalized
	_last_tool_result_at_ms = now_ms
	_alert_feed.push_front(normalized)
	if _alert_feed.size() > 3:
		_alert_feed.resize(3)
	_refresh_alert_cards()
	_unread_alert_count += 1
	_set_status_indicator_alert(true, normalized)
	return true


func _http_method_from_string(method_name: String) -> int:
	match method_name.to_upper():
		"GET":
			return HTTPClient.METHOD_GET
		"POST":
			return HTTPClient.METHOD_POST
		_:
			return -1


func _build_url_with_query(path: String, query: Dictionary) -> String:
	var url := "%s%s" % [_backend_root(), path]
	if query.is_empty():
		return url

	var keys := query.keys()
	keys.sort()
	var query_parts: Array[String] = []
	for key in keys:
		var key_text := str(key).uri_encode()
		var value_text := str(query.get(key, "")).uri_encode()
		query_parts.append("%s=%s" % [key_text, value_text])
	return "%s?%s" % [url, "&".join(query_parts)]


func _is_voice_pipeline_busy() -> bool:
	return _mic_recording or _stt_request_in_flight or _agent_request_in_flight or _tool_call_request_in_flight


func _is_tts_speaking() -> bool:
	if _tts_available and tts_enabled and DisplayServer.has_method("tts_is_speaking"):
		var speaking_variant: Variant = DisplayServer.call("tts_is_speaking")
		if speaking_variant is bool and bool(speaking_variant):
			return true
	return Time.get_ticks_msec() < _tts_guard_until_ms


func _dispatch_announcement(
	message: String,
	mood_method: String,
	priority: int,
	tts_text: String = "",
) -> void:
	var line := message.strip_edges()
	if line.is_empty():
		return

	var speech_line := tts_text.strip_edges()
	if speech_line.is_empty():
		speech_line = line

	# While speech is still playing, queue non-voice announcements instead of interrupting.
	if _is_tts_speaking() and priority < PRIORITY_VOICE:
		_enqueue_announcement(line, mood_method, priority, speech_line)
		return

	if _is_voice_pipeline_busy() and priority < PRIORITY_VOICE:
		_enqueue_announcement(line, mood_method, priority, speech_line)
		return

	if speech_bubble.visible and priority <= _current_announcement_priority:
		_enqueue_announcement(line, mood_method, priority, speech_line)
		return

	_current_announcement_priority = priority
	_show_speech_bubble(line)
	_speak_with_tts(speech_line)
	_play_avatar_method(mood_method)


func _enqueue_announcement(
	message: String,
	mood_method: String,
	priority: int,
	tts_text: String,
) -> void:
	var entry := {
		"message": message,
		"mood": mood_method,
		"priority": priority,
		"tts": tts_text,
	}
	_announcement_queue.append(entry)
	_announcement_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("priority", 0)) > int(b.get("priority", 0))
	)


func _flush_announcement_queue() -> void:
	if _announcement_queue.is_empty():
		return
	if _is_voice_pipeline_busy():
		return
	if _is_tts_speaking():
		return

	var next: Dictionary = _announcement_queue.pop_front()
	_dispatch_announcement(
		str(next.get("message", "")),
		str(next.get("mood", "set_mood_idle")),
		int(next.get("priority", PRIORITY_MONITOR_ALERT)),
		str(next.get("tts", "")),
	)


func _standardized_error_message(
	domain: String,
	response_code: int,
	payload: Dictionary,
	fallback: String,
) -> String:
	var error_variant: Variant = payload.get("error", {})
	if error_variant is Dictionary:
		var error_dict: Dictionary = error_variant
		var error_code := str(error_dict.get("code", "")).strip_edges()
		var error_message := str(error_dict.get("message", "")).strip_edges()
		if not error_code.is_empty():
			match error_code:
				"openai_not_configured":
					return "%s unavailable: OPENAI_API_KEY is missing." % domain
				"openai_request_failed":
					return "%s request failed at provider." % domain
				"openai_empty_response":
					return "%s returned empty response." % domain
				"invalid_audio_base64", "empty_audio_payload", "audio_payload_too_large":
					return "Voice input error: %s" % error_code
				"invalid_bridge_token":
					return "%s authentication failed." % domain
		if not error_message.is_empty():
			return "%s: %s" % [domain, error_message]

	if response_code == 401:
		return "%s authentication failed." % domain
	if response_code == 503:
		return "%s service temporarily unavailable." % domain
	if response_code >= 500:
		return "%s server error." % domain
	return fallback


func _show_speech_bubble(text: String) -> void:
	var line := _truncate_line(text.strip_edges(), BUBBLE_TEXT_MAX_CHARS)
	if line.is_empty():
		return
	speech_label.text = line
	speech_bubble.modulate.a = 1.0
	speech_bubble.visible = true
	if _bubble_tween:
		_bubble_tween.kill()
	_update_speech_bubble_position()
	var hold_sec := bubble_visible_sec
	if _mock_showcase_running:
		hold_sec = maxf(hold_sec, mock_showcase_bubble_min_sec)
	bubble_timer.start(hold_sec)


func _update_speech_bubble_position() -> void:
	var bubble_size := speech_bubble.size
	var stage_size := arena_stage.size
	var target := avatar.position + Vector2(-bubble_size.x * 0.5, -228.0)
	target.x = clampf(target.x, 12.0, max(12.0, stage_size.x - bubble_size.x - 12.0))
	target.y = clampf(target.y, 12.0, max(12.0, stage_size.y - bubble_size.y - 12.0))
	speech_bubble.position = target


func _on_bubble_timer_timeout() -> void:
	if _is_tts_speaking():
		if speech_bubble.visible:
			speech_bubble.modulate.a = 1.0
		bubble_timer.start(0.35)
		return
	if not speech_bubble.visible:
		_current_announcement_priority = -1
		_flush_announcement_queue()
		return
	if _bubble_tween:
		_bubble_tween.kill()
	_bubble_tween = create_tween()
	_bubble_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bubble_tween.tween_property(speech_bubble, "modulate:a", 0.0, 0.2)
	_bubble_tween.chain().tween_callback(func():
		speech_bubble.visible = false
		_current_announcement_priority = -1
		_flush_announcement_queue()
	)


func _initialize_tts() -> void:
	if not tts_enabled:
		return
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		return
	if not DisplayServer.has_method("tts_speak"):
		return
	_tts_available = true

	if tts_voice_id.strip_edges().is_empty() and DisplayServer.has_method("tts_get_voices"):
		var voices_variant: Variant = DisplayServer.call("tts_get_voices")
		if voices_variant is PackedStringArray:
			var voice_ids: PackedStringArray = voices_variant
			if not voice_ids.is_empty():
				tts_voice_id = voice_ids[0]
		elif voices_variant is Array:
			var voices: Array = voices_variant
			if not voices.is_empty():
				var first_voice: Variant = voices[0]
				if first_voice is Dictionary:
					var voice_dict: Dictionary = first_voice
					tts_voice_id = str(voice_dict.get("id", voice_dict.get("name", "")))
				else:
					tts_voice_id = str(first_voice)


func _speak_with_tts(text: String) -> void:
	if not _tts_available or not tts_enabled:
		return
	var line := text.strip_edges()
	if line.is_empty():
		return

	var estimated_sec := clampf(
		float(line.length()) / TTS_ESTIMATED_CHARS_PER_SECOND,
		TTS_ESTIMATED_MIN_SEC,
		TTS_ESTIMATED_MAX_SEC
	)
	if _mock_showcase_running:
		estimated_sec = maxf(estimated_sec, mock_showcase_bubble_min_sec + 0.8)
	_tts_guard_until_ms = Time.get_ticks_msec() + int(estimated_sec * 1000.0)

	if DisplayServer.has_method("tts_stop"):
		DisplayServer.call("tts_stop")
	if DisplayServer.has_method("tts_speak"):
		DisplayServer.call("tts_speak", line, tts_voice_id)


func _initialize_status_indicator() -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_STATUS_INDICATOR):
		return
	_status_icon_normal = _build_indicator_icon(Color(0.39, 0.74, 1.0, 1.0))
	_status_icon_alert = _build_indicator_icon(Color(1.0, 0.45, 0.4, 1.0))
	_status_indicator_id = DisplayServer.create_status_indicator(
		_status_icon_normal,
		"Jarvis monitor active",
		Callable(self, "_on_status_indicator_activated")
	)
	_status_indicator_supported = _status_indicator_id >= 0


func _build_indicator_icon(color: Color) -> Texture2D:
	var image := Image.create(28, 28, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center := Vector2(14.0, 14.0)

	for y in range(28):
		for x in range(28):
			var pixel_center := Vector2(x + 0.5, y + 0.5)
			var distance := pixel_center.distance_to(center)
			if distance <= 12.5:
				image.set_pixel(x, y, Color(0.07, 0.1, 0.17, 1.0))
			if distance <= 8.2:
				image.set_pixel(x, y, color)

	return ImageTexture.create_from_image(image)


func _set_status_indicator_alert(active: bool, tooltip: String) -> void:
	if not _status_indicator_supported or _status_indicator_id < 0:
		return
	DisplayServer.status_indicator_set_icon(
		_status_indicator_id,
		_status_icon_alert if active else _status_icon_normal
	)
	DisplayServer.status_indicator_set_tooltip(_status_indicator_id, tooltip)


func _setup_background_close_behavior() -> void:
	if not _status_indicator_supported:
		return
	get_tree().set_auto_accept_quit(false)
	get_window().close_requested.connect(_on_window_close_requested)


func _on_window_close_requested() -> void:
	if not _status_indicator_supported:
		get_tree().quit()
		return
	get_window().hide()
	_set_status_indicator_alert(
		_unread_alert_count > 0,
		"Jarvis running in background. Click tray icon to reopen."
	)


func _on_status_indicator_activated() -> void:
	var window := get_window()
	if window.visible:
		window.hide()
		return
	window.show()
	window.mode = Window.MODE_WINDOWED
	window.grab_focus()
	_clear_unread_alerts()


func _exit_tree() -> void:
	watchdog_tick_timer.stop()
	idle_brief_timer.stop()
	poll_timer.stop()
	if _calendar_request_in_flight and calendar_request.has_method("cancel_request"):
		calendar_request.cancel_request()
	if _slack_request_in_flight and slack_request.has_method("cancel_request"):
		slack_request.cancel_request()
	if _idle_brief_request_in_flight and idle_brief_request.has_method("cancel_request"):
		idle_brief_request.cancel_request()
	if _stt_request_in_flight and stt_request.has_method("cancel_request"):
		stt_request.cancel_request()
	if _agent_request_in_flight and agent_request.has_method("cancel_request"):
		agent_request.cancel_request()
	if _tool_call_request_in_flight and tool_call_request.has_method("cancel_request"):
		tool_call_request.cancel_request()
	_tool_call_request_in_flight = false
	_tool_call_request_started_at_ms = 0
	_tool_call_queue.clear()
	_active_tool_call = {}
	_mock_showcase_running = false
	if _mock_showcase_timer:
		_mock_showcase_timer.stop()
	if _mic_record_effect and _mic_record_effect.is_recording_active():
		_mic_record_effect.set_recording_active(false)
	if _mic_capture_player and _mic_capture_player.playing:
		_mic_capture_player.stop()
	if _tts_available and DisplayServer.has_method("tts_stop"):
		DisplayServer.call("tts_stop")
	if _status_indicator_id >= 0:
		DisplayServer.delete_status_indicator(_status_indicator_id)


func speak_text(text: String, mood: String = "speaking") -> void:
	var line := text.strip_edges()
	if line.is_empty():
		return
	var mood_method := _resolve_mood_method(mood)
	_dispatch_announcement(line, mood_method, PRIORITY_VOICE, line)


func play_mood(mood: String) -> void:
	_play_avatar_method(_resolve_mood_method(mood))


func _resolve_mood_method(mood: String) -> String:
	var normalized := mood.strip_edges().to_lower()
	match normalized:
		"idle":
			return "set_mood_idle"
		"thinking":
			return "set_mood_thinking"
		"speaking":
			return "set_mood_speaking"
		"happy":
			return "set_mood_happy"
		"surprised":
			return "set_mood_surprised"
		"sad":
			return "set_mood_sad"
		"error":
			return "set_mood_error"
		"angry":
			return "set_mood_angry"
		"embarrassed":
			return "set_mood_embarrassed"
		_:
			return "set_mood_idle"
