extends AnimatedSprite

const MIN_SPEED: float = 1.0

func _ready():
	play("idle")
	
func update_anim(vel: Vector2):
	if vel.y < -MIN_SPEED:
		play("roll_left")
	elif vel.y > MIN_SPEED: #
		play("roll_right")
	else:
		play("idle")
