class_name Projectile
extends Area2D

var particles_scene: PackedScene = preload("res://scenes/Particles/ShootFX.tscn");
var is_playing_sound: bool = true;
var is_destroyed: bool = false;
var fired_by_enemy: bool = false;
var motion: Vector2 = Vector2.ZERO;

func mute():
	$FireSound.set_volume_db(-1000.0); #FIXME: this is just turning the volume really low :S

func set_fired_by_enemy(val: bool):
	fired_by_enemy = val

func is_fired_by_enemy() -> bool:
	return fired_by_enemy

func _ready():
	$FireSound.connect("finished", self, "_sound_finished");
	$FireSound.play();
	add_to_group("projectiles")

func _sound_finished():
	is_playing_sound = false;

func _process(delta):
	if !is_destroyed:
		position += motion*delta;
		if (position.x >= Game.SCREEN_WIDTH+8) or (position.x < -8):
			is_destroyed = true;

	if is_destroyed and !is_playing_sound: #To avoid sound problems.
		call_deferred("queue_free");

func destroy():
	set_deferred("monitorable", false)
	set_deferred("monitoring", false)
	$sprite.hide();
	is_destroyed = true;
	var particle_fx: Node2D = particles_scene.instance();
	particle_fx.global_position = self.global_position;
	get_parent().add_child(particle_fx);

func _on_shot_area_entered(area):
	if !is_instance_valid(area):
		print("Invalid instance at _on_shot_area_entered")
		return;
	if area.is_in_group("asteroid"):
		pass;

func _on_shot_body_entered(body):
	if !is_instance_valid(body):
		print("Invalid instance at _on_shot_area_entered")
		return;
	if !fired_by_enemy and body.is_in_group("players"):
		return;
	if body.has_method("hit"):
		body.hit(); #Fix later

func _exit_tree():
	remove_from_group("projectiles")
