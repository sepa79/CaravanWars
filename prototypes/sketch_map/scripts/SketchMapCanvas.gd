class_name SketchMapCanvas
extends Control

const SYMBOL_MANIFEST_PATH: String = "res://assets/map_symbol_sets/de_fer_player_rough/manifest.json"
const SYMBOL_BASE_PATH: String = "res://assets/map_symbol_sets/de_fer_player_rough"

var model: RefCounted
var zoom: float = 0.92
var pan: Vector2 = Vector2(80, 70)
var selected_node_id: String = ""
var view_mode: String = "player"

var _dragging: bool = false
var _last_mouse_pos: Vector2 = Vector2.ZERO
var _symbol_defs: Dictionary = {}
var _symbol_textures: Dictionary = {}


func _ready() -> void:
    _load_symbol_set(SYMBOL_MANIFEST_PATH)


func bind_model(bound_model: RefCounted) -> void:
    model = bound_model
    queue_redraw()


func set_view_mode(next_mode: String) -> void:
    view_mode = next_mode
    selected_node_id = ""
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

    match view_mode:
        "bought":
            _draw_bought_map(false)
        "compare":
            _draw_bought_map(true)
            _draw_erased_marks()
            _draw_rivers()
            _draw_edges()
            _draw_nodes()
        "truth":
            _draw_truth_map()
        _:
            _draw_erased_marks()
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
            _draw_verified_river(screen_points)


func _draw_erased_marks() -> void:
    for river: Dictionary in model.erased_rivers:
        var river_points: PackedVector2Array = PackedVector2Array()
        for point: Vector2 in river.get("points", []):
            river_points.append(_to_screen(point))
        if river_points.size() >= 2:
            _draw_sketch_river(river_points, true)

    for edge: Dictionary in model.erased_edges:
        var edge_points: PackedVector2Array = PackedVector2Array()
        for point: Vector2 in edge.get("path", PackedVector2Array()):
            edge_points.append(_to_screen(point))
        if edge_points.size() >= 2:
            var erased_path: PackedVector2Array = _trim_polyline_ends(
                _smooth_polyline(edge_points),
                _node_gap_from_map(model.map_nodes, str(edge.get("from", ""))),
                _node_gap_from_map(model.map_nodes, str(edge.get("to", "")))
            )
            draw_polyline(erased_path, Color(0.28, 0.24, 0.18, 0.10), 3.0, true)
            _draw_dotted_polyline(erased_path, Color(0.10, 0.08, 0.06, 0.16), 0.7)

    var font: Font = get_theme_default_font()
    for node: Dictionary in model.erased_nodes:
        var pos: Vector2 = _to_screen(node.get("map_pos", Vector2.ZERO))
        var color: Color = Color(0.10, 0.08, 0.06, 0.20)
        _draw_icon(pos, str(node.get("kind", "unknown")), color, int(node.get("variant", 0)), false)
        draw_line(pos + Vector2(-14, -10), pos + Vector2(16, 10), color, 1.2)
        var label: String = str(node.get("label", ""))
        if label != "":
            _draw_node_label(font, pos, node, label, color, false)


func _draw_bought_map(skip_player_known_nodes: bool) -> void:
    if model.bought_map_quality < 0.0:
        return

    for river_id: String in model.bought_map_rivers.keys():
        var river: Dictionary = model.bought_map_rivers[river_id]
        var river_points: PackedVector2Array = PackedVector2Array()
        for point: Vector2 in river.get("points", []):
            river_points.append(_to_screen(point))
        if river_points.size() >= 2:
            _draw_sketch_river(river_points, false)

    for edge_id: String in model.bought_map_edges.keys():
        var edge: Dictionary = model.bought_map_edges[edge_id]
        var edge_points: PackedVector2Array = PackedVector2Array()
        for point: Vector2 in edge.get("path", PackedVector2Array()):
            edge_points.append(_to_screen(point))
        if edge_points.size() >= 2:
            var bought_path: PackedVector2Array = _trim_polyline_ends(
                _smooth_polyline(edge_points),
                _node_gap_from_map(model.bought_map_nodes, str(edge.get("from", ""))),
                _node_gap_from_map(model.bought_map_nodes, str(edge.get("to", "")))
            )
            draw_polyline(bought_path, Color(0.16, 0.12, 0.08, 0.24), 0.8, true)

    var font: Font = get_theme_default_font()
    for node_id: String in model.bought_map_nodes.keys():
        if skip_player_known_nodes and model.map_nodes.has(node_id):
            continue

        var node: Dictionary = model.bought_map_nodes[node_id]
        var pos: Vector2 = _to_screen(node.get("map_pos", Vector2.ZERO))
        var color: Color = _ink_for_observation(node)
        _draw_icon(pos, str(node.get("kind", "unknown")), color, int(node.get("variant", 0)), false)

        var label: String = str(node.get("label", node_id))
        _draw_node_label(font, pos, node, label, color, false)


