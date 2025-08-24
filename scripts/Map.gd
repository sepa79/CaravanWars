extends Control
signal location_clicked(loc_code: String)

@export var show_grid: bool = true

# Rozmiar obrazu bazowego mapy (piksele)
const IMG_SIZE: Vector2i = Vector2i(1536, 1024)

var scale_val: float = 1.0
var offset: Vector2 = Vector2.ZERO
var player_blink: float = 0.0
var hover_loc: String = ""
var hover_scale: float = 1.0
var _hover_tween: Tween = null

func _ready() -> void:
		mouse_filter = MOUSE_FILTER_STOP
		_update_layout()
		resized.connect(_on_resized)
		set_process(true)
		var blink := create_tween()
		blink.set_loops(0)	# nieskończona pulsacja
		blink.tween_property(self, "player_blink", 1.0, 0.5)
		blink.tween_property(self, "player_blink", 0.0, 0.5)
		queue_redraw()

func _on_resized() -> void:
	_update_layout()
	queue_redraw()

func _update_layout() -> void:
	var panel_size: Vector2 = size
	scale_val = min(
		panel_size.x / float(IMG_SIZE.x),
		panel_size.y / float(IMG_SIZE.y)
	)
	var disp_size: Vector2 = Vector2(IMG_SIZE) * scale_val
	offset = (panel_size - disp_size) * 0.5

func _to_screen(p_img: Vector2) -> Vector2:
	return offset + p_img * scale_val

func _to_image(p_screen: Vector2) -> Vector2:
	var s: float = max(scale_val, 0.00001)
	return (p_screen - offset) / s

func _draw() -> void:
	# Ustaw transform tak, aby rysować w układzie współrzędnych obrazu (1536x1024)
	draw_set_transform(offset, 0.0, Vector2(scale_val, scale_val))
	if show_grid:
		_draw_grid()
		_draw_routes()
		_draw_locations()
		_draw_caravans()
		_draw_players()

func _draw_grid() -> void:
	var step: int = 128
	var c: Color = Color(0.1, 0.1, 0.1, 0.5)
	for x in range(0, IMG_SIZE.x + 1, step):
		draw_line(Vector2(x, 0), Vector2(x, IMG_SIZE.y), c, 1.0)
	for y in range(0, IMG_SIZE.y + 1, step):
		draw_line(Vector2(0, y), Vector2(IMG_SIZE.x, y), c, 1.0)

func _draw_routes() -> void:
	# Ścieżki handlowe z DB.routes (klucze "A->B")
	var line: Color = Color(0.85, 0.7, 0.45, 1.0)  # jasny, „drogowy”
	var shadow: Color = Color(0.0, 0.0, 0.0, 0.25)
	for key in DB.routes.keys():
		if not (key is String):
			continue
		var parts: PackedStringArray = String(key).split("->", false, 2)
		if parts.size() != 2:
			continue
		var a_id: String = parts[0]
		var b_id: String = parts[1]
		if not (DB.positions.has(a_id) and DB.positions.has(b_id)):
			continue
		var pa: Vector2 = DB.positions[a_id]
		var pb: Vector2 = DB.positions[b_id]
		# lekki cień pod linią
		draw_line(pa + Vector2(0, 1), pb + Vector2(0, 1), shadow, 4.0)
		# właściwa linia trasy
		draw_line(pa, pb, line, 3.0)

