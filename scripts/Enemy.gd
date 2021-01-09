extends Area2D

const FOLLOW_PATH_SPEED: float = 50.0
const WAIT_IN_PATH_TIME: float = 1.5
const MIN_SHOOT_SPEED: float = 60.0
const MAX_SHOOT_SPEED: float = 300.0
const ACCEL_SPEED: float = 70.0
const MIN_SLIDE_SPEED: float = 50.0
const MAX_SLIDE_SPEED: float = 80.0
const SLID_DESACCEL: float = 45.0
const SCREEN_MARGIN: float = 8.0

var explosion_scene: PackedScene = preload("res://scenes/explosion.tscn");
var shoot_scene: PackedScene = preload("res://scenes/shot.tscn");
export var move_speed: Vector2 = Vector2(70.0, 0.0);
export var health: int = 3;
export var fire_rate: float = 1.0;

var slide_velocity: Vector2 = Vector2.ZERO
var fire_shoot_speed: float = 50.0
var is_on_viewport = false
var is_destroyed = false;
var base_speed: Vector2 = Vector2.ZERO
var ignore_base_velocity: bool = false
var double_shoot: bool = false

# Path nodes movement stuff
var paths_to_follow: Array = []
var local_path_position: Vector2 = Vector2.ZERO
var current_path_to_follow: int = -1
var current_path_following: Dictionary = {
	pathindex = -1,
	nextpoint = 0,
	prevpos = Vector2.ZERO,
	direction = Vector2.ZERO
}

var rng: RandomNumberGenerator = RandomNumberGenerator.new();

signal destroyed;

func _ready():
	init_difficulty() #This first because it sets the timer fire_rate
		
	self.connect("area_entered", self, "_on_enemy_area_entered");
	self.connect("body_entered", self, "_on_enemy_body_entered");
	$slide_timer.connect("timeout", self, "_on_slide_timeout")
	$shoot_timer.connect("timeout", self, "_on_shoot_timer_timeout");
	$shoot_timer.start(fire_rate);
	$slide_timer.start(1.0)
	$Sprite.play("idle")
	add_to_group("enemies");
	init_paths()
	init_colors()

func _on_slide_timeout():
	if !is_in_screen_height(global_position.y):
		return # avoid undesired bug while a shipt was already out of screen
	if rng.randi()%100 <= 15:
		var new_slide_speed: int = rng.randf_range(MIN_SLIDE_SPEED, MAX_SLIDE_SPEED)
		if rng.randi()%100 <= 50:
			slide_velocity = Vector2(0.0, new_slide_speed)
		else:
			slide_velocity = Vector2(0.0, -new_slide_speed)

func is_in_screen_height(position_y: int) -> bool:
	return position_y >= SCREEN_MARGIN and position_y <= (Game.SCREEN_HEIGHT-SCREEN_MARGIN)

func update_slide_vel(delta):
	if slide_velocity.x > 0.0:
		slide_velocity.x = clamp(slide_velocity.x - SLID_DESACCEL*delta, 0.0, slide_velocity.x)
	elif slide_velocity.x < 0.0:
		slide_velocity.x = clamp(slide_velocity.x + SLID_DESACCEL*delta, slide_velocity.x, 0.0)
	if slide_velocity.y > 0.0:
		slide_velocity.y = clamp(slide_velocity.y - SLID_DESACCEL*delta, 0.0, slide_velocity.y)
	elif slide_velocity.y < 0.0:
		slide_velocity.y = clamp(slide_velocity.y + SLID_DESACCEL*delta, slide_velocity.y, 0.0)
		
func init_difficulty():
	fire_shoot_speed = clamp(32.0*float(health), MIN_SHOOT_SPEED, MAX_SHOOT_SPEED)
	if health > 6: #Nightmare of enemy...
		double_shoot = true
		fire_rate*=1.5 #Otherwise this is unfair as hell
		
func init_colors():
	# To help the player know how hard is the enemy that is facing
	if health <= 2:
		$Sprite.modulate = Color("#ffffff")
	elif health > 2 and health <=4:
		$Sprite.modulate = Color("#ca7593")
	elif health > 4 and health <=6:
		$Sprite.modulate = Color("#f6d605")
	elif health > 6 and health <=8:
		$Sprite.modulate = Color("#40f360")
	else:
		$Sprite.modulate = Color("#007cff")

#####################
# START PATH NODES MOVEMENT
######################

func init_paths():
	var paths = $Paths.get_children()
	var i: int = 0
	for path in paths:
		var points = path.get_children()
		paths_to_follow.append([])
		for point in points:
			assert(point is Position2D)
			paths_to_follow[i].append(point.position)
		i+=1

func get_paths_count() -> int:
	return paths_to_follow.size()

func process_path(path_to_follow: int, delta: float):
	if path_to_follow == -1:
		return Vector2.ZERO
	update_path(path_to_follow)
	follow_path(path_to_follow, delta)

func update_path(path_index: int): 
	var path_selected: Array = paths_to_follow[path_index]
	var points_count: int = path_selected.size()
	if current_path_following.pathindex != path_index: #New path to follow selected
		current_path_following.pathindex = path_index
		var closest_index: int = 0
		for i in range(points_count):
			if path_selected[i].distance_to(local_path_position) < path_selected[closest_index].distance_to(local_path_position):
				closest_index = i
		current_path_following.nextpoint = closest_index
		current_path_following.direction = (path_selected[closest_index] - local_path_position).normalized()

