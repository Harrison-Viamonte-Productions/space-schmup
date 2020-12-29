extends Sprite

var scroll_speed = 0; # Set by the map

func _process(delta):
	position += Vector2(-scroll_speed*delta, 0.0);
	if (position.x <= -Game.SCREEN_WIDTH):
		position.x += Game.SCREEN_WIDTH;
