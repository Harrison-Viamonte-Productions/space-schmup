extends Node2D

var is_game_over = false;
var asteroid = preload("res://scenes/Asteroid.tscn");
const SCREEN_WIDTH = 320;
const SCREEN_HEIGHT = 180;
var score: int = 0;
var players_alive: int = 0;

func _ready():
	$ui/retry.hide();

func _input(event):
	if Input.is_key_pressed(KEY_ESCAPE):
		get_tree().quit();
	if is_game_over && Input.is_key_pressed(KEY_ENTER) && is_network_master():
		Game.rpc("restart_game");

func _on_player_destroyed():
	players_alive-=1;
	if players_alive <= 0:
		is_game_over = true;
		$ui/retry.show();

func _on_spawn_timer_timeout():
	if !is_network_master():
		return;
	var difficulty = round(log_2(float(score+1))+0.51);
	var scaleMax = 1.0+log_4(float(score+1))/6.0;
	var asteroids: Array = [];
	for i in range(int(rand_range(1.0, float(difficulty)))):
		var newScale = rand_range(1.0, scaleMax);
		var asteroid_info: Dictionary = { pos = Vector2.ZERO, speed = 0.0, scale = Vector2.ZERO, health = 0};
		asteroid_info.pos = Vector2(SCREEN_WIDTH + 32, rand_range(0, SCREEN_HEIGHT));
		asteroid_info.speed = rand_range(50.0, 50.0+30.0*difficulty);
		asteroid_info.scale = Vector2(newScale, newScale);
		asteroid_info.health = round((newScale-1.0)*6.0+2.0);
		asteroids.append(asteroid_info);
	
	rpc("spawn_asteroids", asteroids);

sync func spawn_asteroids(asteroids: Array):
	#print(asteroids.size());
	for ast in asteroids:
		var asteroid_instance: Node2D = asteroid.instance();
		if is_network_master():
			asteroid_instance.position = ast.pos;
		else:
			asteroid_instance.position = ast.pos - Vector2(ast.speed*clamp(Game.PingUtil.get_latency(), 0.0, Game.PingUtil.MAX_CLIENT_LATENCY), 0.0); 
		asteroid_instance.move_speed = ast.speed;
		asteroid_instance.health = ast.health;
		asteroid_instance.scale = ast.scale;
		asteroid_instance.connect("score", self, "_on_player_score");
		add_child(asteroid_instance);

func _on_player_score():
	score += 1;
	if is_network_master():
		rpc("update_score", score);

sync func update_score(new_score):
	score = new_score;
	Game.score = new_score;
	get_node("ui/score").text = "Score: " + str(score);

func log_2(val: float) -> float:
	return log(val)/log(2.0);

func log_4(val: float) -> float:
	return log(val)/log(4.0);

func update_latency(new_latency: float):
	$ui/Log.text = str(round(new_latency*1000.0)) + "ms";
