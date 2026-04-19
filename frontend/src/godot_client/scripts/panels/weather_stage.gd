extends Control

var _time := 0.0
var _condition := "sunny"
var _temperature_c := 17.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func set_weather(condition: String, temperature_c: float) -> void:
	_condition = condition.strip_edges().to_lower()
	_temperature_c = temperature_c
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var rect := Rect2(Vector2.ZERO, size)
	match _resolve_mode():
		"sunny":
			_draw_sunny(rect)
		"cloud":
			_draw_cloudy(rect)
		"rain":
			_draw_rain(rect, false)
		"storm":
			_draw_rain(rect, true)
		"snow":
			_draw_snow(rect)
		_:
			_draw_wind(rect)

	_draw_surface_glow(rect)
	_draw_temperature_band(rect)


func _resolve_mode() -> String:
	if _contains_any(_condition, ["sun", "clear"]):
		return "sunny"
	if _contains_any(_condition, ["storm", "thunder"]):
		return "storm"
	if _contains_any(_condition, ["rain", "drizzle", "shower"]):
		return "rain"
	if _contains_any(_condition, ["snow", "sleet", "hail"]):
		return "snow"
	if _contains_any(_condition, ["cloud", "overcast", "fog", "mist"]):
		return "cloud"
	return "wind"


func _contains_any(text: String, tokens: Array) -> bool:
	for token in tokens:
		if text.contains(String(token)):
			return true
	return false


func _draw_sunny(rect: Rect2) -> void:
	var base := Color(0.11, 0.21, 0.34, 1.0)
	draw_rect(rect, base)
	draw_circle(Vector2(rect.size.x * 0.18, rect.size.y * 0.18), rect.size.x * 0.42, Color(0.18, 0.42, 0.62, 0.45))
	draw_circle(Vector2(rect.size.x * 0.82, rect.size.y * 0.82), rect.size.x * 0.5, Color(0.02, 0.08, 0.16, 0.32))

	var sun_center := Vector2(rect.size.x * 0.72, rect.size.y * 0.3)
	var pulse := 1.0 + sin(_time * 1.8) * 0.08
	draw_circle(sun_center, 78.0 * pulse, Color(1.0, 0.85, 0.4, 0.18))
	draw_circle(sun_center, 52.0, Color(1.0, 0.78, 0.32, 1.0))

	for i in range(12):
		var angle := (TAU / 12.0) * i + _time * 0.35
		var inner := sun_center + Vector2.from_angle(angle) * 66.0
		var outer := sun_center + Vector2.from_angle(angle) * (92.0 + sin(_time * 2.2 + i) * 8.0)
		draw_line(inner, outer, Color(1.0, 0.88, 0.56, 0.92), 4.0, true)

	for i in range(7):
		var x := fmod(rect.size.x * 0.14 + i * 78.0 + _time * 42.0, rect.size.x + 90.0) - 40.0
		var y := rect.size.y * 0.72 + sin(_time * 1.4 + i) * 18.0
		draw_line(
			Vector2(x, y),
			Vector2(x + 42.0, y - 18.0),
			Color(0.84, 0.97, 1.0, 0.24),
			3.0,
			true
		)


func _draw_cloudy(rect: Rect2) -> void:
	draw_rect(rect, Color(0.08, 0.14, 0.22, 1.0))
	draw_circle(Vector2(rect.size.x * 0.2, rect.size.y * 0.15), rect.size.x * 0.4, Color(0.2, 0.32, 0.48, 0.28))
	draw_circle(Vector2(rect.size.x * 0.84, rect.size.y * 0.78), rect.size.x * 0.52, Color(0.03, 0.07, 0.12, 0.34))

	_draw_cloud(Vector2(rect.size.x * 0.34 + sin(_time * 0.32) * 12.0, rect.size.y * 0.34), 1.05, Color(0.77, 0.86, 0.96, 0.92), Color(0.44, 0.6, 0.76, 0.18))
	_draw_cloud(Vector2(rect.size.x * 0.68 + cos(_time * 0.28) * 15.0, rect.size.y * 0.52), 1.28, Color(0.67, 0.78, 0.9, 0.96), Color(0.28, 0.42, 0.58, 0.18))
	_draw_cloud(Vector2(rect.size.x * 0.52 + sin(_time * 0.4) * 18.0, rect.size.y * 0.7), 0.94, Color(0.84, 0.9, 0.98, 0.84), Color(0.26, 0.36, 0.5, 0.14))

	for i in range(5):
		var start := Vector2(-40.0 + fmod(_time * 36.0 + i * 92.0, rect.size.x + 80.0), rect.size.y * 0.2 + i * 42.0)
		var points := PackedVector2Array([
			start,
			start + Vector2(34.0, -4.0),
			start + Vector2(58.0, 6.0),
			start + Vector2(92.0, 0.0)
		])
		draw_polyline(points, Color(0.74, 0.87, 0.98, 0.18), 3.0, true)


