extends Node2D

# #############################
# IMPORTANT KNOWLEDGE: For Netcode using RPC to work fine only
# Entities must have the EXACT same NodePath (that means all parents and the node itself need to have the very same name)
# So we cant to manually make sure and sync the node names to be the same in the client and server ALWAYS
# This is using original Godot way of doing netcode. (using Clockout's netcode, that's not necessary since
# the Game.Network singleton it's the only node dealing with rpc and it has an array with the only entities needed to be synced
# So, therefore, Clockout's way of doing netcode it's better for big projects.
# ############################

const POINT_PER_LIFE = 100;
const START_LIVES = 3;

var is_game_over = false;
var asteroid_scene = preload("res://scenes/Asteroid.tscn");
var enemy_scene = preload("res://scenes/Enemy.tscn");
var enemies_count: int = 0; #Important for netcode
var score: int = 0;
var players_alive: int = 0;
var lives = START_LIVES;
var difficulty_curve: float = 0.0;
var max_difficulty = 0;

#Procedural generation stuff
var asteroids_grid: CuteGrid = CuteGrid.new(16, Vector2(Game.SCREEN_WIDTH, Game.SCREEN_HEIGHT));
var enemies_grid: CuteGrid = CuteGrid.new(32, Vector2(Game.SCREEN_WIDTH, Game.SCREEN_HEIGHT));
var rng: RandomNumberGenerator = RandomNumberGenerator.new();

enum SPAWN_TYPE {
	ASTEROID,
	ENEMY
};

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
	update_lives(START_LIVES);

func clear_stage():
	difficulty_curve = 0.0
	max_difficulty = 0
	enemies_count = 0;
	rng.randomize();

sync func update_lives(new_lives: int):
	lives = new_lives;
	$ui/lives.text = "Lives: " + str(lives)
	if lives <= 0:
		Game.clear_players(self);
		is_game_over = true;
		if !is_network_master():
			$ui/retry.text = "Waiting for server to restart...";
		$ui/retry.show();

func _on_snapshot():
	get_tree().call_group("network_nodes","_on_snapshot");

func _input(event):
	var is_just_presssed: bool = event.is_pressed() && !event.is_echo();
	if Input.is_key_pressed(KEY_ESCAPE):
		get_tree().quit();

	if is_game_over && Input.is_key_pressed(KEY_ENTER) && is_network_master():
		rpc("restart_map");

sync func restart_map():
	get_tree().call_group("enemies", "call_deferred", "queue_free") #I think it is redundant to use call_deferred
	get_tree().call_group("projectiles", "call_deferred", "queue_free")
	score = 0;
	is_game_over = false;
	Game.spawn_players(self);
	$ui/retry.hide();
	update_score(0);
	clear_stage();
	update_lives(START_LIVES);

func _on_spawn_timer_timeout():
	if !is_network_master():
		return;
	rpc("generate_enemies", score, rng.get_seed()); #With the randomg seed it's enough to spawn the exact same asteroids and enemies in the client pc

sync func generate_enemies(current_score: int, new_seed: int):
	rng.set_seed(new_seed); # GOLD <3
	if max_difficulty == 0 or difficulty_curve == 0:
		max_difficulty = rng.randi_range(8.0, 12.0)
		difficulty_curve = rng.randf_range(0.4, 0.95)
	#var difficulty = round(log_2(float(current_score+1))/2.0+0.51);
	var difficulty = round(calculate_difficulty(float(current_score), 1000.0, max_difficulty))
	var scaleMax = 1.0+log_4(float(current_score+1))/6.0;
	var spawn_data: Array = [];
	enemies_grid.clear_grid(0); #0 being not used

	for i in range(int(rng.randf_range(1.0, float(difficulty)))):
		var spawnargs: Dictionary;
		var random_cell_pos: Vector2;
		if rng.randi_range(0, 100) < 25:
			var random_cell: Vector2 = enemies_grid.get_random_cell_filter(0, new_seed);
			random_cell_pos = enemies_grid.get_world_pos_from_cell_centered(random_cell);
			enemies_grid.set_cellv(random_cell, 1); #To avoid spawning two enemies in the very same position
			spawnargs = {
				idspawn = SPAWN_TYPE.ENEMY,
				pos =  Vector2(Game.SCREEN_WIDTH + random_cell_pos.x, random_cell_pos.y),
				fire_rate = rng.randf_range(0.5, 2.0),
				speed = Vector2(100.0, 0.0)
			};
			if rng.randi_range(0, 100) % 100 < 25:
				spawnargs.speed = Vector2(100.0, rng.randi_range(-10.0, 10.0));
		else:
			random_cell_pos = asteroids_grid.get_world_pos_from_cell_centered(asteroids_grid.get_random_cell(new_seed));
			spawnargs = {
				idspawn = SPAWN_TYPE.ASTEROID,
				scale = rng.randf_range(1.0, scaleMax),
				pos =  Vector2(Game.SCREEN_WIDTH + 32, random_cell_pos.y+rng.randi_range(-8, 8)), # add that little change to make it feel more natural
				speed = Vector2(rng.randf_range(50.0, 50+32.0*(difficulty-1))+rng.randf_range(-10.0, 10.0), rng.randi_range(-15.0, 15.0)),
				health = 0,
				rotation = rng.randi_range(-25, 25)
			};
			spawnargs.health = round((spawnargs.scale-1.0)*6.0+2.0);
		
		spawn_data.append(spawnargs);
	#We can do some post-proccess here if we want before spawning the enemies!
	#post_process()....	
	spawn_enemies(spawn_data);

