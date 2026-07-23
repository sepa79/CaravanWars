class_name DebugMapCanvas
extends Control

var model: RefCounted = null
var zoom: float = 1.05
var pan: Vector2 = Vector2(34, 34)
var selected_node_id: String = ""

var _dragging: bool = false
var _last_mouse_pos: Vector2 = Vector2.ZERO


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

    _draw_terrain_areas()
    _draw_edges()
    _draw_landmarks()
    _draw_nodes()
    _draw_overlay()


func _draw_parchment() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.54, 0.45, 0.32), true)
    draw_rect(Rect2(Vector2(10, 10), size - Vector2(20, 20)), Color(0.80, 0.72, 0.54), true)
    for i: int in range(0, 120):
        var x: float = float((i * 97) % int(max(size.x, 1.0)))
        var y: float = float((i * 53) % int(max(size.y, 1.0)))
        var radius: float = 12.0 + float((i * 13) % 34)
        draw_circle(Vector2(x, y), radius, Color(0.36, 0.24, 0.12, 0.018))


func _draw_terrain_areas() -> void:
    for area: Dictionary in model.map_terrain_areas.values():
        var color: Color = _terrain_color(str(area.get("kind", "unknown")), str(area.get("source", "")) == "truth")
        if str(area.get("shape", "polygon")) == "ellipse":
            var center: Vector2 = _to_screen(area.get("center", Vector2.ZERO))
            var radius: Vector2 = area.get("radius", Vector2.ZERO) * zoom
            if radius.x > 0.0 and radius.y > 0.0:
                _draw_filled_ellipse(center, radius, color)
                _draw_ellipse_outline(center, radius, Color(color.r, color.g, color.b, min(color.a + 0.14, 0.48)))
            continue

        var points: PackedVector2Array = PackedVector2Array()
        for point: Vector2 in area.get("points", []):
            points.append(_to_screen(point))
        if points.size() >= 3:
            draw_colored_polygon(points, color)
            var outline: PackedVector2Array = points.duplicate()
            outline.append(points[0])
            draw_polyline(outline, Color(color.r * 0.65, color.g * 0.65, color.b * 0.65, min(color.a + 0.16, 0.46)), 0.8, true)


func _draw_edges() -> void:
    for edge: Dictionary in model.map_edges.values():
        var screen_path: PackedVector2Array = PackedVector2Array()
        for point: Vector2 in edge.get("path", PackedVector2Array()):
            screen_path.append(_to_screen(point))
        if screen_path.size() < 2:
            continue

        screen_path = _smooth_polyline(screen_path)
        var color: Color = Color(0.12, 0.08, 0.05, 0.85)
        if str(edge.get("source", "")) == "known":
            color = Color(0.20, 0.13, 0.07, 0.58)
        elif str(edge.get("source", "")) == "observed":
            color = Color(0.10, 0.06, 0.03, 0.78)
        var width: float = 1.8 if str(edge.get("source", "")) == "observed" else 1.15
        draw_polyline(screen_path, color, width, true)
        if str(edge.get("source", "")) == "observed":
            draw_polyline(_jittered(screen_path, str(edge.get("id", ""))), Color(color.r, color.g, color.b, 0.28), 0.7, true)


func _draw_nodes() -> void:
    var font: Font = get_theme_default_font()
    for node: Dictionary in model.map_nodes.values():
        var pos: Vector2 = _to_screen(node.get("map_pos", node.get("position", Vector2.ZERO)))
        var color: Color = _ink_for_source(str(node.get("source", "")))
        var selected: bool = str(node.get("id", "")) == selected_node_id
        _draw_node_symbol(pos, str(node.get("kind", "unknown")), color, selected)
        _draw_label(font, pos, str(node.get("label", node.get("name", ""))), color, 13, selected)


