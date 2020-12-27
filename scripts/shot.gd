class_name Projectile
extends Area2D

const SCREEN_WIDTH = 320;
const MOVE_SPEED = 500.0;

var particles_scene: PackedScene = preload("res://scenes/Particles/ShootFX.tscn");
var is_playing_sound: bool = true;
var is_destroyed: bool = false;

func mute():
	$FireSound.set_volume_db(-1000.0); #FIXME: this is just turning the volume really low :S

func _ready():
	$FireSound.connect("finished", self, "_sound_finished");
	$FireSound.play();

func _sound_finished():
	is_playing_sound = false;

func _process(delta):
	if !is_destroyed:
		position += Vector2(MOVE_SPEED*delta, 0.0);
		if (position.x >= SCREEN_WIDTH+8):
			is_destroyed = true;

	if is_destroyed and !is_playing_sound: #To avoid sound problems.
		call_deferred("queue_free");

func destroy():
	collision_layer = 0; # Disable collisions jut in case
	collision_mask = 0;
		
	#call_deferred("queue_free");
	$sprite.hide();
	is_destroyed = true;
	var particle_fx: Node2D = particles_scene.instance();
	particle_fx.global_position = self.global_position;
	get_parent().add_child(particle_fx);

func _on_shot_area_entered(area):
	if area.is_in_group("asteroid"):
		pass;
