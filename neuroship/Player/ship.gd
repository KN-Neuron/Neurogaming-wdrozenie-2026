extends RigidBody2D

@export var engine_power = 75
@export var turn_torque = 5000
@export var torque_ratio = 300
@export var lean_speed = 0.01
@export var lean_threshold_divisor = 50.0
@export var lean_factor = 2


@onready var ship_sprite = $Sprite2D

func _physics_process(_delta):
	var speed = linear_velocity.length()
	
	# UP
	if Input.is_action_pressed("forward"):
		apply_central_force(transform.x * engine_power)
		
	# DOWN
	if Input.is_action_pressed("backward") and speed > 50:
		apply_central_force(transform.x * -engine_power)
	
	# TURN
	var rotation_dir = Input.get_axis("left", "right")
	apply_torque(rotation_dir * turn_torque * (speed / torque_ratio + 2))
	
	# LEAN
	var heel_force = angular_velocity * speed 

	var lean_percent = clamp(abs(heel_force) / turn_torque * lean_threshold_divisor, 0.0, 1.0)
	
	var curved_tilt = pow(lean_percent, 3) * lean_factor * sign(heel_force)

	ship_sprite.skew = lerp(ship_sprite.skew, -curved_tilt, lean_speed)
