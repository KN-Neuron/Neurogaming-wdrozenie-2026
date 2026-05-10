extends Camera2D

@export var speed: float = 2000.0 
@export var zoom_speed: float = 2.0 

func _process(delta: float) -> void:
	var direction := Vector2.ZERO
	
	if Input.is_action_pressed("ui_right"): direction.x += 1
	if Input.is_action_pressed("ui_left"): direction.x -= 1
	if Input.is_action_pressed("ui_down"): direction.y += 1
	if Input.is_action_pressed("ui_up"): direction.y -= 1

	position += direction.normalized() * speed * delta

	if Input.is_physical_key_pressed(KEY_E):
		zoom -= Vector2(zoom_speed, zoom_speed) * delta
	if Input.is_physical_key_pressed(KEY_Q):
		zoom += Vector2(zoom_speed, zoom_speed) * delta
		
	zoom = zoom.clamp(Vector2(0.1, 0.1), Vector2(5.0, 5.0))
