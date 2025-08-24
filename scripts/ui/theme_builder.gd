extends Node
class_name ThemeBuilder

static func make_stylebox(tex_path: String, m: int, content: int = 6) -> StyleBoxTexture:
    var sb := StyleBoxTexture.new()
    sb.texture = load(tex_path)
    sb.texture_margin_left = m
    sb.texture_margin_top = m
    sb.texture_margin_right = m
    sb.texture_margin_bottom = m
    sb.content_margin_left = content
    sb.content_margin_top = content
    sb.content_margin_right = content
    sb.content_margin_bottom = content
    sb.draw_center = true
    return sb