func _draw_truth_map() -> void:
    for river: Dictionary in model.rivers:
        var river_points: PackedVector2Array = PackedVector2Array()
        for point_value: Variant in river.get("points", []):
            river_points.append(_to_screen(_array_to_vec2(point_value)))
        if river_points.size() >= 2:
            _draw_verified_river(river_points)

    for edge: Dictionary in model.edges:
        var from_id: String = str(edge.get("from", ""))
        var to_id: String = str(edge.get("to", ""))
        if not model.nodes_by_id.has(from_id) or not model.nodes_by_id.has(to_id):
            continue

        var from_pos: Vector2 = _array_to_vec2(model.nodes_by_id[from_id].get("position", [0, 0]))
        var to_pos: Vector2 = _array_to_vec2(model.nodes_by_id[to_id].get("position", [0, 0]))
        var points: PackedVector2Array = _smooth_polyline(PackedVector2Array([from_pos, (from_pos + to_pos) * 0.5, to_pos]))
        for i: int in range(0, points.size()):
            points[i] = _to_screen(points[i])
        draw_polyline(points, Color(0.10, 0.07, 0.04, 0.38), 1.4, true)

    var font: Font = get_theme_default_font()
    for node_id: String in model.nodes_by_id.keys():
        var node: Dictionary = model.nodes_by_id[node_id]
        var pos: Vector2 = _to_screen(_array_to_vec2(node.get("position", [0, 0])))
        var color: Color = Color(0.08, 0.05, 0.03, 0.78)
        _draw_icon(pos, str(node.get("kind", "unknown")), color, int(abs(hash("%s:truth" % node_id)) % 4), false)
        _draw_node_label(font, pos, node, str(node.get("name", node_id)), color, false)


func _draw_edges() -> void:
    for edge_id: String in model.map_edges.keys():
        var edge: Dictionary = model.map_edges[edge_id]
        var source: String = str(edge.get("source", "heard"))
        var points: PackedVector2Array = PackedVector2Array()
        for point: Vector2 in edge.get("path", PackedVector2Array()):
            points.append(_to_screen(point))

        if points.size() < 2:
            continue

        var smooth_points: PackedVector2Array = _trim_polyline_ends(
            _smooth_polyline(points),
            _node_gap_from_map(model.map_nodes, str(edge.get("from", ""))),
            _node_gap_from_map(model.map_nodes, str(edge.get("to", "")))
        )
        var color: Color = _ink_for_observation(edge)
        var width: float = 1.45 if source == "visited" else 0.95
        if source == "heard" or source == "copied":
            _draw_dotted_polyline(smooth_points, color, width)
        else:
            draw_polyline(smooth_points, color, width, true)
            if source == "visited":
                draw_polyline(_jittered(smooth_points, edge_id), Color(color.r, color.g, color.b, 0.22), 0.55, true)


func _draw_nodes() -> void:
    var font: Font = get_theme_default_font()
    for node_id: String in model.map_nodes.keys():
        var node: Dictionary = model.map_nodes[node_id]
        var pos: Vector2 = _to_screen(node.get("map_pos", Vector2.ZERO))
        var source: String = str(node.get("source", "heard"))
        var color: Color = _ink_for_observation(node)
        var selected: bool = node_id == selected_node_id

        _draw_icon(pos, str(node.get("kind", "unknown")), color, int(node.get("variant", 0)), selected)

        var label: String = str(node.get("label", node_id))
        _draw_node_label(font, pos, node, label, color, true)


