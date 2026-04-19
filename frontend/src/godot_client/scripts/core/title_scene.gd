extends Control

const MAIN_SCENE = "res://scenes/core/main_scene.tscn"
const GOOGLE_AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"
const GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token"
const GOOGLE_USERINFO_URL = "https://openidconnect.googleapis.com/v1/userinfo"
const CALLBACK_PATH = "/oauth2/callback"
const AUTH_TIMEOUT_SEC = 180.0

const GOOGLE_SCOPES = [
	"openid",
	"email",
	"profile",
]

@onready var avatar: Node2D = $Margin/LayoutShell/ShellMargin/HBox/HeroPanel/HeroContent/HeroVBox/AvatarWrap/AvatarArea
@onready var sign_in_btn: Button = $Margin/LayoutShell/ShellMargin/HBox/SignInPanel/CardMargin/CardVBox/SignInBtn
@onready var status_label: Label = $Margin/LayoutShell/ShellMargin/HBox/SignInPanel/CardMargin/CardVBox/StatusLabel
@onready var client_hint_label: Label = $Margin/LayoutShell/ShellMargin/HBox/SignInPanel/CardMargin/CardVBox/ClientHint
@onready var identity_card: PanelContainer = $Margin/LayoutShell/ShellMargin/HBox/SignInPanel/CardMargin/CardVBox/IdentityCard
@onready var identity_name: Label = $Margin/LayoutShell/ShellMargin/HBox/SignInPanel/CardMargin/CardVBox/IdentityCard/IdentityMargin/IdentityVBox/IdentityName
@onready var identity_email: Label = $Margin/LayoutShell/ShellMargin/HBox/SignInPanel/CardMargin/CardVBox/IdentityCard/IdentityMargin/IdentityVBox/IdentityEmail

var _auth_session
var _token_request: HTTPRequest
var _userinfo_request: HTTPRequest
var _server := TCPServer.new()
var _pending_peer: StreamPeerTCP
var _pending_request_buffer := ""
var _auth_started_at_msec := 0
var _auth_state := ""
var _code_verifier := ""
var _redirect_uri := ""
var _callback_host := "127.0.0.1"
var _callback_port := 0
var _oauth_token_payload: Dictionary = {}
var _is_auth_in_progress := false
var _float_tween: Tween


func _ready() -> void:
	_auth_session = get_node_or_null("/root/AuthSession")

	_create_http_requests()
	sign_in_btn.pressed.connect(_on_sign_in_pressed)
	sign_in_btn.pivot_offset = sign_in_btn.size / 2.0
	identity_card.visible = false

	_start_float_anim()
	_refresh_config_state()

	if _auth_session and _auth_session.is_authenticated():
		_show_identity(_auth_session.profile)
		status_label.text = "Signed in as %s" % _auth_session.get_email()


func _process(_delta: float) -> void:
	if not _is_auth_in_progress:
		return

	if _server.is_listening() and Time.get_ticks_msec() - _auth_started_at_msec > int(AUTH_TIMEOUT_SEC * 1000.0):
		_finish_auth_with_error("Google sign-in timed out. Try again.")
		return

	if _pending_peer == null and _server.is_connection_available():
		_pending_peer = _server.take_connection()
		if _pending_peer:
			_pending_peer.set_no_delay(true)

	if _pending_peer == null:
		return

	_pending_peer.poll()
	var available_bytes := _pending_peer.get_available_bytes()
	if available_bytes <= 0:
		return

	var packet = _pending_peer.get_data(available_bytes)
	if packet[0] != OK:
		_finish_auth_with_error("Could not read the browser callback.")
		return

	_pending_request_buffer += packet[1].get_string_from_utf8()
	if _pending_request_buffer.find("\r\n\r\n") == -1 and _pending_request_buffer.find("\n\n") == -1:
		return

	_handle_callback_request(_pending_request_buffer)
	_pending_request_buffer = ""


func _exit_tree() -> void:
	if _server.is_listening():
		_server.stop()

	if _pending_peer:
		_pending_peer.disconnect_from_host()


