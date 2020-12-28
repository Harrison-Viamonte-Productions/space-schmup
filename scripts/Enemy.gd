extends Area2D

var explosion_scene: PackedScene = preload("res://scenes/explosion.tscn");
var shoot_scene: PackedScene = preload("res://scenes/shot.tscn");
export var move_speed: Vector2 = Vector2(100.0, 0.0);
export var health: int = 3;
export var fire_rate: float = 1.0;
var is_destroyed = false;
signal destroyed;


func _ready():
	self.connect("area_entered", self, "_on_enemy_area_entered");
	self.connect("body_entered", self, "_on_enemy_body_entered");
	$shoot_timer.connect("timeout", self, "_on_shoot_timer_timeout");
	$shoot_timer.start(fire_rate);
	add_to_group("enemies");
	$Sprite.rotation_degrees = rad2deg(atan2(move_speed.y, move_speed.x))+180;

func _process(delta):
	if !is_destroyed:
		position-=delta*move_speed;
		if position.x <= -100:
			call_deferred("queue_free");

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

func _on_enemy_area_entered(area):
	if (area is Projectile) and (!area.fired_by or typeof(area.fired_by) == TYPE_NIL or area.fired_by is Player):
		health-=1;
		#$AnimationPlayer.play("hit");
		area.destroy();
	if !is_destroyed && health <= 0:
		destroy();

func _on_enemy_body_entered(body):
	health = 0;
	body.hit_by_asteroid(); #actually change this to just "hit" probably in player
	if !is_destroyed && health <= 0:
		destroy();

func _on_shoot_timer_timeout():
	if position.x > Game.SCREEN_WIDTH:
		return;
	var parent_node = get_parent();
	var shoot_instance: Projectile = shoot_scene.instance();
	shoot_instance.modulate = Color(0.75, 0.25, 0.25); 
	shoot_instance.fired_by = self;
	shoot_instance.position = position+Vector2(-9, 0);
	shoot_instance.motion = Vector2(-200, move_speed.y);
	parent_node.call_deferred("add_child", shoot_instance);
	#parent_node.add_child(shoot_instance);