func _draw_icon(pos: Vector2, kind: String, color: Color, variant: int, selected: bool) -> void:
    var icon_scale: float = clamp(zoom, 0.65, 1.85)
    if selected:
        draw_circle(pos, 18.0 * icon_scale, Color(0.55, 0.10, 0.06, 0.16))
        draw_arc(pos, 18.0 * icon_scale, 0.0, TAU, 24, Color(0.55, 0.10, 0.06, 0.65), 2.0)

    _draw_icon_backing(pos, kind, variant)

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
            var half: float = 15.0 * icon_scale
            var y: float = 4.0 * icon_scale
            draw_line(pos + Vector2(-half, y), pos + Vector2(half, y), color, 2.0)
            draw_line(pos + Vector2(-half * 0.72, -y), pos + Vector2(half * 0.72, -y), color, 1.6)
            draw_line(pos + Vector2(-half * 0.45, -8.0 * icon_scale), pos + Vector2(-half * 0.45, 8.0 * icon_scale), color, 1.2)
            draw_line(pos + Vector2(0, -8.0 * icon_scale), pos + Vector2(0, 8.0 * icon_scale), color, 1.2)
            draw_line(pos + Vector2(half * 0.45, -8.0 * icon_scale), pos + Vector2(half * 0.45, 8.0 * icon_scale), color, 1.2)
        "ford":
            var wave: float = 12.0 * icon_scale
            draw_arc(pos + Vector2(-wave * 0.55, -3.0 * icon_scale), wave * 0.45, 0.0, PI, 10, color, 1.6)
            draw_arc(pos + Vector2(wave * 0.20, -3.0 * icon_scale), wave * 0.45, 0.0, PI, 10, color, 1.6)
            draw_line(pos + Vector2(-wave, 5.0 * icon_scale), pos + Vector2(wave, -5.0 * icon_scale), color, 1.5)
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

    var symbol_scale: float = float(symbol.get("scale", 1.0)) * clamp(zoom, 0.65, 1.85)
    var symbol_size: Vector2 = texture.get_size() * symbol_scale
    var offset: Vector2 = _array_to_vec2(symbol.get("offset", [0, 0])) * symbol_scale
    var rect: Rect2 = Rect2(pos - symbol_size * 0.5 + offset, symbol_size)
    draw_texture_rect(texture, rect, false, Color(1.0, 1.0, 1.0, clamp(color.a, 0.18, 1.0)))
    return true


func _draw_icon_backing(pos: Vector2, kind: String, variant: int) -> void:
    var rect: Rect2 = _symbol_screen_rect(pos, kind, variant)
    if rect.size == Vector2.ZERO:
        var fallback_radius: float = 22.0 * clamp(zoom, 0.65, 1.85)
        _draw_soft_paper_circle(pos, fallback_radius)
        return

    rect = rect.grow(5.0 * clamp(zoom, 0.65, 1.85))
    _draw_soft_paper_rect(rect)


func _symbol_screen_rect(pos: Vector2, kind: String, variant: int) -> Rect2:
    if not _symbol_textures.has(kind):
        return Rect2()

    var variants: Array = _symbol_textures[kind]
    if variants.is_empty():
        return Rect2()

    var symbol: Dictionary = variants[variant % variants.size()]
    var texture: Texture2D = symbol.get("texture", null)
    if texture == null:
        return Rect2()

    var symbol_scale: float = float(symbol.get("scale", 1.0)) * clamp(zoom, 0.65, 1.85)
    var symbol_size: Vector2 = texture.get_size() * symbol_scale
    var offset: Vector2 = _array_to_vec2(symbol.get("offset", [0, 0])) * symbol_scale
    return Rect2(pos - symbol_size * 0.5 + offset, symbol_size)


func _draw_soft_paper_rect(rect: Rect2) -> void:
    var center: Vector2 = rect.get_center()
    var radius: Vector2 = rect.size * 0.58
    _draw_soft_paper_ellipse(center, radius)


func _draw_soft_paper_circle(pos: Vector2, radius: float) -> void:
    _draw_soft_paper_ellipse(pos, Vector2(radius, radius))


func _draw_soft_paper_ellipse(pos: Vector2, radius: Vector2) -> void:
    var paper: Color = Color(0.82, 0.74, 0.56, 1.0)
    for i: int in range(7, -1, -1):
        var t: float = float(i) / 7.0
        var expanded: Vector2 = radius * (1.0 + t * 0.65)
        var alpha: float = lerpf(0.08, 0.92, 1.0 - t)
        _draw_filled_ellipse(pos, expanded, Color(paper.r, paper.g, paper.b, alpha))