func _create_http_requests() -> void:
	_token_request = HTTPRequest.new()
	_token_request.name = "TokenRequest"
	_token_request.timeout = 15.0
	_token_request.request_completed.connect(_on_token_request_completed)
	add_child(_token_request)

	_userinfo_request = HTTPRequest.new()
	_userinfo_request.name = "UserinfoRequest"
	_userinfo_request.timeout = 15.0
	_userinfo_request.request_completed.connect(_on_userinfo_request_completed)
	add_child(_userinfo_request)


func _refresh_config_state() -> void:
	var client_id := _get_google_client_id()
	if client_id.is_empty():
		sign_in_btn.disabled = true
		client_hint_label.visible = true
		client_hint_label.text = "Set GOOGLE_CLIENT_ID or jarvis/auth/google_client_id to enable Google OAuth."
		status_label.text = "Google OAuth is not configured yet."
		return

	sign_in_btn.disabled = false
	client_hint_label.visible = false
	status_label.text = "Use your Google Account to continue to Jarvis."


func _start_float_anim() -> void:
	_float_tween = create_tween().set_loops()
	_float_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_float_tween.tween_property(avatar, "position:y", avatar.position.y - 12.0, 1.4)
	_float_tween.tween_property(avatar, "position:y", avatar.position.y, 1.4)


func _on_sign_in_pressed() -> void:
	if _is_auth_in_progress:
		return

	var client_id := _get_google_client_id()
	if client_id.is_empty():
		_refresh_config_state()
		return

	_bounce_sign_in_button()
	_begin_oauth_sign_in(client_id)


func _bounce_sign_in_button() -> void:
	var tw = create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(sign_in_btn, "scale", Vector2(0.97, 0.97), 0.08)
	tw.chain().tween_property(sign_in_btn, "scale", Vector2.ONE, 0.18)


func _begin_oauth_sign_in(client_id: String) -> void:
	_callback_host = _get_project_or_env("jarvis/auth/oauth_callback_host", "GOOGLE_CALLBACK_HOST", "127.0.0.1")
	var base_port := int(_get_project_or_env("jarvis/auth/oauth_callback_port", "GOOGLE_CALLBACK_PORT", "8756"))
	_callback_port = _listen_for_callback(base_port)

	if _callback_port <= 0:
		_finish_auth_with_error("Could not open a local callback port for Google sign-in.")
		return

	_code_verifier = _generate_random_urlsafe(48)
	_auth_state = _generate_random_urlsafe(24)
	_redirect_uri = "http://%s:%d%s" % [_callback_host, _callback_port, CALLBACK_PATH]
	_auth_started_at_msec = Time.get_ticks_msec()
	_is_auth_in_progress = true

	sign_in_btn.disabled = true
	status_label.text = "Opening the Google sign-in page in your browser…"

	var auth_url = _build_google_auth_url(client_id)
	var open_err := OS.shell_open(auth_url)
	if open_err != OK:
		_finish_auth_with_error("Could not open the Google sign-in page.")


func _listen_for_callback(base_port: int) -> int:
	if _server.is_listening():
		_server.stop()

	for offset in range(12):
		var port := base_port + offset
		var err := _server.listen(port, _callback_host)
		if err == OK:
			return port

	return -1


func _build_google_auth_url(client_id: String) -> String:
	var params := {
		"client_id": client_id,
		"redirect_uri": _redirect_uri,
		"response_type": "code",
		"scope": " ".join(GOOGLE_SCOPES),
		"state": _auth_state,
		"code_challenge": _build_code_challenge(_code_verifier),
		"code_challenge_method": "S256",
		"access_type": "offline",
		"prompt": "select_account",
	}
	return "%s?%s" % [GOOGLE_AUTH_URL, _form_encode(params)]


