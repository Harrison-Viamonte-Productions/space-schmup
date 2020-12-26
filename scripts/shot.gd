extends Area2D

const SCREEN_WIDTH = 320;
const MOVE_SPEED = 500.0;

var particles_scene: PackedScene = preload("res://scenes/Particles/ShootFX.tscn");

func _process(delta):
	position += Vector2(MOVE_SPEED*delta, 0.0);
	if (position.x >= SCREEN_WIDTH+8):
		queue_free();


func destroy():
	collision_layer = 0; # Disable collisions jut in case
	collision_mask = 0;
		
	call_deferred("queue_free");
	var particle_fx: Node2D = particles_scene.instance();
	particle_fx.global_position = self.global_position;
	get_parent().add_child(particle_fx);

func _on_shot_area_entered(area):
	if area.is_in_group("asteroid"):
		pass;
