extends Enemy

# Sincronizar bien la vida del boss via online

func _ready():
	move_speed = Vector2.ZERO
	ignore_base_velocity = true
	current_path_to_follow = 0
	$Sprite.modulate = Color("#ffffff")
	health = 300


func _on_shoot_timer_timeout():
	if position.x > Game.SCREEN_WIDTH:
		return;
	var parent_node = get_parent();
	if !is_instance_valid(parent_node):
		print("[WARNING] invalid instance at enemy::_on_shoot_timer_timeout")
		return
	var min_speed = get_current_vel().x if (-get_current_vel().x >  base_speed.x) else -base_speed.x
	var shoot_velocity: Vector2 = Vector2(-fire_shoot_speed+min_speed, 0.0);
	shoot_velocity.x = clamp(shoot_velocity.x, -MAX_SHOOT_SPEED, -fire_shoot_speed+min_speed)
	for i in range(4):
		var shoot_instance: Projectile = shoot_scene.instance();
		shoot_instance.motion = shoot_velocity
		shoot_instance.modulate = Color("ffdd00")
		shoot_instance.set_fired_by_enemy(true)
		shoot_instance.position = position+Vector2(-7, -7+8*i)
		parent_node.call_deferred("add_child", shoot_instance)
