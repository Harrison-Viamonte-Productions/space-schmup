extends Node2D

var is_game_over = false;
var asteroid = preload("res://scenes/Asteroid.tscn");
const SCREEN_WIDTH = 320;
const SCREEN_HEIGHT = 180;
var score: int = 0;
var players_alive: int = 0;

var rng: RandomNumberGenerator = RandomNumberGenerator.new();

func _ready():
	# Let's implement the snapshot code in the stage and not in the singleton, because I am using Godot way of doing netcode
	# not the one I tend to uses, and requires to have everything sync, so since this scene it's synced (while the singleton it's not)
	# I prefer to have this here just in case....
	clear_stage();
	var SnapshotTimer: Timer = Timer.new();
	SnapshotTimer.set_wait_time(Game.SNAPSHOT_DELAY);
	SnapshotTimer.set_one_shot(false);
	SnapshotTimer.connect("timeout", self, "_on_snapshot");
	self.add_child(SnapshotTimer);
	SnapshotTimer.start();
	
	$ui/retry.hide();

func clear_stage():
	rng.randomize();

func _on_snapshot():
	get_tree().call_group("network_nodes","_on_snapshot");

func _input(event):
	if Input.is_key_pressed(KEY_ESCAPE):
		get_tree().quit();
	if is_game_over && Input.is_key_pressed(KEY_ENTER) && is_network_master():
		rpc("restart_map");

sync func restart_map():
	get_tree().call_group("enemies", "call_deferred", "queue_free");
	score = 0;
	Game.score = 0;
	is_game_over = false;
	Game.spawn_players(self);
	$ui/retry.hide();
	update_score(0);

func _on_player_destroyed():
	players_alive-=1;
	if players_alive <= 0:
		is_game_over = true;
		$ui/retry.show();

func _on_spawn_timer_timeout():
	if !is_network_master():
		return;
	rpc("spawn_asteroids", score, rng.get_seed()); #With the randomg seed it's enough to spawn the exact same asteroids and enemies in the client pc

sync func spawn_asteroids(current_score: int, new_seed: int):
	
	rng.set_seed(new_seed); # GOLD <3
	
	var difficulty = round(log_2(float(current_score+1))+0.51);
	var scaleMax = 1.0+log_4(float(current_score+1))/6.0;
	var asteroids: Array = [];
	for i in range(int(rng.randf_range(1.0, float(difficulty)))):
		var newScale = rng.randf_range(1.0, scaleMax);
		var spawn_pos: Vector2 = Vector2(SCREEN_WIDTH + 32, rng.randf_range(0, SCREEN_HEIGHT));
		var spawn_speed: float = rng.randf_range(50.0, 50.0+30.0*difficulty);
		var asteroid_instance: Node2D = asteroid.instance();
		if is_network_master():
			asteroid_instance.position = spawn_pos;
		else:
			asteroid_instance.position = spawn_pos - Vector2(spawn_speed*clamp(Game.PingUtil.get_latency(), 0.0, Game.PingUtil.MAX_CLIENT_LATENCY), 0.0); 
		asteroid_instance.move_speed = spawn_speed;
		asteroid_instance.health = round((newScale-1.0)*6.0+2.0);
		asteroid_instance.scale = Vector2(newScale, newScale);
		asteroid_instance.connect("destroyed", self, "_on_player_score");
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
