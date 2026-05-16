class_name SketchMapCanvas
extends Control

const SYMBOL_MANIFEST_PATH: String = "res://assets/map_symbol_sets/de_fer_player_rough/manifest.json"
const SYMBOL_BASE_PATH: String = "res://assets/map_symbol_sets/de_fer_player_rough"

var model: RefCounted
var zoom: float = 0.92
var pan: Vector2 = Vector2(80, 70)
var selected_node_id: String = ""

var _dragging: bool = false
var _last_mouse_pos: Vector2 = Vector2.ZERO
var _symbol_defs: Dictionary = {}
var _symbol_textures: Dictionary = {}


func _ready() -> void:
    _load_symbol_set(SYMBOL_MANIFEST_PATH)


func bind_model(bound_model: RefCounted) -> void:
    model = bound_model
    queue_redraw()


func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mouse_button: InputEventMouseButton = event
        if mouse_button.button_index == MOUSE_BUTTON_LEFT:
            if mouse_button.pressed:
                var clicked_node_id: String = _node_at_screen(mouse_button.position)
                if clicked_node_id != "":
                    selected_node_id = clicked_node_id
                    queue_redraw()
                else:
                    _dragging = true
                    _last_mouse_pos = mouse_button.position
            else:
                _dragging = false
        elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
            _zoom_at(mouse_button.position, 1.08)
        elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
            _zoom_at(mouse_button.position, 0.92)
    elif event is InputEventMouseMotion and _dragging:
        var motion: InputEventMouseMotion = event
        pan += motion.position - _last_mouse_pos
        _last_mouse_pos = motion.position
        queue_redraw()


func _draw() -> void:
    _draw_parchment()
    if model == null:
        return

    _draw_bought_map()
    _draw_rivers()
    _draw_edges()
    _draw_nodes()
    _draw_legend()


func _draw_parchment() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.72, 0.62, 0.45), true)
    draw_rect(Rect2(Vector2(12, 12), size - Vector2(24, 24)), Color(0.82, 0.74, 0.56), true)
    for i: int in range(0, 90):
        var x: float = float((i * 97) % int(max(size.x, 1.0)))
        var y: float = float((i * 53) % int(max(size.y, 1.0)))
        var r: float = 18.0 + float((i * 13) % 28)
        draw_circle(Vector2(x, y), r, Color(0.45, 0.32, 0.18, 0.025))


func _draw_rivers() -> void:
    for river_id: String in model.map_rivers.keys():
        var river: Dictionary = model.map_rivers[river_id]
        var screen_points: PackedVector2Array = PackedVector2Array()
        for point: Vector2 in river.get("points", []):
            screen_points.append(_to_screen(point))
        if screen_points.size() >= 2:
            draw_polyline(screen_points, Color(0.20, 0.30, 0.38, 0.55), 5.0, true)
            draw_polyline(screen_points, Color(0.16, 0.22, 0.28, 0.65), 1.5, true)


func _draw_bought_map() -> void:
    if model.bought_map_quality < 0.0:
        return

    for river_id: String in model.bought_map_rivers.keys():
        var river: Dictionary = model.bought_map_rivers[river_id]
        var river_points: PackedVector2Array = PackedVector2Array()
        for point: Vector2 in river.get("points", []):
            river_points.append(_to_screen(point))
        if river_points.size() >= 2:
            draw_polyline(river_points, Color(0.14, 0.22, 0.27, 0.24), 4.0, true)

    for edge_id: String in model.bought_map_edges.keys():
        var edge: Dictionary = model.bought_map_edges[edge_id]
        var edge_points: PackedVector2Array = PackedVector2Array()
        for point: Vector2 in edge.get("path", PackedVector2Array()):
            edge_points.append(_to_screen(point))
        if edge_points.size() >= 2:
            draw_polyline(edge_points, Color(0.19, 0.14, 0.09, 0.28), 1.6, true)

    var font: Font = get_theme_default_font()
    for node_id: String in model.bought_map_nodes.keys():
        if model.map_nodes.has(node_id):
            continue

        var node: Dictionary = model.bought_map_nodes[node_id]
        var pos: Vector2 = _to_screen(node.get("map_pos", Vector2.ZERO))
        var color: Color = _ink_for_source("bought")
        _draw_icon(pos, str(node.get("kind", "unknown")), color, int(node.get("variant", 0)), false)

        var label: String = str(node.get("label", node_id))
        var label_pos: Vector2 = pos + Vector2(10, -8)
        draw_string(font, label_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)


func _draw_edges() -> void:
    for edge_id: String in model.map_edges.keys():
        var edge: Dictionary = model.map_edges[edge_id]
        var source: String = str(edge.get("source", "heard"))
        var points: PackedVector2Array = PackedVector2Array()
        for point: Vector2 in edge.get("path", PackedVector2Array()):
            points.append(_to_screen(point))

        if points.size() < 2:
            continue

        var color: Color = _ink_for_source(source)
        var width: float = 2.8 if source == "visited" else 1.8
        if source == "heard" or source == "copied":
            _draw_dotted_polyline(points, color, width)
        else:
            draw_polyline(points, color, width, true)
            if source == "visited":
                draw_polyline(_jittered(points, edge_id), Color(color.r, color.g, color.b, 0.30), 1.0, true)


