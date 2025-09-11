extends Button
class_name LegendIconButton

@export var icon_type: String = ""

func _ready() -> void:
    toggle_mode = true
    button_pressed = true

func _toggled(_pressed: bool) -> void:
    queue_redraw()

func _draw() -> void:
    var base_color: Color = {
        "road": Color.WHITE,
        "river": Color.BLUE,
        "city": Color.RED,
        "village": Color.GREEN,
        "fort": Color.ORANGE,
        "crossing": Color.YELLOW,
        "region": Color.MAGENTA,
    }.get(icon_type, Color.WHITE)
    var col: Color = base_color if button_pressed else base_color.darkened(0.5)
    var c: Vector2 = size * 0.5
    var s: float = min(size.x, size.y) * 0.4
    match icon_type:
        "road":
            draw_line(Vector2(2, c.y), Vector2(size.x - 2, c.y), col, 2.0)
        "river":
            draw_line(Vector2(2, c.y), Vector2(size.x - 2, c.y), col, 2.0)
        "city":
            draw_circle(c, s, col)
        "village":
            var tri := PackedVector2Array([
                c + Vector2(-s, s),
                c + Vector2(s, s),
                c + Vector2(0, -s),
            ])
            draw_polygon(tri, PackedColorArray([col]))
        "fort":
            var rect := PackedVector2Array([
                c + Vector2(-s, -s),
                c + Vector2(s, -s),
                c + Vector2(s, s),
                c + Vector2(-s, s),
            ])
            draw_polygon(rect, PackedColorArray([col]))
        "crossing":
            var diamond := PackedVector2Array([
                c + Vector2(0, -s),
                c + Vector2(s, 0),
                c + Vector2(0, s),
                c + Vector2(-s, 0),
            ])
            draw_polygon(diamond, PackedColorArray([col]))
        "region":
            var r := Rect2(c - Vector2(s, s), Vector2(s * 2.0, s * 2.0))
            draw_rect(r, col)

