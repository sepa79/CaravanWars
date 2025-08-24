extends Node2D
class_name CaravanSprite

enum CaravanState { CART, CART_HORSE, WAGON_2H, CAMELS, BROKEN, HIDDEN }

@onready var anim: AnimatedSprite2D = $Anim

var state: CaravanState = CaravanState.CART
var direction: String = "down"
var speed: float = 0.0

# Jawnie typowany słownik (klucz: int/CaravanState, wartość: String)
const STATE_NAME: Dictionary[int, String] = {
	CaravanState.CART: "cart",
	CaravanState.CART_HORSE: "cart_horse",
	CaravanState.WAGON_2H: "wagon_2h",
	CaravanState.CAMELS: "camels",
	CaravanState.BROKEN: "broken",
	CaravanState.HIDDEN: "hidden",
}

func _ready() -> void:
	_setup_frames()
	_apply()

func _setup_frames() -> void:
	# Jeśli ramki już są przypisane, pomiń tworzenie
	if anim.sprite_frames != null:
		return
	var frames: SpriteFrames = SpriteFrames.new()
	var img: Image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	var states: Array[String] = ["cart", "cart_horse", "wagon_2h", "camels", "broken", "hidden"]
	var dirs: Array[String] = ["up", "down", "left", "right"]
	var modes: Array[String] = ["idle", "walk"]
	for s in states:
		for d in dirs:
			for m in modes:
				var anim_name: String = "%s_%s_%s" % [s, d, m]
				frames.add_animation(anim_name)
				frames.add_frame(anim_name, tex)
	anim.sprite_frames = frames

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
	if anim.sprite_frames == null:
		return

	var state_name: String = (STATE_NAME.get(state, "hidden") as String)
	var mode: String = "idle" if absf(speed) < 0.01 else "walk"
	var anim_name: String = "%s_%s_%s" % [state_name, direction, mode]

	if anim.sprite_frames.has_animation(anim_name):
		anim.play(anim_name)

	anim.speed_scale = maxf(0.01, absf(speed))

	if state == CaravanState.BROKEN:
		anim.modulate = Color(1, 0.3, 0.3)
	elif state == CaravanState.HIDDEN:
		anim.modulate = Color(1, 1, 1, 0.3)
	else:
		anim.modulate = Color(1, 1, 1, 1)
