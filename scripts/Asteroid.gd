extends Area2D

const SHOOT_PUSH_FACTOR: float = 0.3

var explosion_scene = preload("res://scenes/explosion.tscn")
export var move_speed: Vector2 = Vector2(100.0, 0.0)
export var health: int = 1
var base_speed: Vector2 = Vector2.ZERO
var is_destroyed = false
signal destroyed
var spawn_rotation: float = 0
var move_mod: float = 1
onready var SpriteColorShader = preload("res://Shaders/SpriteColorDeMierda.shader")

func _ready():
	init_material()
	
	add_to_group("enemies");
	$destroyed_sound.connect("finished", self, "_on_destroyedsnd_finished")
	$Sprite.rotation_degrees = spawn_rotation
	if self.scale.x <= 1.10:
		$Sprite.play("small")
		$Sprite.scale = Vector2(1.0, 1.0)
	elif self.scale.x <= 1.6:
		$Sprite.play("medium")
		$Sprite.scale = Vector2(0.5, 0.5)
	else:
		$Sprite.play("big")
		$Sprite.scale = Vector2(0.25, 0.25)

func init_material():
	$Sprite.material = ShaderMaterial.new()
	$Sprite.material.shader = SpriteColorShader
	$Sprite.get_material().set_shader_param("new", Color("ffffff"))
	
func _on_destroyedsnd_finished():
	call_deferred("queue_free")

func _physics_process(delta):
	if !is_destroyed:
		position-=delta*(move_speed*move_mod+base_speed)
		if position.x <= -100:
			call_deferred("queue_free")

func destroy():
	if is_destroyed:
		return;
	is_destroyed = true

	$destroyed_sound.play();
	$hit_zone.set_deferred("disabled", true)
	$Sprite.hide()
	emit_signal("destroyed") # Call it here and not in exit_tree...
	#call_deferred("queue_free")
	var stage_node = get_parent()
	if !is_instance_valid(stage_node):
		print("[WARNING] Invalid instance at Asteroid::destroy")
		return
	var explosion_instance = explosion_scene.instance()
	explosion_instance.position = position
	stage_node.call_deferred("add_child", explosion_instance)

func hit():
	health-=1;
	move_mod*=1.0-SHOOT_PUSH_FACTOR/scale.length();
	$AnimationPlayer.play("hit");

func _on_asteroid_area_entered(area):
	if !is_instance_valid(area):
		print("Invalid instance at _on_asteroid_area_entered")
		return;
	if area.is_in_group("shot"):
		hit();
		if area.has_method("destroy"):
			area.destroy();
	if !is_destroyed && health <= 0:
		destroy();

func _on_asteroid_body_entered(body):
	if !is_instance_valid(body):
		print("Invalid instance at _on_asteroid_body_entered")
		return;
	health = 0;
	if body.has_method("hit"):
		body.hit();
	if !is_destroyed && health <= 0:
		destroy();

func on_level_speed_changed(new_speed):
	base_speed = new_speed

func blink_on():
	$Sprite.get_material().set_shader_param("enabled", true)

func blink_off():
	$Sprite.get_material().set_shader_param("enabled", false)
