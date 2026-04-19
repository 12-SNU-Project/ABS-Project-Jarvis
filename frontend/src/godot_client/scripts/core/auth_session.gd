class_name JarvisAuthSession
extends Node

signal session_changed(is_authenticated: bool)

var access_token := ""
var refresh_token := ""
var id_token := ""
var token_type := "Bearer"
var scope := ""
var expires_at_unix := 0
var profile: Dictionary = {}


func set_session(tokens: Dictionary, user_profile: Dictionary) -> void:
	access_token = String(tokens.get("access_token", ""))
	refresh_token = String(tokens.get("refresh_token", ""))
	id_token = String(tokens.get("id_token", ""))
	token_type = String(tokens.get("token_type", "Bearer"))
	scope = String(tokens.get("scope", ""))

	var expires_in = int(tokens.get("expires_in", 0))
	expires_at_unix = Time.get_unix_time_from_system() + max(expires_in, 0)
	profile = user_profile.duplicate(true)

	session_changed.emit(is_authenticated())


func clear_session() -> void:
	access_token = ""
	refresh_token = ""
	id_token = ""
	token_type = "Bearer"
	scope = ""
	expires_at_unix = 0
	profile.clear()

	session_changed.emit(false)


func is_authenticated() -> bool:
	return not access_token.is_empty() and not profile.is_empty()


func has_valid_access_token() -> bool:
	if access_token.is_empty():
		return false
	if expires_at_unix <= 0:
		return true
	return Time.get_unix_time_from_system() < expires_at_unix


func get_display_name() -> String:
	var full_name := String(profile.get("name", "")).strip_edges()
	if not full_name.is_empty():
		return full_name

	var given_name := String(profile.get("given_name", "")).strip_edges()
	if not given_name.is_empty():
		return given_name

	return get_email()


func get_email() -> String:
	return String(profile.get("email", "")).strip_edges()


func get_avatar_url() -> String:
	return String(profile.get("picture", "")).strip_edges()
