extends Node2D

var is_game_over = false;
var asteroid = preload("res://scenes/Asteroid.tscn");
const SCREEN_WIDTH = 320;
const SCREEN_HEIGHT = 180;
var score = 0;

func restart_game():
	get_tree().set_network_peer(null);
	get_tree().change_scene("res://scenes/Lobby.tscn");


func _input(event):
	if Input.is_key_pressed(KEY_ESCAPE):
		get_tree().quit();
	if is_game_over && Input.is_key_pressed(KEY_ENTER):
		restart_game();

func _on_player_destroyed():
	pass;

func _on_spawn_timer_timeout():
	if !is_network_master():
		return;
	var difficulty = round(log_2(float(score+1))+0.51);
	var scaleMax = 1.0+log_4(float(score+1))/6.0;
	for i in range(int(rand_range(1.0, float(difficulty)))):
		var newScale = rand_range(1.0, scaleMax);
		rpc("spawn_asteroid", Vector2(SCREEN_WIDTH + 32, rand_range(0, SCREEN_HEIGHT)), rand_range(50.0, 50.0+30.0*difficulty),  Vector2(newScale, newScale), round((newScale-1.0)*6.0+2.0));

sync func spawn_asteroid(pos: Vector2, speed: float, scale: Vector2, health: int):
	var asteroid_instance: Node2D = asteroid.instance();
	if is_network_master():
		asteroid_instance.position = pos;
	else:
		asteroid_instance.position = pos - Vector2(speed*clamp(Game.client_latency, 0.0, Game.MAX_CLIENT_LATENCY), 0.0); 
	asteroid_instance.move_speed = speed;
	asteroid_instance.health = health;
	asteroid_instance.scale = scale;
	asteroid_instance.connect("score", self, "_on_player_score");
	add_child(asteroid_instance);

func _on_player_score():
	score += 1;
	if is_network_master():
		rpc("update_score", score);

sync func update_score(new_score):
	score = new_score;
	Game.score = new_score;
	print(score);
	get_node("ui/score").text = "Score: " + str(score);

func log_2(val: float) -> float:
	return log(val)/log(2.0);

func log_4(val: float) -> float:
	return log(val)/log(4.0);

func update_latency():
	$ui/Log.text = str(round(Game.client_latency*1000.0)) + "ms";