func _handle_callback_request(raw_request: String) -> void:
	var first_line := raw_request.get_slice("\r\n", 0)
	if first_line.is_empty():
		first_line = raw_request.get_slice("\n", 0)

	var parts := first_line.split(" ", false)
	if parts.size() < 2:
		_write_callback_response(400, "Invalid request.")
		_finish_auth_with_error("Google returned an invalid callback.")
		return

	var target := parts[1]
	var path := target
	var query := ""
	var query_index := target.find("?")
	if query_index >= 0:
		path = target.substr(0, query_index)
		query = target.substr(query_index + 1)

	var params := _parse_query_params(query)
	if path != CALLBACK_PATH:
		_write_callback_response(404, "Unknown callback path.")
		_finish_auth_with_error("Google returned to an unexpected callback path.")
		return

	if params.has("error"):
		_write_callback_response(200, "Google sign-in was cancelled. You can close this tab.")
		_finish_auth_with_error("Google sign-in was cancelled: %s" % String(params["error"]))
		return

	if String(params.get("state", "")) != _auth_state:
		_write_callback_response(200, "State validation failed. Return to the app and try again.")
		_finish_auth_with_error("State validation failed for the Google callback.")
		return

	var code := String(params.get("code", "")).strip_edges()
	if code.is_empty():
		_write_callback_response(200, "No authorization code was returned. Return to the app and try again.")
		_finish_auth_with_error("Google did not return an authorization code.")
		return

	_write_callback_response(200, "Google sign-in completed. You can close this tab and return to Jarvis.")
	_exchange_code_for_tokens(code)


func _exchange_code_for_tokens(code: String) -> void:
	status_label.text = "Completing Google sign-in…"

	var body_params := {
		"client_id": _get_google_client_id(),
		"code": code,
		"code_verifier": _code_verifier,
		"grant_type": "authorization_code",
		"redirect_uri": _redirect_uri,
	}

	var client_secret := _get_google_client_secret()
	if not client_secret.is_empty():
		body_params["client_secret"] = client_secret

	var err := _token_request.request(
		GOOGLE_TOKEN_URL,
		["Content-Type: application/x-www-form-urlencoded"],
		HTTPClient.METHOD_POST,
		_form_encode(body_params)
	)

	if err != OK:
		_finish_auth_with_error("Could not request Google access tokens.")


func _on_token_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_finish_auth_with_error("Google token exchange failed.")
		return

	if response_code < 200 or response_code >= 300:
		_finish_auth_with_error(_extract_oauth_error(body, "Google token exchange was rejected."))
		return

	var payload := _parse_json_body(body)
	if payload.is_empty():
		_finish_auth_with_error("Google token exchange returned invalid JSON.")
		return

	var access_token := String(payload.get("access_token", "")).strip_edges()
	if access_token.is_empty():
		_finish_auth_with_error("Google did not return an access token.")
		return

	_oauth_token_payload = payload

	var err := _userinfo_request.request(
		GOOGLE_USERINFO_URL,
		["Authorization: Bearer %s" % access_token]
	)
	if err != OK:
		_finish_auth_with_error("Could not fetch the Google account profile.")


func _on_userinfo_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_finish_auth_with_error("Google profile lookup failed.")
		return

	if response_code < 200 or response_code >= 300:
		_finish_auth_with_error(_extract_oauth_error(body, "Google profile lookup was rejected."))
		return

	var profile := _parse_json_body(body)
	if profile.is_empty():
		_finish_auth_with_error("Google profile lookup returned invalid JSON.")
		return

	if _auth_session:
		_auth_session.set_session(_oauth_token_payload, profile)

	_show_identity(profile)
	status_label.text = "Signed in as %s" % String(profile.get("email", "your Google account"))
	sign_in_btn.text = "Continue to Jarvis"
	sign_in_btn.disabled = true

	_cleanup_oauth_server()

	await get_tree().create_timer(0.8).timeout

	var change_err := get_tree().change_scene_to_file(MAIN_SCENE)
	if change_err != OK:
		_finish_auth_with_error("Sign-in worked, but the main scene could not be opened.")


func _show_identity(profile: Dictionary) -> void:
	identity_card.visible = true
	identity_name.text = String(profile.get("name", "Google Account"))
	identity_email.text = String(profile.get("email", ""))


func _finish_auth_with_error(message: String) -> void:
	_cleanup_oauth_server()
	_oauth_token_payload.clear()
	_code_verifier = ""
	_auth_state = ""
	status_label.text = message
	sign_in_btn.disabled = _get_google_client_id().is_empty()
	sign_in_btn.text = "Sign in with Google"


