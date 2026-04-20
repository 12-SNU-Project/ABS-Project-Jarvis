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
var _unread_alert_count := 0
var _last_poll_time := "--:--"
var _status_indicator_id := -1
var _status_indicator_supported := false
var _status_icon_normal: Texture2D
var _status_icon_alert: Texture2D
var _bubble_tween: Tween
var _tts_available := false
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
	_mood_index = (_mood_index + 1) % MOOD_METHODS.size()
	_play_avatar_method(MOOD_METHODS[_mood_index])


func _step_mood() -> void:
	_on_mood_timer_timeout()


func _apply_random_mood() -> void:
	if MOOD_METHODS.is_empty():
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
	if _active_nav_name != "NavHome":
		return
	if _calendar_request_in_flight or _slack_request_in_flight or _idle_brief_request_in_flight:
		return
	if _mic_recording or _stt_request_in_flight or _agent_request_in_flight:
		return
	_request_idle_brief()


func _on_watchdog_tick_timeout() -> void:
	var timeout_ms := int(request_timeout_sec * 1000.0)
	_check_request_timeout("calendar", _calendar_request_in_flight, _calendar_request_started_at_ms, timeout_ms)
	_check_request_timeout("slack", _slack_request_in_flight, _slack_request_started_at_ms, timeout_ms)
	_check_request_timeout("idle_brief", _idle_brief_request_in_flight, _idle_brief_request_started_at_ms, timeout_ms)
	_check_request_timeout("stt", _stt_request_in_flight, _stt_request_started_at_ms, timeout_ms)
	_check_request_timeout("agent", _agent_request_in_flight, _agent_request_started_at_ms, timeout_ms)


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
	else:
		tray_monitor_button.text = "Resume Monitor"
		tray_status_label.text = "Monitoring paused"
		poll_timer.stop()
		idle_brief_timer.stop()
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
		_notify_monitor_error(ALERT_SOURCE_VOICE, "STT request failed.")
		tray_status_label.text = "Voice request failed"
		return

	var payload_variant: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (payload_variant is Dictionary):
		_notify_monitor_error(ALERT_SOURCE_VOICE, "STT response parsing failed.")
		return

	var payload: Dictionary = payload_variant
	if payload.has("error"):
		var error_payload: Variant = payload.get("error", {})
		var message := "STT error"
		if error_payload is Dictionary:
			message = str(error_payload.get("message", message))
		_notify_monitor_error(ALERT_SOURCE_VOICE, message)
		tray_status_label.text = "Voice request failed"
		return

	var transcript := str(payload.get("transcript", "")).strip_edges()
	if transcript.is_empty():
		_notify_monitor_error(ALERT_SOURCE_VOICE, "STT returned empty transcript.")
		tray_status_label.text = "Voice request failed"
		_update_monitor_info_labels()
		return

	tray_status_label.text = "Transcript ready"
	_show_speech_bubble("인식: %s" % transcript)
	_speak_with_tts(transcript)
	_play_avatar_method("set_mood_speaking")
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
		_notify_monitor_error(ALERT_SOURCE_VOICE, "Agent interpretation failed.")
		tray_status_label.text = "Voice command failed"
		return

	var payload_variant: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (payload_variant is Dictionary):
		_notify_monitor_error(ALERT_SOURCE_VOICE, "Invalid agent response payload.")
		return

	var payload: Dictionary = payload_variant
	if payload.has("error"):
		var error_payload: Variant = payload.get("error", {})
		var message := "Agent interpretation error"
		if error_payload is Dictionary:
			message = str(error_payload.get("message", message))
		_notify_monitor_error(ALERT_SOURCE_VOICE, message)
		tray_status_label.text = "Voice command failed"
		return

	var status_label := str(payload.get("status", ""))
	var explanation := str(payload.get("explanation", "")).strip_edges()
	var command := str(payload.get("command", "")).strip_edges()
	var output_text := explanation if not explanation.is_empty() else "요청 해석을 완료했습니다."
	if status_label == "interpreted" and not command.is_empty():
		output_text = "%s\n→ %s" % [output_text, command]
		_play_avatar_method("set_mood_happy")
	else:
		_play_avatar_method("set_mood_thinking")

	_show_speech_bubble(output_text)
	_speak_with_tts(explanation if not explanation.is_empty() else "요청 해석이 완료되었습니다.")
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
		if not _idle_brief_error_notified:
			_idle_brief_error_notified = true
			_notify_monitor_error(ALERT_SOURCE_SYSTEM, "Idle briefing disconnected.")
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
		if not _idle_brief_error_notified:
			_idle_brief_error_notified = true
			_notify_monitor_error(ALERT_SOURCE_SYSTEM, "Idle briefing returned an error.")
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
		return _truncate_line(final_summary, 180)

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

	return _truncate_line(" ".join(segments), 180)