func _draw_filled_ellipse(pos: Vector2, radius: Vector2, color: Color) -> void:
    var points: PackedVector2Array = PackedVector2Array()
    for i: int in range(0, 33):
        var angle: float = TAU * float(i) / 32.0
        points.append(pos + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
    draw_colored_polygon(points, color)


func _draw_node_label(font: Font, pos: Vector2, node: Dictionary, label: String, color: Color, shadow: bool) -> void:
    var font_size: int = int(round(13.0 * clamp(zoom, 0.78, 1.45)))
    var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
    var kind: String = str(node.get("kind", "unknown"))
    var variant: int = int(node.get("variant", 0))
    var icon_rect: Rect2 = _symbol_screen_rect(pos, kind, variant)
    var icon_top: float = pos.y - _fallback_icon_radius(kind)
    if icon_rect.size != Vector2.ZERO:
        icon_top = icon_rect.position.y

    var label_gap: float = 5.0 * clamp(zoom, 0.78, 1.45)
    var label_pos: Vector2 = Vector2(pos.x - text_size.x * 0.5, icon_top - label_gap)
    if shadow:
        draw_string(font, label_pos + Vector2(1, 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.20, 0.14, 0.08, 0.28))
    draw_string(font, label_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_legend() -> void:
    var font: Font = get_theme_default_font()
    var base: Vector2 = Vector2(24, size.y - 94)
    draw_rect(Rect2(base - Vector2(12, 22), Vector2(340, 78)), Color(0.86, 0.78, 0.58, 0.55), true)
    draw_string(font, base, "Ink: solid=travelled  light=seen  dotted=heard/copied", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.20, 0.14, 0.08))
    var bought_text: String = ""
    if model.bought_map_quality >= 0.0:
        bought_text = "  bought=%d%% quality" % int(round(model.bought_map_quality * 100.0))
    draw_string(font, base + Vector2(0, 24), "View=%s. Drag parchment to pan. Mouse wheel to zoom.%s" % [view_mode, bought_text], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.20, 0.14, 0.08))
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


func _draw_verified_river(points: PackedVector2Array) -> void:
    var color: Color = Color(0.08, 0.06, 0.04, 0.68)
    var smooth_points: PackedVector2Array = _smooth_polyline(points)
    var offset_distance: float = 2.3
    draw_polyline(_offset_polyline(smooth_points, offset_distance), color, 0.55, true)
    draw_polyline(_offset_polyline(smooth_points, -offset_distance), color, 0.55, true)
    _draw_river_marks(smooth_points, color)


func _draw_sketch_river(points: PackedVector2Array, erased: bool) -> void:
    var color: Color = Color(0.12, 0.10, 0.07, 0.14 if erased else 0.30)
    var smooth_points: PackedVector2Array = _smooth_polyline(points)
    var offset_distance: float = 2.3
    draw_polyline(_offset_polyline(smooth_points, offset_distance), color, 0.45, true)
    draw_polyline(_offset_polyline(smooth_points, -offset_distance), color, 0.45, true)


func _draw_river_marks(points: PackedVector2Array, color: Color) -> void:
    var font: Font = get_theme_default_font()
    for i: int in range(0, points.size() - 1):
        var start: Vector2 = points[i]
        var end: Vector2 = points[i + 1]
        var segment: Vector2 = end - start
        var length: float = segment.length()
        if length < 70.0:
            continue

        var count: int = int(length / 120.0) + 1
        var dir: Vector2 = segment.normalized()
        var angle: float = dir.angle()
        for mark_index: int in range(0, count):
            var t: float = (float(mark_index) + 0.5) / float(count)
            var mark_pos: Vector2 = start.lerp(end, t)
            draw_set_transform(mark_pos, angle, Vector2.ONE)
            draw_string(font, Vector2(-5, 4), "~", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)
            draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _offset_polyline(points: PackedVector2Array, distance: float) -> PackedVector2Array:
    var output: PackedVector2Array = PackedVector2Array()
    for i: int in range(0, points.size()):
        var previous: Vector2 = points[max(i - 1, 0)]
        var next: Vector2 = points[min(i + 1, points.size() - 1)]
        var direction: Vector2 = next - previous
        if direction.length() <= 0.1:
            output.append(points[i])
            continue

        var normal: Vector2 = Vector2(-direction.y, direction.x).normalized()
        output.append(points[i] + normal * distance)
    return output


func _smooth_polyline(points: PackedVector2Array) -> PackedVector2Array:
    if points.size() < 3:
        return points

    var output: PackedVector2Array = PackedVector2Array()
    output.append(points[0])
    for i: int in range(0, points.size() - 1):
        var p0: Vector2 = points[max(i - 1, 0)]
        var p1: Vector2 = points[i]
        var p2: Vector2 = points[i + 1]
        var p3: Vector2 = points[min(i + 2, points.size() - 1)]
        for step: int in range(1, 8):
            var t: float = float(step) / 8.0
            output.append(_catmull_rom(p0, p1, p2, p3, t))
    return output


