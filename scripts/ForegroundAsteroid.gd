extends AnimatedSprite

const MIN_VELOCITY: Vector2 = Vector2(-50.0, -10.0)
const MAX_VELOCITY: Vector2 = Vector2(-5.0, 10.0)

var velocity: Vector2 = Vector2.ZERO
var base_velocity: Vector2 = Vector2.ZERO
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready():
	rng.randomize()
	random_pos_and_vel()

func random_pos_and_vel():
	position.x = rng.randf_range(Game.SCREEN_WIDTH+64.0, Game.SCREEN_WIDTH*5)
	position.y = rng.randf_range(0, Game.SCREEN_HEIGHT)
	velocity.x = rng.randf_range(MIN_VELOCITY.x, MAX_VELOCITY.x)
	velocity.y = rng.randf_range(MIN_VELOCITY.y, MAX_VELOCITY.y)
	var new_scale: float = rng.randf_range(0.2, 0.9)
	scale = Vector2(new_scale, new_scale)
	
func _physics_process(delta):
	position += (velocity + base_velocity)*delta
	if position.x <= -100.0:
		random_pos_and_vel()

func _on_speed_updated(new_speed):
	base_velocity = -new_speed