func get_enemy_from_spawnargs(spawnargs: Dictionary) -> Node2D:
	var spawn_instance: Node2D;
	match spawnargs.idspawn:
		SPAWN_TYPE.ENEMY:
			spawn_instance = enemy_scene.instance();
			spawn_instance.set_name(str(enemies_count));
			if is_network_master():
				spawn_instance.position = spawnargs.pos;
			else:
				spawn_instance.position = spawnargs.pos - spawnargs.speed*clamp(Game.PingUtil.get_latency(), 0.0, Game.PingUtil.MAX_CLIENT_LATENCY); 
		
			spawn_instance.connect("destroyed", self, "_on_player_score");
			spawn_instance.fire_rate = rng.randf_range(0.5, 3.0);
			spawn_instance.move_speed = spawnargs.speed;
		SPAWN_TYPE.ASTEROID:
			spawn_instance = asteroid_scene.instance();
			spawn_instance.set_name(str(enemies_count)); # For netcode in case we want to sync things in runtime with the asteroids
			if is_network_master():
				spawn_instance.position = spawnargs.pos;
			else:
				spawn_instance.position = spawnargs.pos - spawnargs.speed*clamp(Game.PingUtil.get_latency(), 0.0, Game.PingUtil.MAX_CLIENT_LATENCY); 
			spawn_instance.move_speed = spawnargs.speed;
			spawn_instance.health = spawnargs.health;
			spawn_instance.scale = Vector2(spawnargs.scale, spawnargs.scale);
			spawn_instance.connect("destroyed", self, "_on_player_score");
			spawn_instance.spawn_rotation = spawnargs.rotation;
	return spawn_instance;

func spawn_enemies(to_spawn: Array):
	for spawnargs in to_spawn:
		var spawn_instance: Node2D = get_enemy_from_spawnargs(spawnargs);
		enemies_count+=1;
		get_node("Enemies").add_child(spawn_instance);

sync func update_score(new_score):
	score = new_score;
	get_node("ui/score").text = "Score: " + str(score);
	if score % POINT_PER_LIFE == 0:
		update_lives(lives+1)

#####################
# Signal's events
######################

func _on_player_score():
	score += 1;
	get_tree().call_group("players", "on_score_changed", score)
	if is_network_master():
		rpc("update_score", score);

func _on_player_revived():
	players_alive+=1;

func _on_player_destroyed():
	players_alive-=1;
	if players_alive <= 0:
		if is_network_master(): #Let the server handle this to avoid desync player lives between clients
			rpc("update_lives", lives-1);


##################
# UI'specific
##################

func muted():
	$ui/MuteIcon.show();

func unmuted():
	$ui/MuteIcon.hide();

func update_latency(new_latency: float):
	$ui/Log.text = str(round(new_latency*1000.0)) + "ms";

###############
# MISC & Util
###############
func log_2(val: float) -> float:
	return log(val)/log(2.0);

func log_4(val: float) -> float:
	return log(val)/log(4.0);

# Formula I made to get some curve of difficulty
func calculate_difficulty(score: float, end_score: float, end_difficulty: float) -> float:
	var x = score/end_score
	var difficulty_scale: float = half_sigmoid_curve(x, difficulty_curve)
	return (end_difficulty-1.0)*difficulty_scale+1.0

func sigmoid_curve(x: float, grow: float) -> float:
	x = clamp(x, 0.0, 1.0)
	grow = clamp(grow, 0.0, 1.0)
	if (1.0-x) == 0:
		return 1.0
	return 1.0/(1.0+pow((x/(1.0-x)), -grow))

func half_sigmoid_curve(x: float, grow: float) -> float:
	return clamp(2.0*sigmoid_curve(0.5*x, grow), 0.0, 1.0)