func _catmull_rom(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
    var t2: float = t * t
    var t3: float = t2 * t
    return 0.5 * (
        (2.0 * p1)
        + (-p0 + p2) * t
        + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
        + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
    )


func _jittered(points: PackedVector2Array, seed_text: String) -> PackedVector2Array:
    var output: PackedVector2Array = PackedVector2Array()
    for i: int in range(0, points.size()):
        var seed: int = abs(hash("%s:%d" % [seed_text, i]))
        var offset: Vector2 = Vector2(float(seed % 5) - 2.0, float((seed / 7) % 5) - 2.0)
        output.append(points[i] + offset)
    return output


func _node_gap_from_map(node_map: Dictionary, node_id: String) -> float:
    if not node_map.has(node_id):
        return 28.0
    return _node_icon_gap(node_map[node_id])


func _node_icon_gap(node: Dictionary) -> float:
    var kind: String = str(node.get("kind", "unknown"))
    if _symbol_textures.has(kind):
        var variants: Array = _symbol_textures[kind]
        if not variants.is_empty():
            var variant: int = int(node.get("variant", 0)) % variants.size()
            var symbol: Dictionary = variants[variant]
            var texture: Texture2D = symbol.get("texture", null)
            if texture != null:
                var symbol_scale: float = float(symbol.get("scale", 1.0)) * clamp(zoom, 0.65, 1.85)
                var symbol_size: Vector2 = texture.get_size() * symbol_scale
                return min(max(symbol_size.x, symbol_size.y) * 0.18, 24.0) + 8.0

    match kind:
        "bridge", "ford":
            return 16.0 * clamp(zoom, 0.65, 1.85)
        _:
            return 18.0 * clamp(zoom, 0.65, 1.85)


func _fallback_icon_radius(kind: String) -> float:
    var scale: float = clamp(zoom, 0.65, 1.85)
    match kind:
        "bridge", "ford":
            return 18.0 * scale
        "hill":
            return 20.0 * scale
        "mill":
            return 18.0 * scale
        _:
            return 22.0 * scale


func _trim_polyline_ends(points: PackedVector2Array, start_gap: float, end_gap: float = -1.0) -> PackedVector2Array:
    if points.size() < 2 or start_gap <= 0.0:
        return points

    if end_gap < 0.0:
        end_gap = start_gap

    var start_trimmed: PackedVector2Array = _trim_polyline_start(points, start_gap)
    var reversed: PackedVector2Array = PackedVector2Array()
    for i: int in range(start_trimmed.size() - 1, -1, -1):
        reversed.append(start_trimmed[i])

    var end_trimmed_reversed: PackedVector2Array = _trim_polyline_start(reversed, end_gap)
    var output: PackedVector2Array = PackedVector2Array()
    for i: int in range(end_trimmed_reversed.size() - 1, -1, -1):
        output.append(end_trimmed_reversed[i])
    return output


func _trim_polyline_start(points: PackedVector2Array, gap: float) -> PackedVector2Array:
    if points.size() < 2:
        return points

    var remaining_gap: float = gap
    for i: int in range(0, points.size() - 1):
        var start: Vector2 = points[i]
        var end: Vector2 = points[i + 1]
        var segment: Vector2 = end - start
        var length: float = segment.length()
        if length <= 0.1:
            continue

        if remaining_gap <= length:
            var output: PackedVector2Array = PackedVector2Array()
            output.append(start + segment.normalized() * remaining_gap)
            for j: int in range(i + 1, points.size()):
                output.append(points[j])
            return output

        remaining_gap -= length

    return PackedVector2Array()


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
            return Color(0.16, 0.13, 0.09, 0.50)
        "bought":
            return Color(0.16, 0.13, 0.09, 0.36)
        _:
            return Color(0.18, 0.12, 0.08, 0.70)


func _ink_for_observation(observation: Dictionary) -> Color:
    var medium: String = str(observation.get("medium", ""))
    match medium:
        "ink":
            return Color(0.12, 0.07, 0.04, 0.95)
        "thin_ink":
            return Color(0.22, 0.14, 0.08, 0.60)
        "charcoal":
            if str(observation.get("status", "")) == "erased":
                return Color(0.10, 0.08, 0.06, 0.20)
            if str(observation.get("source", "")) == "copied":
                return Color(0.16, 0.13, 0.09, 0.50)
            return Color(0.20, 0.17, 0.12, 0.38)
        _:
            return _ink_for_source(str(observation.get("source", "")))


func _array_to_vec2(value: Variant) -> Vector2:
    if typeof(value) == TYPE_ARRAY and value.size() >= 2:
        return Vector2(float(value[0]), float(value[1]))
    return Vector2.ZERO