func _cleanup_oauth_server() -> void:
	_is_auth_in_progress = false
	_pending_request_buffer = ""

	if _pending_peer:
		_pending_peer.disconnect_from_host()
		_pending_peer = null

	if _server.is_listening():
		_server.stop()


func _write_callback_response(status_code: int, message: String) -> void:
	if _pending_peer == null:
		return

	var reason := "OK"
	if status_code == 400:
		reason = "Bad Request"
	elif status_code == 404:
		reason = "Not Found"

	var body := (
		"<html><head><meta charset=\"utf-8\"><title>Jarvis</title></head>"
		+ "<body style=\"font-family:Arial,sans-serif;background:#f8fafc;color:#202124;padding:32px;\">"
		+ "<div style=\"max-width:480px;margin:0 auto;background:#fff;border:1px solid #dadce0;border-radius:20px;padding:24px;\">"
		+ "<h2 style=\"margin:0 0 12px 0;\">Jarvis</h2>"
		+ "<p style=\"margin:0;font-size:15px;line-height:1.5;\">%s</p>"
		+ "</div></body></html>"
	) % message.xml_escape()

	var response := (
		"HTTP/1.1 %d %s\r\n" % [status_code, reason]
		+ "Content-Type: text/html; charset=utf-8\r\n"
		+ "Content-Length: %d\r\n" % body.to_utf8_buffer().size()
		+ "Connection: close\r\n\r\n"
		+ body
	)

	_pending_peer.put_data(response.to_utf8_buffer())


func _parse_query_params(query: String) -> Dictionary:
	var params := {}
	if query.is_empty():
		return params

	for pair in query.split("&", false):
		if pair.is_empty():
			continue
		var divider := pair.find("=")
		if divider == -1:
			params[pair.uri_decode()] = ""
			continue

		var key := pair.substr(0, divider).uri_decode()
		var value := pair.substr(divider + 1).replace("+", " ").uri_decode()
		params[key] = value

	return params


func _parse_json_body(body: PackedByteArray) -> Dictionary:
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		return {}

	var data = json.get_data()
	if data is Dictionary:
		return data
	return {}


func _extract_oauth_error(body: PackedByteArray, fallback: String) -> String:
	var payload := _parse_json_body(body)
	if payload.is_empty():
		return fallback

	if payload.has("error_description"):
		return String(payload["error_description"])
	if payload.has("error"):
		return String(payload["error"])
	return fallback


func _build_code_challenge(verifier: String) -> String:
	var hashing_context := HashingContext.new()
	hashing_context.start(HashingContext.HASH_SHA256)
	hashing_context.update(verifier.to_utf8_buffer())
	return _base64_url_encode(hashing_context.finish())


func _generate_random_urlsafe(byte_count: int) -> String:
	var crypto := Crypto.new()
	return _base64_url_encode(crypto.generate_random_bytes(byte_count))


func _base64_url_encode(bytes: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(bytes).replace("+", "-").replace("/", "_").replace("=", "")


func _form_encode(params: Dictionary) -> String:
	var pairs: Array[String] = []
	for key in params.keys():
		var encoded_key := String(key).uri_encode()
		var encoded_value := String(params[key]).uri_encode()
		pairs.append("%s=%s" % [encoded_key, encoded_value])
	return "&".join(pairs)


func _get_google_client_id() -> String:
	return _get_project_or_env("jarvis/auth/google_client_id", "GOOGLE_CLIENT_ID", "")


func _get_google_client_secret() -> String:
	return _get_project_or_env("jarvis/auth/google_client_secret", "GOOGLE_CLIENT_SECRET", "")


func _get_project_or_env(setting_path: String, env_name: String, fallback: String) -> String:
	var project_value = String(ProjectSettings.get_setting(setting_path, "")).strip_edges()
	if not project_value.is_empty():
		return project_value

	var env_value := OS.get_environment(env_name).strip_edges()
	if not env_value.is_empty():
		return env_value

	return fallback
