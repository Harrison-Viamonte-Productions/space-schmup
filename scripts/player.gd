class_name Player
extends KinematicBody2D

const SPACE_SIZE = 20.0;
const MOVE_SPEED = 100.0;
const CLIENT_FOLLOW_SPEED = 8.0;
const RESPAWN_DURATION = 6;
const SPAWN_PROTECTION_DURATION = 3.0;

signal destroyed;
signal revived;

var is_alive = true;
var can_shoot = true;
var double_shoot = false;
var nickname = "player"

var explosion_scene = preload("res://scenes/explosion.tscn");
var shot_scene = preload("res://scenes/shot.tscn");
var snapshotData: Dictionary = {pos = Vector2()};
var spawn_protection_time: float = SPAWN_PROTECTION_DURATION;
var respawn_time: float = 0;
var direction: Vector2 = Vector2.ZERO;

func _ready():
	add_to_group("network_nodes");
	$name.text = nickname
	snapshotData.pos = self.global_position;

# Main player frame
func _physics_process(delta):
	if spawn_protection_time > 0.0:
		spawn_protection_time-=delta;
		if $sprite.modulate.a == 1:
			$sprite.modulate.a = 0.5
		else:
			$sprite.modulate.a = 1
	else:
		$sprite.modulate.a = 1
	if not is_alive:
		respawn_time-=delta;
		$respawn_timer.text = str(int(respawn_time));
		if respawn_time <= 0:
			rpc("_on_revived")
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
	global_position = global_position.linear_interpolate(snapshotData.pos, delta * CLIENT_FOLLOW_SPEED);
	adjust_position_to_bounds();

func think(delta):
	handle_input();
	move(delta);
	adjust_position_to_bounds();

func handle_input():
	direction = Vector2.ZERO;
	if not is_alive:
		return
	if Input.is_key_pressed(KEY_SPACE) && can_shoot:
		rpc_unreliable("shoot_missile", (Game.score >= 50));
		can_shoot = false;
		get_node("reload_timer").start();
	if Input.is_key_pressed(KEY_UP):
		direction.y -= 1.0;
	if Input.is_key_pressed(KEY_DOWN):
		direction.y += 1.0;
	if Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0;
	if Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0;

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
	move_and_slide(MOVE_SPEED*direction);

func adjust_position_to_bounds():
	position.x = clamp(position.x, SPACE_SIZE/2.0, Game.SCREEN_WIDTH-SPACE_SIZE/2.0);
	position.y = clamp(position.y, SPACE_SIZE/2.0, Game.SCREEN_HEIGHT-SPACE_SIZE/2.0);

func _on_reload_timer_timeout():
	can_shoot = true;

sync func _on_revived():
	if not is_alive:
		is_alive = true
		$sprite.show()
		$hit_zone.set_deferred("disabled", false)
		$respawn_timer.hide()
		respawn_time = 0
		spawn_protection_time = SPAWN_PROTECTION_DURATION
		emit_signal("revived");

sync func _on_destroyed():
	if is_alive && spawn_protection_time <= 0.0:
		var stage_node = get_parent();
		var explosion_instance = explosion_scene.instance();
		explosion_instance.position = position;
		stage_node.add_child(explosion_instance);
		is_alive = false;
		$sprite.hide()
		$hit_zone.set_deferred("disabled", true)
		$respawn_timer.show()
		respawn_time = RESPAWN_DURATION
		emit_signal("destroyed");

func hit_by_asteroid():
	if is_network_master() && is_alive:
		rpc("_on_destroyed");

func _exit_tree():
	remove_from_group("network_nodes");
