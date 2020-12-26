class_name Player
extends KinematicBody2D

const SCREEN_WIDTH = 320;
const SCREEN_HEIGHT = 180;
const SPACE_SIZE = 20.0;
const MOVE_SPEED = 100.0;
const CLIENT_FOLLOW_SPEED = 8.0;

signal destroyed;

var is_alive = true;
var can_shoot = true;
var double_shoot = false;

var explosion_scene = preload("res://scenes/explosion.tscn");
var shot_scene = preload("res://scenes/shot.tscn");
var snapshotData: Dictionary = {pos = Vector2()};
var spawn_protection_time: float = 3.0;

func _ready():
	var timer: Timer = Timer.new();
	timer.set_wait_time(Game.SNAPSHOT_DELAY);
	timer.set_one_shot(false);
	timer.connect("timeout", self, "_on_snapshot");
	self.add_child(timer);
	timer.start();
	snapshotData.pos = self.global_position;

func _physics_process(delta):
	if spawn_protection_time > 0.0:
		spawn_protection_time-=delta;
	if is_network_master():
		think(delta);
	else:
		cs_think(delta);

remote func receive_snapshot(data: Dictionary):
	snapshotData = data;

func _on_snapshot():
	if !is_network_master():
		return;
	var sendData: Dictionary = {pos = Vector2()};
	sendData.pos = global_position;
	rpc_unreliable("receive_snapshot", sendData);

# Clientside think
func cs_think(delta):
	global_position = global_position.linear_interpolate(snapshotData.pos, delta * CLIENT_FOLLOW_SPEED)

func think(delta):
	move(delta);
	if Input.is_key_pressed(KEY_SPACE) && can_shoot:
		rpc_unreliable("shoot_missile", (Game.score >= 50));
		can_shoot = false;
		get_node("reload_timer").start();

sync func shoot_missile(is_double_shoot: bool):
	var stage_node = get_parent();
	var shot_instanceA: Node2D = shot_scene.instance();
	if is_double_shoot:
		var shot_instanceB: Node2D = shot_scene.instance();
		shot_instanceA.position = position+Vector2(9, -5);
		shot_instanceB.position = position+Vector2(9, 5);
		shot_instanceB.set_network_master(self.get_network_master());
		stage_node.add_child(shot_instanceB);
	else:
		shot_instanceA.position = position+Vector2(9, 0);
	shot_instanceA.set_network_master(self.get_network_master());
	stage_node.add_child(shot_instanceA);

func move(delta):
	var input_dir: Vector2 = Vector2.ZERO;
	if Input.is_key_pressed(KEY_UP):
		input_dir.y -= 1.0;
	if Input.is_key_pressed(KEY_DOWN):
		input_dir.y += 1.0;
	if Input.is_key_pressed(KEY_LEFT):
		input_dir.x -= 1.0;
	if Input.is_key_pressed(KEY_RIGHT):
		input_dir.x += 1.0;

	move_and_slide(MOVE_SPEED*input_dir);
	adjust_position_to_bounds();

func adjust_position_to_bounds():
	if position.x < (SPACE_SIZE/2.0):
		position.x = (SPACE_SIZE/2.0);
	elif position.x > (SCREEN_WIDTH-SPACE_SIZE/2.0):
		position.x = SCREEN_WIDTH-SPACE_SIZE/2.0;
	if position.y < (SPACE_SIZE/2.0):
		position.y = (SPACE_SIZE/2.0);
	elif position.y > (SCREEN_HEIGHT-SPACE_SIZE/2.0):
		position.y = SCREEN_HEIGHT-SPACE_SIZE/2.0;

func _on_reload_timer_timeout():
	can_shoot = true;

sync func _on_destroyed():
	if is_alive && spawn_protection_time <= 0.0:
		call_deferred("queue_free");
		var stage_node = get_parent();
		var explosion_instance = explosion_scene.instance();
		explosion_instance.position = position;
		stage_node.add_child(explosion_instance);
		is_alive = false;

func hit_by_asteroid():
	if is_network_master() && is_alive:
		rpc("_on_destroyed");

func _exit_tree():
	emit_signal("destroyed");