func _draw_landmarks() -> void:
    var font: Font = get_theme_default_font()
    for landmark: Dictionary in model.map_landmarks.values():
        var pos: Vector2 = _to_screen(landmark.get("map_pos", landmark.get("position", Vector2.ZERO)))
        var color: Color = _ink_for_source(str(landmark.get("source", "")))
        _draw_landmark_symbol(pos, str(landmark.get("kind", "landmark")), color, int(landmark.get("variant", 0)))
        _draw_label(font, pos, str(landmark.get("label", landmark.get("name", ""))), color, 11, false)


func _draw_overlay() -> void:
    var font: Font = get_theme_default_font()
    var mode_text: String = "Debug map: %s / %s" % [str(model.map_mode), str(model.selected_party_id)]
    var truth_warning: String = "TRUTH VIEW - full graph" if str(model.map_mode) == "truth" else "PARTY VIEW - filtered knowledge"
    draw_rect(Rect2(Vector2(18, 18), Vector2(360, 54)), Color(0.88, 0.79, 0.58, 0.76), true)
    draw_string(font, Vector2(30, 40), mode_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.16, 0.10, 0.06, 0.95))
    draw_string(font, Vector2(30, 62), truth_warning, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.28, 0.08, 0.04, 0.86))
    if selected_node_id != "" and model.map_nodes.has(selected_node_id):
        var node: Dictionary = model.map_nodes[selected_node_id]
        draw_rect(Rect2(Vector2(18, size.y - 44), Vector2(300, 28)), Color(0.88, 0.79, 0.58, 0.70), true)
        draw_string(font, Vector2(30, size.y - 24), "Selected: %s" % str(node.get("label", selected_node_id)), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.16, 0.10, 0.06, 0.95))


func _draw_node_symbol(pos: Vector2, kind: String, color: Color, selected: bool) -> void:
    if selected:
        draw_circle(pos, 17.0 * clamp(zoom, 0.7, 1.7), Color(0.55, 0.10, 0.06, 0.16))
        draw_arc(pos, 17.0 * clamp(zoom, 0.7, 1.7), 0.0, TAU, 24, Color(0.55, 0.10, 0.06, 0.65), 2.0)
    _draw_soft_paper_circle(pos, 18.0 * clamp(zoom, 0.7, 1.7))
    match kind:
        "town":
            draw_rect(Rect2(pos + Vector2(-5, -5), Vector2(10, 10)), color, false, 1.5)
            draw_line(pos + Vector2(-7, -5), pos + Vector2(0, -13), color, 1.5)
            draw_line(pos + Vector2(0, -13), pos + Vector2(7, -5), color, 1.5)
        "ford":
            draw_arc(pos + Vector2(-4, -1), 5.0, 0.0, PI, 8, color, 1.3)
            draw_arc(pos + Vector2(4, -1), 5.0, 0.0, PI, 8, color, 1.3)
        "hill":
            draw_arc(pos + Vector2(0, 5), 9.0, PI, TAU, 12, color, 1.4)
        _:
            draw_circle(pos, 4.0, color, false, 1.6)


func _draw_landmark_symbol(pos: Vector2, kind: String, color: Color, variant: int) -> void:
    _draw_soft_paper_circle(pos, 14.0 * clamp(zoom, 0.7, 1.7))
    match kind:
        "tree":
            draw_line(pos + Vector2(0, 8), pos + Vector2(0, -8 - variant), color, 1.5)
            draw_arc(pos + Vector2(-4, -3), 7.0, PI * 0.15, PI * 1.35, 12, color, 1.4)
            draw_arc(pos + Vector2(4, -3), 7.0, -PI * 0.35, PI * 0.85, 12, color, 1.4)
        "ford":
            draw_arc(pos + Vector2(-5, -2), 5.0, 0.0, PI, 8, color, 1.3)
            draw_arc(pos + Vector2(3, -2), 5.0, 0.0, PI, 8, color, 1.3)
            draw_line(pos + Vector2(-10, 5), pos + Vector2(10, -5), color, 1.2)
        "hill":
            draw_arc(pos + Vector2(-4, 6), 10.0, PI, TAU, 12, color, 1.3)
            draw_arc(pos + Vector2(6, 6), 12.0, PI, TAU, 12, color, 1.2)
        _:
            draw_circle(pos, 5.0, color, false, 1.5)
            draw_line(pos + Vector2(-7, 7), pos + Vector2(7, -7), color, 1.0)