func _draw_rain(rect: Rect2, storm: bool) -> void:
	var base := Color(0.05, 0.1, 0.18, 1.0)
	if storm:
		base = Color(0.04, 0.07, 0.14, 1.0)
	draw_rect(rect, base)
	draw_circle(Vector2(rect.size.x * 0.2, rect.size.y * 0.18), rect.size.x * 0.36, Color(0.2, 0.3, 0.52, 0.16))
	draw_circle(Vector2(rect.size.x * 0.82, rect.size.y * 0.82), rect.size.x * 0.54, Color(0.02, 0.05, 0.1, 0.32))

	_draw_cloud(Vector2(rect.size.x * 0.35, rect.size.y * 0.28), 1.18, Color(0.34, 0.44, 0.58, 0.96), Color(0.18, 0.24, 0.34, 0.22))
	_draw_cloud(Vector2(rect.size.x * 0.68, rect.size.y * 0.38), 1.34, Color(0.26, 0.34, 0.46, 0.98), Color(0.14, 0.18, 0.28, 0.22))

	for i in range(24):
		var x := fmod(i * 28.0 + _time * 220.0, rect.size.x + 50.0) - 18.0
		var y := fmod(i * 14.0 + _time * 136.0, rect.size.y + 80.0) - 32.0
		var start := Vector2(x, y)
		var end := start + Vector2(-12.0, 34.0)
		draw_line(start, end, Color(0.58, 0.84, 1.0, 0.72), 2.4, true)

	for i in range(10):
		var ripple_x := fmod(i * 64.0 + _time * 64.0, rect.size.x + 60.0) - 20.0
		var ripple_y := rect.size.y * 0.8 + sin(_time * 2.0 + i) * 10.0
		draw_arc(Vector2(ripple_x, ripple_y), 14.0, 0.2, PI - 0.2, 18, Color(0.66, 0.9, 1.0, 0.24), 2.0, true)

	if storm:
		var lightning := PackedVector2Array([
			Vector2(rect.size.x * 0.66, rect.size.y * 0.14),
			Vector2(rect.size.x * 0.58, rect.size.y * 0.34),
			Vector2(rect.size.x * 0.68, rect.size.y * 0.34),
			Vector2(rect.size.x * 0.54, rect.size.y * 0.62),
			Vector2(rect.size.x * 0.66, rect.size.y * 0.44),
			Vector2(rect.size.x * 0.58, rect.size.y * 0.44)
		])
		draw_polyline(lightning, Color(1.0, 0.9, 0.55, 0.95), 6.0, true)


func _draw_snow(rect: Rect2) -> void:
	draw_rect(rect, Color(0.14, 0.2, 0.28, 1.0))
	draw_circle(Vector2(rect.size.x * 0.24, rect.size.y * 0.16), rect.size.x * 0.42, Color(0.32, 0.46, 0.62, 0.22))
	_draw_cloud(Vector2(rect.size.x * 0.4, rect.size.y * 0.3), 1.18, Color(0.74, 0.84, 0.93, 0.92), Color(0.36, 0.48, 0.62, 0.18))
	_draw_cloud(Vector2(rect.size.x * 0.68, rect.size.y * 0.48), 1.08, Color(0.84, 0.92, 1.0, 0.84), Color(0.34, 0.44, 0.6, 0.12))

	for i in range(28):
		var x := fmod(i * 32.0 + _time * 34.0 + sin(_time + i) * 10.0, rect.size.x + 44.0) - 18.0
		var y := fmod(i * 22.0 + _time * 58.0, rect.size.y + 80.0) - 20.0
		var radius := 1.8 + fmod(float(i), 3.0)
		draw_circle(Vector2(x, y), radius, Color(0.92, 0.98, 1.0, 0.88))


