extends Area2D

var explosion_scene = preload("res://scenes/explosion.tscn");
export var move_speed: Vector2 = Vector2(100.0, 0.0);
export var health: int = 1;
var is_destroyed = false;
signal destroyed;
var spawn_rotation: float = 0;

func _ready():
	add_to_group("enemies");
	$destroyed_sound.connect("finished", self, "_on_destroyedsnd_finished");
	$sprite.rotation_degrees = spawn_rotation;

func _on_destroyedsnd_finished():
	call_deferred("queue_free");

func _process(delta):
	if !is_destroyed:
		position-=delta*move_speed;
		if position.x <= -100:
			call_deferred("queue_free");

func destroy():
	if is_destroyed:
		return;
	is_destroyed = true;

	$destroyed_sound.play();
	$hit_zone.set_deferred("disabled", true);
	$sprite.hide();
	emit_signal("destroyed"); # Call it here and not in exit_tree...
	#call_deferred("queue_free");
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
	body.hit();
	if !is_destroyed && health <= 0:
		destroy();
