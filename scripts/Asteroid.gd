extends Area2D

var explosion_scene = preload("res://scenes/explosion.tscn");

export var move_speed: float = 100.0;
export var health: int = 1;
var is_destroyed = false;
signal destroyed;
var spawn_rotation: float = 0;

func _ready():
	add_to_group("enemies");
	$sprite.rotation_degrees = spawn_rotation;

func _process(delta):
	position-=Vector2(move_speed*delta, 0.0);
	if position.x <= -100:
		call_deferred("queue_free");

func _draw():
	pass;

func destroy():
	if is_destroyed:
		return;
	is_destroyed = true;
	emit_signal("destroyed"); # Call it here and not in exit_tree...
	call_deferred("queue_free");
	var stage_node = get_parent();
	var explosion_instance = explosion_scene.instance();
	explosion_instance.position = position;
	stage_node.add_child(explosion_instance);

func _on_asteroid_area_entered(area):
	if area.is_in_group("shot"):
		health-=1;
		$AnimationPlayer.play("hit");
		area.destroy();
	if !is_destroyed && health <= 0:
		destroy();

func _on_asteroid_body_entered(body):
	health = 0;
	body.hit_by_asteroid();
	if !is_destroyed && health <= 0:
		destroy();