func _truncate_line(text: String, max_length: int) -> String:
	var trimmed := text.strip_edges()
	if trimmed.length() <= max_length:
		return trimmed
	return trimmed.substr(0, max_length) + "..."


func _announce_idle_brief(summary: String) -> void:
	var brief_line := "Idle • %s" % summary
	_alert_feed.push_front(brief_line)
	if _alert_feed.size() > 3:
		_alert_feed.resize(3)
	_refresh_alert_cards()
	tray_status_label.text = "Idle briefing delivered"
	_show_speech_bubble(summary)
	_speak_with_tts(summary)
	_play_avatar_method("set_mood_happy")


func _on_calendar_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
) -> void:
	_calendar_request_in_flight = false
	_calendar_request_started_at_ms = 0
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		if not _calendar_error_notified:
			_calendar_error_notified = true
			_notify_monitor_error(ALERT_SOURCE_CALENDAR, "Calendar monitor disconnected.")
		_update_monitor_info_labels()
		return
	_calendar_error_notified = false
	_calendar_timeout_retry_count = 0

	var payload: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (payload is Dictionary):
		return
	var payload_dict: Dictionary = payload
	if payload_dict.has("error"):
		if not _calendar_error_notified:
			_calendar_error_notified = true
			_notify_monitor_error(ALERT_SOURCE_CALENDAR, "Calendar monitor returned an error.")
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
		if not _slack_error_notified:
			_slack_error_notified = true
			_notify_monitor_error(ALERT_SOURCE_SLACK, "Slack monitor disconnected.")
		_update_monitor_info_labels()
		return
	_slack_error_notified = false
	_slack_timeout_retry_count = 0

	var payload: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (payload is Dictionary):
		return
	var payload_dict: Dictionary = payload
	if payload_dict.has("error"):
		if not _slack_error_notified:
			_slack_error_notified = true
			_notify_monitor_error(ALERT_SOURCE_SLACK, "Slack monitor returned an error.")
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
	_show_speech_bubble(message)
	_speak_with_tts("%s alert. %s" % [source, message])
	_play_avatar_method(mood_method)


func _notify_monitor_error(source: String, message: String) -> void:
	_push_alert(source, message, "set_mood_error")


func _refresh_alert_cards() -> void:
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

	alert_card_1_label.text = lines[0]
	alert_card_2_label.text = lines[1]
	alert_card_3_label.text = lines[2]
	_update_monitor_info_labels()


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

	var idle_state := "on" if idle_brief_enabled else "off"
	mini_info_line_1.text = "Monitor: %s (Slack %s / Idle %s) • %s" % [
		monitor_state,
		slack_state,
		idle_state,
		_last_poll_time,
	]
	mini_info_line_3.text = "Pending alerts: %d • Requests: %d" % [
		_unread_alert_count,
		pending_requests,
	]


func _backend_root() -> String:
	return backend_base_url.rstrip("/")


func _show_speech_bubble(text: String) -> void:
	var line := text.strip_edges()
	if line.is_empty():
		return
	speech_label.text = line
	speech_bubble.modulate.a = 1.0
	speech_bubble.visible = true
	if _bubble_tween:
		_bubble_tween.kill()
	_update_speech_bubble_position()
	bubble_timer.start(bubble_visible_sec)


func _update_speech_bubble_position() -> void:
	var bubble_size := speech_bubble.size
	var stage_size := arena_stage.size
	var target := avatar.position + Vector2(-bubble_size.x * 0.5, -228.0)
	target.x = clampf(target.x, 12.0, max(12.0, stage_size.x - bubble_size.x - 12.0))
	target.y = clampf(target.y, 12.0, max(12.0, stage_size.y - bubble_size.y - 12.0))
	speech_bubble.position = target


func _on_bubble_timer_timeout() -> void:
	if not speech_bubble.visible:
		return
	if _bubble_tween:
		_bubble_tween.kill()
	_bubble_tween = create_tween()
	_bubble_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bubble_tween.tween_property(speech_bubble, "modulate:a", 0.0, 0.2)
	_bubble_tween.chain().tween_callback(func():
		speech_bubble.visible = false
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
	_show_speech_bubble(line)
	_speak_with_tts(line)
	if not mood.strip_edges().is_empty():
		play_mood(mood)


func play_mood(mood: String) -> void:
	var normalized := mood.strip_edges().to_lower()
	match normalized:
		"idle":
			_play_avatar_method("set_mood_idle")
		"thinking":
			_play_avatar_method("set_mood_thinking")
		"speaking":
			_play_avatar_method("set_mood_speaking")
		"happy":
			_play_avatar_method("set_mood_happy")
		"surprised":
			_play_avatar_method("set_mood_surprised")
		"sad":
			_play_avatar_method("set_mood_sad")
		"error":
			_play_avatar_method("set_mood_error")
		"angry":
			_play_avatar_method("set_mood_angry")
		"embarrassed":
			_play_avatar_method("set_mood_embarrassed")
		_:
			_play_avatar_method("set_mood_idle")