func follow_path(path_index: int, delta: float):
	var path_selected: Array = paths_to_follow[path_index]
	var next_point_pos: Vector2 = path_selected[current_path_following.nextpoint]
	var distance_to_pos: Vector2 = next_point_pos - local_path_position
	var new_position: Vector2 = Vector2.ZERO
	new_position = local_path_position + current_path_following.direction*FOLLOW_PATH_SPEED*delta

	local_path_position = new_position
	# we use squared for performance (to avoid sqrt)
	if new_position.distance_squared_to(next_point_pos) <= pow(FOLLOW_PATH_SPEED*delta+0.2, 2.0): #Allow small margin of error
		move_to_next_path_point(path_index)

func move_to_next_path_point(path_index:int):
	var path_selected: Array = paths_to_follow[path_index]
	var points_count: int = path_selected.size()

	current_path_following.nextpoint+=1
	if current_path_following.nextpoint >= points_count:
		current_path_following.nextpoint = 0
	current_path_following.direction = (path_selected[current_path_following.nextpoint] - local_path_position).normalized()

#####################
# END PATH NODES MOVEMENT
######################

func get_current_vel() -> Vector2:
	var velocity: Vector2 = Vector2.ZERO
	if ignore_base_velocity:
		velocity = -move_speed
	else:
		velocity = -move_speed-base_speed
	
	if current_path_to_follow >= 0 and is_on_viewport:
		velocity+=current_path_following.direction*FOLLOW_PATH_SPEED
	
	velocity+= slide_velocity
	return velocity

func modulate_sprite(new_color: Color) -> void:
	$Sprite.modulate = new_color

func _physics_process(delta):
	if !is_destroyed:
		if global_position.x > 0 and global_position.x <= Game.SCREEN_WIDTH:
			is_on_viewport = true
		else:
			is_on_viewport = false
		
		update_slide_vel(delta)
		move(delta)
		update_anim()
		if position.x <= -100:
			call_deferred("queue_free");

func move(delta):

	#var velocity: Vector2 = Vector2.ZERO
	var new_position: Vector2 = position
	process_path(current_path_to_follow, delta)
	new_position+=get_current_vel()*delta
	if !is_in_screen_height(new_position.y):
		if current_path_to_follow >= 0 or slide_velocity.length_squared() > 1.0:
			new_position.y = clamp(new_position.y, SCREEN_MARGIN, Game.SCREEN_HEIGHT-SCREEN_MARGIN)
			if current_path_to_follow >= 0:
				move_to_next_path_point(current_path_to_follow)
			if slide_velocity.length_squared() > 1.0:
				slide_velocity = -slide_velocity
	position = new_position

func update_anim():
	if (get_current_vel()+base_speed).length_squared() > pow(ACCEL_SPEED, 2.0): #Squared for performance
		$Sprite.play("accelerate")
	else:
		$Sprite.play("idle")

func destroy():
	if is_destroyed:
		return;
	is_destroyed = true;
	emit_signal("destroyed"); # Call it here and not in exit_tree...
	call_deferred("queue_free");
	var stage_node = get_parent();
	if !is_instance_valid(stage_node):
		print("[WARNING] invalid instance at enemy::destroy")
		return
	var explosion_instance = explosion_scene.instance();
	explosion_instance.position = position;
	#stage_node.add_child(explosion_instance);
	stage_node.call_deferred("add_child", explosion_instance)

func _on_enemy_area_entered(area):
	if (area is Projectile) and (!area.fired_by or typeof(area.fired_by) == TYPE_NIL or area.fired_by is Player):
		health-=1;
		#$AnimationPlayer.play("hit");
		area.destroy();
	if !is_destroyed && health <= 0:
		destroy();

func _on_enemy_body_entered(body):
	health = 0;
	body.hit();
	if !is_destroyed && health <= 0:
		destroy();

func _on_shoot_timer_timeout():
	if position.x > Game.SCREEN_WIDTH:
		return;
	var parent_node = get_parent();
	if !is_instance_valid(parent_node):
		print("[WARNING] invalid instance at enemy::_on_shoot_timer_timeout")
		return
	var min_speed = get_current_vel().x if (-get_current_vel().x >  base_speed.x) else -base_speed.x
	var shoot_instance: Projectile = shoot_scene.instance();
	var shoot_velocity: Vector2 = Vector2(-fire_shoot_speed+min_speed, 0.0);
	shoot_velocity.x = clamp(shoot_velocity.x, -MAX_SHOOT_SPEED, -fire_shoot_speed+min_speed)
	if double_shoot:
		var shoot_instanceB: Projectile = shoot_scene.instance();
		shoot_instanceB.motion = shoot_velocity
		#f70000
		shoot_instanceB.modulate = Color("ffdd00"); 
		shoot_instanceB.fired_by = self;
		shoot_instanceB.mute(); #silly fix to avoid duplicated sound that's annoying
		shoot_instance.position = position+Vector2(-9, -5);
		shoot_instanceB.position = position+Vector2(-9, 5);
		parent_node.call_deferred("add_child", shoot_instanceB);
	else:
		shoot_instance.position = position+Vector2(-9, 0);

	shoot_instance.modulate = Color("ffdd00"); 
	shoot_instance.fired_by = self;
	shoot_instance.motion = shoot_velocity
	parent_node.call_deferred("add_child", shoot_instance);

func on_level_speed_changed(new_speed):
	base_speed = new_speed