func _draw_nodes() -> void:
    var font: Font = get_theme_default_font()
    for node_id: String in model.map_nodes.keys():
        var node: Dictionary = model.map_nodes[node_id]
        var pos: Vector2 = _to_screen(node.get("map_pos", Vector2.ZERO))
        var source: String = str(node.get("source", "heard"))
        var color: Color = _ink_for_source(source)
        var selected: bool = node_id == selected_node_id

        _draw_icon(pos, str(node.get("kind", "unknown")), color, int(node.get("variant", 0)), selected)

        var label: String = str(node.get("label", node_id))
        var label_pos: Vector2 = pos + Vector2(12, -10)
        draw_string(font, label_pos + Vector2(1, 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.20, 0.14, 0.08, 0.35))
        draw_string(font, label_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)


func _draw_icon(pos: Vector2, kind: String, color: Color, variant: int, selected: bool) -> void:
    if selected:
        draw_circle(pos, 18.0, Color(0.55, 0.10, 0.06, 0.16))
        draw_arc(pos, 18.0, 0.0, TAU, 24, Color(0.55, 0.10, 0.06, 0.65), 2.0)

    if _draw_symbol_icon(pos, kind, color, variant):
        return

    match kind:
        "town":
            draw_rect(Rect2(pos + Vector2(-9, -8), Vector2(18, 16)), color, false, 2.0)
            draw_line(pos + Vector2(-12, -8), pos + Vector2(0, -18 - variant), color, 2.0)
            draw_line(pos + Vector2(0, -18 - variant), pos + Vector2(12, -8), color, 2.0)
        "village":
            draw_line(pos + Vector2(-11, 6), pos + Vector2(-2, -8 - variant), color, 2.0)
            draw_line(pos + Vector2(-2, -8 - variant), pos + Vector2(8, 6), color, 2.0)
            draw_rect(Rect2(pos + Vector2(-8, 0), Vector2(14, 10)), color, false, 1.7)
        "inn":
            draw_rect(Rect2(pos + Vector2(-10, -7), Vector2(20, 14)), color, false, 2.0)
            draw_line(pos + Vector2(-6, -10), pos + Vector2(8, -15 - variant), color, 2.0)
            draw_line(pos + Vector2(8, -15 - variant), pos + Vector2(13, -5), color, 2.0)
        "bridge":
            draw_arc(pos + Vector2(0, 5), 14.0, PI, TAU, 14, color, 2.0)
            draw_line(pos + Vector2(-16, 5), pos + Vector2(16, 5), color, 2.0)
        "ford":
            draw_line(pos + Vector2(-13, -5), pos + Vector2(13, 6), color, 1.8)
            draw_line(pos + Vector2(-13, 4), pos + Vector2(13, -7), color, 1.8)
        "hill":
            draw_arc(pos + Vector2(-5, 8), 13.0, PI, TAU, 14, color, 1.8)
            draw_arc(pos + Vector2(8, 8), 16.0, PI, TAU, 14, color, 1.6)
        "mill":
            draw_circle(pos, 8.0, Color.TRANSPARENT, false, 1.8)
            for i: int in range(0, 4):
                var angle: float = float(i) * PI * 0.5 + float(variant) * 0.12
                draw_line(pos, pos + Vector2(cos(angle), sin(angle)) * 15.0, color, 1.8)
        _:
            draw_circle(pos, 6.0, color)


func _load_symbol_set(manifest_path: String) -> void:
    _symbol_defs.clear()
    _symbol_textures.clear()

    var file: FileAccess = FileAccess.open(manifest_path, FileAccess.READ)
    if file == null:
        push_warning("Map symbol manifest not found: %s" % manifest_path)
        return

    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        push_warning("Map symbol manifest is not a dictionary: %s" % manifest_path)
        return

    var symbols: Variant = parsed.get("symbols", {})
    if typeof(symbols) == TYPE_DICTIONARY:
        _symbol_defs = symbols

    for kind: String in _symbol_defs.keys():
        var variants: Variant = _symbol_defs[kind]
        if typeof(variants) != TYPE_ARRAY:
            continue

        var loaded_variants: Array[Dictionary] = []
        for variant_value: Variant in variants:
            if typeof(variant_value) != TYPE_DICTIONARY:
                continue

            var variant_def: Dictionary = variant_value
            var texture_path: String = "%s/%s" % [SYMBOL_BASE_PATH, str(variant_def.get("path", ""))]
            var image: Image = Image.new()
            var load_error: Error = image.load(texture_path)
            if load_error != OK:
                push_warning("Map symbol image not found: %s" % texture_path)
                continue

            var texture: Texture2D = ImageTexture.create_from_image(image)
            if texture == null:
                push_warning("Map symbol texture could not be created: %s" % texture_path)
                continue

            variant_def["texture"] = texture
            loaded_variants.append(variant_def)

        if not loaded_variants.is_empty():
            _symbol_textures[kind] = loaded_variants