func _draw_wind(rect: Rect2) -> void:
	draw_rect(rect, Color(0.08, 0.15, 0.24, 1.0))
	draw_circle(Vector2(rect.size.x * 0.2, rect.size.y * 0.22), rect.size.x * 0.36, Color(0.18, 0.34, 0.56, 0.18))
	draw_circle(Vector2(rect.size.x * 0.82, rect.size.y * 0.74), rect.size.x * 0.5, Color(0.03, 0.06, 0.12, 0.28))

	for i in range(8):
		var start := Vector2(-90.0 + fmod(_time * 120.0 + i * 82.0, rect.size.x + 180.0), rect.size.y * 0.22 + i * 34.0)
		var points := PackedVector2Array([
			start,
			start + Vector2(48.0, -10.0),
			start + Vector2(92.0, 8.0),
			start + Vector2(142.0, -2.0)
		])
		draw_polyline(points, Color(0.7, 0.92, 1.0, 0.42), 4.0, true)

	_draw_cloud(Vector2(rect.size.x * 0.66, rect.size.y * 0.42 + sin(_time * 0.5) * 8.0), 0.92, Color(0.72, 0.84, 0.96, 0.88), Color(0.3, 0.42, 0.58, 0.14))


func _draw_cloud(center: Vector2, cloud_scale: float, color: Color, glow: Color) -> void:
	draw_circle(center + Vector2(-56.0, 14.0) * cloud_scale, 30.0 * cloud_scale, glow)
	draw_circle(center + Vector2(0.0, 0.0) * cloud_scale, 42.0 * cloud_scale, glow)
	draw_circle(center + Vector2(56.0, 18.0) * cloud_scale, 28.0 * cloud_scale, glow)

	draw_circle(center + Vector2(-48.0, 8.0) * cloud_scale, 28.0 * cloud_scale, color)
	draw_circle(center + Vector2(0.0, -10.0) * cloud_scale, 42.0 * cloud_scale, color)
	draw_circle(center + Vector2(54.0, 12.0) * cloud_scale, 26.0 * cloud_scale, color)
	draw_rect(Rect2(center + Vector2(-74.0, 10.0) * cloud_scale, Vector2(148.0, 38.0) * cloud_scale), color)


func _draw_surface_glow(rect: Rect2) -> void:
	draw_rect(Rect2(0.0, rect.size.y * 0.74, rect.size.x, rect.size.y * 0.26), Color(0.02, 0.08, 0.16, 0.18))
	draw_line(
		Vector2(rect.size.x * 0.08, rect.size.y * 0.82),
		Vector2(rect.size.x * 0.92, rect.size.y * 0.82),
		Color(0.58, 0.88, 1.0, 0.18),
		3.0,
		true
	)


func _draw_temperature_band(rect: Rect2) -> void:
	var normalized: float = clamp((_temperature_c + 10.0) / 40.0, 0.0, 1.0)
	var band_width: float = rect.size.x * (0.28 + normalized * 0.5)
	var band_color := Color(0.48, 0.92, 1.0, 0.32)
	if _temperature_c >= 24.0:
		band_color = Color(1.0, 0.72, 0.34, 0.32)
	elif _temperature_c <= 4.0:
		band_color = Color(0.74, 0.9, 1.0, 0.36)

	var start := Vector2(rect.size.x * 0.12, rect.size.y * 0.9)
	var end := start + Vector2(band_width + sin(_time * 1.8) * 12.0, 0.0)
	draw_line(start, end, band_color, 8.0, true)
	draw_circle(end, 10.0, Color(band_color.r, band_color.g, band_color.b, 0.8))
