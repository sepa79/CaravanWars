extends Node2D
class_name CaravanSprite

enum CaravanState { CART, CART_HORSE, WAGON_2H, CAMELS, BROKEN, HIDDEN }

@onready var anim: AnimatedSprite2D = $Anim

var state: CaravanState = CaravanState.CART
var direction: String = "down"
var speed: float = 0.0

func _ready() -> void:
    _setup_frames()
    _apply()

func _setup_frames() -> void:
    if anim.frames != null:
        return
    var frames := SpriteFrames.new()
    var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
    img.fill(Color.WHITE)
    var tex := ImageTexture.create_from_image(img)
    var states = ["cart", "cart_horse", "wagon_2h", "camels", "broken", "hidden"]
    var dirs = ["up", "down", "left", "right"]
    var modes = ["idle", "walk"]
    for s in states:
        for d in dirs:
            for m in modes:
                var anim_name = "%s_%s_%s" % [s, d, m]
                frames.add_animation(anim_name)
                frames.add_frame(anim_name, tex)
    anim.frames = frames

func set_state(p_state: CaravanState) -> void:
    state = p_state
    _apply()

func set_direction(p_dir: String) -> void:
    direction = p_dir
    _apply()

func set_speed(p_speed: float) -> void:
    speed = p_speed
    _apply()

func _apply() -> void:
    if anim.frames == null:
        return
    var state_name := match state:
        CaravanState.CART: "cart"
        CaravanState.CART_HORSE: "cart_horse"
        CaravanState.WAGON_2H: "wagon_2h"
        CaravanState.CAMELS: "camels"
        CaravanState.BROKEN: "broken"
        CaravanState.HIDDEN: "hidden"
        _: "cart"
    var mode := "idle" if abs(speed) < 0.01 else "walk"
    var anim_name := "%s_%s_%s" % [state_name, direction, mode]
    if anim.frames.has_animation(anim_name):
        anim.play(anim_name)
    anim.speed_scale = max(0.01, abs(speed))
    if state == CaravanState.BROKEN:
        anim.modulate = Color(1, 0.3, 0.3)
    elif state == CaravanState.HIDDEN:
        anim.modulate = Color(1, 1, 1, 0.3)
    else:
        anim.modulate = Color(1, 1, 1, 1)