func _draw_symbol_icon(pos: Vector2, kind: String, color: Color, variant: int) -> bool:
    if not _symbol_textures.has(kind):
        return false

    var variants: Array = _symbol_textures[kind]
    if variants.is_empty():
        return false

    var symbol: Dictionary = variants[variant % variants.size()]
    var texture: Texture2D = symbol.get("texture", null)
    if texture == null:
        return false

    var symbol_scale: float = clamp(zoom, 0.65, 1.85)
    var symbol_size: Vector2 = _array_to_vec2(symbol.get("size", [28, 28])) * symbol_scale
    var offset: Vector2 = _array_to_vec2(symbol.get("offset", [0, 0])) * symbol_scale
    var rect: Rect2 = Rect2(pos - symbol_size * 0.5 + offset, symbol_size)
    draw_texture_rect(texture, rect, false, Color(1.0, 1.0, 1.0, clamp(color.a, 0.18, 1.0)))
    return true


func _draw_legend() -> void:
    var font: Font = get_theme_default_font()
    var base: Vector2 = Vector2(24, size.y - 94)
    draw_rect(Rect2(base - Vector2(12, 22), Vector2(340, 78)), Color(0.86, 0.78, 0.58, 0.55), true)
    draw_string(font, base, "Ink: solid=travelled  light=seen  dotted=heard/copied", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.20, 0.14, 0.08))
    var bought_text: String = ""
    if model.bought_map_quality >= 0.0:
        bought_text = "  bought=%d%% quality" % int(round(model.bought_map_quality * 100.0))
    draw_string(font, base + Vector2(0, 24), "Drag parchment to pan. Mouse wheel to zoom.%s" % bought_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.20, 0.14, 0.08))
    if selected_node_id != "" and model.map_nodes.has(selected_node_id):
        var node: Dictionary = model.map_nodes[selected_node_id]
        draw_string(font, base + Vector2(0, 48), "Selected: %s (%s)" % [str(node.get("label", "")), str(node.get("source", ""))], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.28, 0.08, 0.04))


func _draw_dotted_polyline(points: PackedVector2Array, color: Color, width: float) -> void:
    for i: int in range(0, points.size() - 1):
        var start: Vector2 = points[i]
        var end: Vector2 = points[i + 1]
        var segment: Vector2 = end - start
        var length: float = segment.length()
        if length <= 0.1:
            continue
        var dir: Vector2 = segment / length
        var cursor: float = 0.0
        while cursor < length:
            var dash_end: float = min(cursor + 8.0, length)
            draw_line(start + dir * cursor, start + dir * dash_end, color, width)
            cursor += 16.0


func _jittered(points: PackedVector2Array, seed_text: String) -> PackedVector2Array:
    var output: PackedVector2Array = PackedVector2Array()
    for i: int in range(0, points.size()):
        var seed: int = abs(hash("%s:%d" % [seed_text, i]))
        var offset: Vector2 = Vector2(float(seed % 5) - 2.0, float((seed / 7) % 5) - 2.0)
        output.append(points[i] + offset)
    return output


func _node_at_screen(screen_pos: Vector2) -> String:
    if model == null:
        return ""
    for node_id: String in model.map_nodes.keys():
        var node: Dictionary = model.map_nodes[node_id]
        if _to_screen(node.get("map_pos", Vector2.ZERO)).distance_to(screen_pos) <= 22.0:
            return node_id
    return ""


func _zoom_at(screen_pos: Vector2, factor: float) -> void:
    var before: Vector2 = _to_world(screen_pos)
    zoom = clamp(zoom * factor, 0.45, 2.4)
    var after_screen: Vector2 = _to_screen(before)
    pan += screen_pos - after_screen
    queue_redraw()


func _to_screen(world_pos: Vector2) -> Vector2:
    return world_pos * zoom + pan


func _to_world(screen_pos: Vector2) -> Vector2:
    return (screen_pos - pan) / zoom


func _ink_for_source(source: String) -> Color:
    match source:
        "visited":
            return Color(0.16, 0.10, 0.06, 0.95)
        "seen":
            return Color(0.24, 0.17, 0.10, 0.58)
        "heard":
            return Color(0.30, 0.12, 0.08, 0.42)
        "copied":
            return Color(0.11, 0.20, 0.20, 0.50)
        "bought":
            return Color(0.12, 0.16, 0.17, 0.36)
        _:
            return Color(0.18, 0.12, 0.08, 0.70)


func _array_to_vec2(value: Variant) -> Vector2:
    if typeof(value) == TYPE_ARRAY and value.size() >= 2:
        return Vector2(float(value[0]), float(value[1]))
    return Vector2.ZERO
