extends SpringArm3D
 
## ---------------------------------------------------------
## CAMERA MOUSE LOOK (for the SpringArm3D chase camera)
## Lets the player look left/right up to a max angle with the
## mouse, independent of the skater's facing direction. The
## look offset resets toward center when the mouse is idle... 
## actually it does NOT auto-recenter here (see note below) —
## it just clamps to the max angle, like glancing over your
## shoulder while still steering normally with A/D.
## Attach directly to the SpringArm3D node (the one that's a
## child of the skater, with Camera3D as its child).
## ---------------------------------------------------------
 
@export var look_sensitivity: float = 0.005      # mouse movement -> radians
@export var max_look_angle_degrees: float = 30.0 # clamp range, left and right
 
var look_yaw: float = 0.0       # current look offset, in radians
var base_rotation_y: float = 0.0 # the SpringArm3D's original authored rotation (e.g. facing behind the skater)
 
func _ready() -> void:
	base_rotation_y = rotation.y
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
 
 
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		look_yaw -= event.relative.x * look_sensitivity
		var max_rad: float = deg_to_rad(max_look_angle_degrees)
		look_yaw = clamp(look_yaw, -max_rad, max_rad)
 
	# Optional: press Escape to release the mouse cursor (e.g. for menus/debugging).
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
 
 
func _process(_delta: float) -> void:
	# Apply the look offset on top of the SpringArm3D's base rotation, so it's always
	# relative to "straight behind the skater," not relative to world space.
	rotation.y = base_rotation_y + look_yaw