func _draw_label(font: Font, pos: Vector2, label: String, color: Color, font_size: int, shadow: bool) -> void:
    if label.is_empty():
        return

    var scaled_size: int = int(round(float(font_size) * clamp(zoom, 0.82, 1.25)))
    var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, scaled_size)
    var label_pos: Vector2 = pos + Vector2(-text_size.x * 0.5, -18.0 * clamp(zoom, 0.8, 1.45))
    if shadow:
        draw_string(font, label_pos + Vector2(1, 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, scaled_size, Color(0.20, 0.14, 0.08, 0.28))
    draw_string(font, label_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, scaled_size, color)


func _draw_filled_ellipse(pos: Vector2, radius: Vector2, color: Color) -> void:
    var points: PackedVector2Array = PackedVector2Array()
    for i: int in range(0, 33):
        var angle: float = TAU * float(i) / 32.0
        points.append(pos + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
    draw_colored_polygon(points, color)


func _draw_ellipse_outline(pos: Vector2, radius: Vector2, color: Color) -> void:
    var points: PackedVector2Array = PackedVector2Array()
    for i: int in range(0, 34):
        var angle: float = TAU * float(i) / 33.0
        points.append(pos + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
    draw_polyline(points, color, 0.8, true)


func _draw_soft_paper_circle(pos: Vector2, radius: float) -> void:
    var paper: Color = Color(0.80, 0.72, 0.54, 1.0)
    for i: int in range(5, -1, -1):
        var t: float = float(i) / 5.0
        var alpha: float = lerpf(0.08, 0.82, 1.0 - t)
        _draw_filled_ellipse(pos, Vector2(radius, radius) * (1.0 + t * 0.55), Color(paper.r, paper.g, paper.b, alpha))


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
            output.append(_catmull_rom(p0, p1, p2, p3, float(step) / 8.0))
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
        var seed_value: int = abs(hash("%s:%d" % [seed_text, i]))
        output.append(points[i] + Vector2(float(seed_value % 5) - 2.0, float((seed_value / 7) % 5) - 2.0))
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
    zoom = clamp(zoom * factor, 0.55, 2.5)
    var after_screen: Vector2 = _to_screen(before)
    pan += screen_pos - after_screen
    queue_redraw()


func _to_screen(world_pos: Vector2) -> Vector2:
    return world_pos * zoom + pan


func _to_world(screen_pos: Vector2) -> Vector2:
    return (screen_pos - pan) / zoom


func _ink_for_source(source: String) -> Color:
    match source:
        "truth":
            return Color(0.08, 0.05, 0.03, 0.92)
        "observed":
            return Color(0.12, 0.07, 0.04, 0.86)
        "known":
            return Color(0.22, 0.14, 0.08, 0.62)
        _:
            return Color(0.18, 0.10, 0.06, 0.70)


func _terrain_color(kind: String, truth: bool) -> Color:
    var alpha: float = 0.18 if truth else 0.12
    match kind:
        "forest":
            return Color(0.16, 0.25, 0.13, alpha)
        "river_valley":
            return Color(0.17, 0.23, 0.20, alpha)
        "hills":
            return Color(0.34, 0.27, 0.17, alpha)
        "marsh":
            return Color(0.15, 0.24, 0.21, alpha)
        "field", "cultivated":
            return Color(0.38, 0.32, 0.18, alpha)
        _:
            return Color(0.24, 0.20, 0.14, alpha)