func _draw_locations() -> void:
		var font := get_theme_default_font()
		# rysuj w stabilnej kolejności po kodach
		var ids: Array = DB.positions.keys()
		ids.sort()
		for loc_id in ids:
				var pos: Vector2 = DB.positions[loc_id]
				var radius: float = 10.5
				if loc_id == hover_loc:
						radius *= hover_scale
						draw_circle(pos, radius + 2.0, Color.WHITE)
				# marker: kropka z ciemnym środkiem
				draw_circle(pos, radius, Color(0.95, 0.3, 0.2, 0.9))
				draw_circle(pos, 3.75, Color(0.1, 0.1, 0.1, 1.0))
				# podpis (tłumaczona nazwa)
				var label_pos := pos + Vector2(12, -8)
				var name_str: String = DB.get_loc_name(loc_id)
				# cień
				draw_string(font, label_pos + Vector2(1, 1), name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0, 0, 0, 0.65))
				# właściwy napis
								draw_string(font, label_pos, name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

func _draw_caravans() -> void:
	var players_dict: Dictionary = PlayerMgr.players
	if players_dict == null or players_dict.is_empty():
	return
	var col_base := Color(0.95, 0.8, 0.2, 1.0)
	var col_alt := Color(0.95, 0.2, 0.2, 1.0)
	var col := col_base.lerp(col_alt, player_blink)
	for id in players_dict.keys():
	var p = players_dict[id]
	var pos: Vector2 = Vector2.ZERO
	if p.get("moving", false) and p.has("from") and p.has("to") and DB.positions.has(p["from"]) and DB.positions.has(p["to"]):
	var from_pos: Vector2 = DB.positions[p["from"]]
	var to_pos: Vector2 = DB.positions[p["to"]]
	var t: float = clamp(p.get("progress", 0.0), 0.0, 1.0)
	pos = from_pos.lerp(to_pos, t)
	var dir: Vector2 = (to_pos - from_pos).normalized()
	var perp: Vector2 = dir.orthogonal() * 6.0
	var tip: Vector2 = pos + dir * 12.0
	var tail: Vector2 = pos - dir * 12.0
	var tri := PackedVector2Array([tip, tail + perp, tail - perp])
	draw_colored_polygon(tri, col)
	elif p.has("loc") and DB.positions.has(p["loc"]):
	pos = DB.positions[p["loc"]]
	draw_circle(pos, 8.0, col)
	else:
	continue
func _draw_players() -> void:
		var players_dict: Dictionary = PlayerMgr.players
		if players_dict == null or players_dict.is_empty():
				return
		var font := get_theme_default_font()
		for id in players_dict.keys():
				var p = players_dict[id]
				var pos: Vector2 = Vector2.ZERO
				if p.get("moving", false) and p.has("from") and p.has("to") and DB.positions.has(p["from"]) and DB.positions.has(p["to"]):
						var from_pos: Vector2 = DB.positions[p["from"]]
						var to_pos: Vector2 = DB.positions[p["to"]]
						var t: float = clamp(p.get("progress", 0.0), 0.0, 1.0)
						pos = from_pos.lerp(to_pos, t)
				elif p.has("loc") and DB.positions.has(p["loc"]):
						pos = DB.positions[p["loc"]]
				else:
						continue
				var disp_label: String = "P"
				if p.has("name"):
						disp_label = String(p["name"])
				draw_string(font, pos + Vector2(12, -8), disp_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
				var mouse_pos: Vector2 = _to_image(event.position)
				var found: String = ""
				for loc_id in DB.positions.keys():
						var p: Vector2 = DB.positions[loc_id]
						if p.distance_to(mouse_pos) <= 18.0:
								found = loc_id
								break
				if found != hover_loc:
						hover_loc = found
						if _hover_tween != null:
								_hover_tween.kill()
						_hover_tween = create_tween()
						var target: float = (hover_loc == "") if true else 1.0
						_hover_tween.tween_property(self, "hover_scale", target, 0.1)
						queue_redraw()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				# Przelicz klik ze space UI → space obrazu
				var click_pos: Vector2 = _to_image(event.position)
				# Trafienie w lokację po większym okręgu
				for loc_id in DB.positions.keys():
						var p: Vector2 = DB.positions[loc_id]
						if p.distance_to(click_pos) <= 18.0:
								emit_signal("location_clicked", loc_id)
								break

func _process(_delta: float) -> void:
		queue_redraw()
