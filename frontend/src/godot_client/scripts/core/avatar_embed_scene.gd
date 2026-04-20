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
	"NavHome": "Workspace stable",
	"NavAlerts": "Alert stream focused",
	"NavAgent": "Agent diagnostics active",
	"NavSystem": "System snapshot loaded",
}

const NAV_MOOD := {
	"NavHome": "set_mood_idle",
	"NavAlerts": "set_mood_surprised",
	"NavAgent": "set_mood_thinking",
	"NavSystem": "set_mood_embarrassed",
}

const ALERT_SOURCE_CALENDAR := "Calendar"
const ALERT_SOURCE_SLACK := "Slack"
const ALERT_SOURCE_SYSTEM := "System"

@export var backend_base_url := "http://127.0.0.1:8000"
@export var calendar_id := "primary"
@export var slack_channel_id := ""
@export_range(10.0, 600.0, 1.0) var monitor_interval_sec := 45.0
@export_range(1, 168, 1) var slack_lookback_hours := 24
@export var tts_enabled := true
@export var tts_voice_id := ""
@export_range(1.0, 12.0, 0.1) var bubble_visible_sec := 4.0

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
@onready var alert_card_1_label: Label = $MainLayout/RootVBox/TopRow/RightSidebar/SidebarMargin/SidebarStack/SidebarContent/AlertCard1/AlertCard1Margin/AlertCard1Label
@onready var alert_card_2_label: Label = $MainLayout/RootVBox/TopRow/RightSidebar/SidebarMargin/SidebarStack/SidebarContent/AlertCard2/AlertCard2Margin/AlertCard2Label
@onready var alert_card_3_label: Label = $MainLayout/RootVBox/TopRow/RightSidebar/SidebarMargin/SidebarStack/SidebarContent/AlertCard3/AlertCard3Margin/AlertCard3Label
@onready var mini_info_line_1: Label = $MainLayout/RootVBox/TopRow/RightSidebar/SidebarMargin/SidebarStack/SidebarContent/MiniInfoCard/MiniInfoMargin/MiniInfoVBox/MiniInfoLine1
@onready var mini_info_line_2: Label = $MainLayout/RootVBox/TopRow/RightSidebar/SidebarMargin/SidebarStack/SidebarContent/MiniInfoCard/MiniInfoMargin/MiniInfoVBox/MiniInfoLine2
@onready var mini_info_line_3: Label = $MainLayout/RootVBox/TopRow/RightSidebar/SidebarMargin/SidebarStack/SidebarContent/MiniInfoCard/MiniInfoMargin/MiniInfoVBox/MiniInfoLine3
@onready var tray_status_label: Label = $MainLayout/RootVBox/TrayBar/TrayMargin/TrayRow/TrayStatusLabel
@onready var tray_sidebar_button: Button = $MainLayout/RootVBox/TrayBar/TrayMargin/TrayRow/TraySidebarToggleButton
@onready var tray_roam_button: Button = $MainLayout/RootVBox/TrayBar/TrayMargin/TrayRow/TrayRoamToggleButton
@onready var tray_mood_button: Button = $MainLayout/RootVBox/TrayBar/TrayMargin/TrayRow/TrayMoodButton
@onready var tray_monitor_button: Button = $MainLayout/RootVBox/TrayBar/TrayMargin/TrayRow/TrayMonitorToggleButton
@onready var clock_label: Label = $MainLayout/RootVBox/TrayBar/TrayMargin/TrayRow/ClockLabel
@onready var mood_timer: Timer = $MoodTimer
@onready var clock_timer: Timer = $ClockTimer
@onready var poll_timer: Timer = $PollTimer
@onready var bubble_timer: Timer = $BubbleTimer
@onready var calendar_request: HTTPRequest = $CalendarRequest
@onready var slack_request: HTTPRequest = $SlackRequest

@onready var nav_buttons: Array[Button] = [nav_home, nav_alerts, nav_agent, nav_system]

var _rng := RandomNumberGenerator.new()
var _roam_tween: Tween
var _indicator_tween: Tween
var _sidebar_tween: Tween
var _mood_index := 0
var _roam_enabled := true
var _monitor_enabled := true
var _sidebar_expanded := true
var _arena_rect := Rect2()
var _calendar_signature := ""
var _slack_signature := ""
var _calendar_request_in_flight := false
var _slack_request_in_flight := false
var _calendar_error_notified := false
var _slack_error_notified := false
var _alert_feed: Array[String] = []
var _unread_alert_count := 0
var _last_poll_time := "--:--"
var _status_indicator_id := -1
var _status_indicator_supported := false
var _status_icon_normal: Texture2D
var _status_icon_alert: Texture2D
var _bubble_tween: Tween
var _tts_available := false


func _ready() -> void:
	_rng.randomize()
	resized.connect(_on_resized)
	mood_timer.timeout.connect(_on_mood_timer_timeout)
	clock_timer.timeout.connect(_update_clock)
	poll_timer.timeout.connect(_on_poll_timer_timeout)
	bubble_timer.timeout.connect(_on_bubble_timer_timeout)
	calendar_request.request_completed.connect(_on_calendar_request_completed)
	slack_request.request_completed.connect(_on_slack_request_completed)

	tray_sidebar_button.pressed.connect(_toggle_sidebar)
	tray_roam_button.pressed.connect(_toggle_roam)
	tray_mood_button.pressed.connect(_step_mood)
	tray_monitor_button.pressed.connect(_toggle_monitoring)
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
	tray_status_label.text = String(NAV_STATUS.get(nav_name, "Workspace stable"))
	var mood_method := String(NAV_MOOD.get(nav_name, "set_mood_idle"))
	_play_avatar_method(mood_method)
	if nav_name == "NavAlerts":
		_set_sidebar_expanded(true)
		_clear_unread_alerts()


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


func _toggle_monitoring() -> void:
	_monitor_enabled = not _monitor_enabled
	if _monitor_enabled:
		tray_monitor_button.text = "Pause Monitor"
		tray_status_label.text = "Monitoring active"
		poll_timer.start()
		_poll_backend_now()
	else:
		tray_monitor_button.text = "Resume Monitor"
		tray_status_label.text = "Monitoring paused"
		poll_timer.stop()
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


func _on_calendar_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
) -> void:
	_calendar_request_in_flight = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		if not _calendar_error_notified:
			_calendar_error_notified = true
			_notify_monitor_error(ALERT_SOURCE_CALENDAR, "Calendar monitor disconnected.")
		return
	_calendar_error_notified = false

	var payload: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (payload is Dictionary):
		return
	var payload_dict: Dictionary = payload
	if payload_dict.has("error"):
		if not _calendar_error_notified:
			_calendar_error_notified = true
			_notify_monitor_error(ALERT_SOURCE_CALENDAR, "Calendar monitor returned an error.")
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


func _on_slack_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
) -> void:
	_slack_request_in_flight = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		if not _slack_error_notified:
			_slack_error_notified = true
			_notify_monitor_error(ALERT_SOURCE_SLACK, "Slack monitor disconnected.")
		return
	_slack_error_notified = false

	var payload: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (payload is Dictionary):
		return
	var payload_dict: Dictionary = payload
	if payload_dict.has("error"):
		if not _slack_error_notified:
			_slack_error_notified = true
			_notify_monitor_error(ALERT_SOURCE_SLACK, "Slack monitor returned an error.")
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
	mini_info_line_1.text = "Monitor: %s (Slack %s) • %s" % [
		monitor_state,
		slack_state,
		_last_poll_time,
	]
	mini_info_line_3.text = "Pending alerts: %d" % _unread_alert_count


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
