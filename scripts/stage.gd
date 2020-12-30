extends Node2D

# #############################
# IMPORTANT KNOWLEDGE: For Netcode using RPC to work fine only
# Entities must have the EXACT same NodePath (that means all parents and the node itself need to have the very same name)
# So we cant to manually make sure and sync the node names to be the same in the client and server ALWAYS
# This is using original Godot way of doing netcode. (using Clockout's netcode, that's not necessary since
# the Game.Network singleton it's the only node dealing with rpc and it has an array with the only entities needed to be synced
# So, therefore, Clockout's way of doing netcode it's better for big projects.
# ############################

const POINT_INCREMENT_SPEED = 25
const POINT_PER_LIFE = 100;
const START_LIVES = 3;
const SCORE_LIMIT = 1000;
const START_LEVEL_SPEED = 30.0
const ASTEROID_MAX_SCALE = 2.25

var is_game_over = false;
var game_finished = false;
var asteroid_scene = preload("res://scenes/Asteroid.tscn");
var enemy_scene = preload("res://scenes/Enemy.tscn");
var enemies_count: int = 0; #Important for netcode
var score: int = 0;
var players_alive: int = 0;
var level_speed: float = START_LEVEL_SPEED; #The speed the background moves (or our base player speed illusion)
var lives = START_LIVES;
var game_difficulty: int = Game.EASY

#Procedural generation stuff
var asteroids_grid: CuteGrid = CuteGrid.new(16, Vector2(Game.SCREEN_WIDTH, Game.SCREEN_HEIGHT));
var enemies_grid: CuteGrid = CuteGrid.new(32, Vector2(Game.SCREEN_WIDTH, Game.SCREEN_HEIGHT));
var rng: RandomNumberGenerator = RandomNumberGenerator.new();
var pcg_data_configured: bool = false
var difficulty_curve: float = 0;
var max_difficulty: int = 0;
var max_level_speed: float = 0

enum SPAWN_TYPE {
	ASTEROID,
	ENEMY
};

signal level_speed_changed(new_speed)

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
	$background.scroll_speed = level_speed
	update_lives(START_LIVES);
	init_level_hud()

func init_level_hud():
	$ui/retry.hide();
	$ui/win_label.hide();
	$ui/DifficultyProgress/Easy.hide()
	$ui/DifficultyProgress/Hard.hide()
	$ui/DifficultyProgress/Medium.hide()
	$ui/DifficultyProgress/Impossible.hide()
	match game_difficulty:
		Game.EASY:
			$ui/DifficultyProgress/Easy.show()
		Game.MEDIUM:
			$ui/DifficultyProgress/Easy.show()
			$ui/DifficultyProgress/Medium.show()
		Game.HARD:
			$ui/DifficultyProgress/Easy.show()
			$ui/DifficultyProgress/Medium.show()
			$ui/DifficultyProgress/Hard.show()
		Game.IMPOSSIBLE:
			$ui/DifficultyProgress/Easy.show()
			$ui/DifficultyProgress/Medium.show()
			$ui/DifficultyProgress/Hard.show()
			$ui/DifficultyProgress/Impossible.show()


func clear_stage():
	pcg_data_configured = false
	difficulty_curve = 0.0
	max_difficulty = 0
	enemies_count = 0;
	max_level_speed = 0
	rng.randomize();

sync func update_lives(new_lives: int):
	lives = new_lives;
	$ui/lives.text = "Lives: " + str(lives)
	if lives <= 0:
		Game.clear_players(self)
		is_game_over = true
		if !Game.is_network_master_or_sp(self):
			$ui/retry.text = "Waiting for server to restart..."
		$ui/retry.show()

func game_was_finished():
	game_finished = true
	$ui/win_label.show()
	
func _on_snapshot():
	get_tree().call_group("network_nodes","_on_snapshot");

func _input(event):
	var is_just_presssed: bool = event.is_pressed() && !event.is_echo();
	if Input.is_key_pressed(KEY_ESCAPE):
		Game._stop_game("Game stopped")

	if (is_game_over or game_finished) && Input.is_key_pressed(KEY_ENTER) &&  Game.is_network_master_or_sp(self):
		Game.rpc_sp(self, "restart_map");

sync func restart_map():
	get_tree().call_group("enemies", "call_deferred", "queue_free") #I think it is redundant to use call_deferred
	get_tree().call_group("projectiles", "call_deferred", "queue_free")
	score = 0;
	is_game_over = false
	game_finished = false
	Game.spawn_players(self);
	$ui/retry.hide();
	$ui/win_label.hide();
	update_score(0);
	clear_stage();
	update_lives(START_LIVES);

func _on_spawn_timer_timeout():
	if !Game.is_network_master_or_sp(self) or game_finished:
		return;
	#We keep sending the seed always to not put in risk the fact that maybe a missing packet (even while using rpc!) 
	#made the client not receive the new sync and then BOOM, desync everywhere!
	Game.rpc_sp(self, "generate_enemies", [score, rng.get_seed()])

func adjut_level_properties():
	if !pcg_data_configured:
		match game_difficulty:
			Game.EASY:
				max_difficulty = rng.randi_range(4.0, 6.0)
				max_level_speed = rng.randi_range(START_LEVEL_SPEED*1, START_LEVEL_SPEED*2)
			Game.MEDIUM:
				max_difficulty = rng.randi_range(6.0, 9.0)
				max_level_speed = rng.randi_range(START_LEVEL_SPEED*2, START_LEVEL_SPEED*4)
			Game.HARD:
				max_difficulty = rng.randi_range(8.0, 12.0)
				max_level_speed = rng.randi_range(START_LEVEL_SPEED*3, START_LEVEL_SPEED*6)
			Game.IMPOSSIBLE: #Not even fair,but that's the point
				max_difficulty = rng.randi_range(11.0, 15.0)
				max_level_speed = rng.randi_range(START_LEVEL_SPEED*5, START_LEVEL_SPEED*8)
		difficulty_curve = rng.randf_range(0.4, 0.95)
		pcg_data_configured = true

sync func generate_enemies(current_score: int, new_seed: int):
	rng.set_seed(new_seed); # GOLD <3
	adjut_level_properties()

	var difficulty = round(calculate_difficulty(float(current_score), SCORE_LIMIT, max_difficulty))
	var scaleMax = (ASTEROID_MAX_SCALE-1.0)*get_difficulty_scale(float(current_score), SCORE_LIMIT)+1.0
	var spawn_data: Array = [];
	enemies_grid.clear_grid(0); #0 being not used
	for i in range(int(rng.randf_range(1.0, float(difficulty)))):
		var spawnargs: Dictionary;
		var random_cell_pos: Vector2;
		if rng.randi_range(0, 100) < 25:
			var random_cell: Vector2 = enemies_grid.get_random_cell_filter(0, new_seed);
			random_cell_pos = enemies_grid.get_world_pos_from_cell_centered(random_cell);
			enemies_grid.set_cellv(random_cell, 1); #To avoid spawning two enemies in the very same position
			var enemy_tier: float = 1.0+rng.randf_range(0.0, 1.0)*float(difficulty-1.0)
			spawnargs = {
				idspawn = SPAWN_TYPE.ENEMY,
				pos =  Vector2(Game.SCREEN_WIDTH + 64 + random_cell_pos.x, random_cell_pos.y),
				fire_rate = clamp(rng.randf_range(3.0, 4.0)/enemy_tier, 0.2, 4.0),
				speed = Vector2(40.0, 0.0), # Not random yet
				health = int(enemy_tier*0.75+0.5)
			};
			if rng.randi_range(0, 100) % 100 < 25:
				spawnargs.speed = Vector2(40.0, rng.randi_range(-10.0, 10.0));
		else:
			random_cell_pos = asteroids_grid.get_world_pos_from_cell_centered(asteroids_grid.get_random_cell(new_seed));
			spawnargs = {
				idspawn = SPAWN_TYPE.ASTEROID,
				scale = rng.randf_range(1.0, scaleMax),
				pos =  Vector2(Game.SCREEN_WIDTH + rng.randi_range(64, 128), random_cell_pos.y+rng.randi_range(-8, 8)), # add that little change to make it feel more natural
				speed = Vector2(rng.randf_range(0.0, 16.0*difficulty)+rng.randf_range(0.0, 16.0), rng.randi_range(-15.0, 15.0)),
				health = 0,
				rotation = rng.randi_range(-25, 25)
			};
			spawnargs.health = round((spawnargs.scale-1.0)*6.0+2.1);
		
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
			spawn_instance.fire_rate = rng.randf_range(0.5, 3.0);
			#-1 being no path at all, just static movement
			spawn_instance.current_path_to_follow = rng.randi_range(-1, spawn_instance.get_paths_count())
			if spawn_instance.current_path_to_follow >= 0:
				spawn_instance.ignore_base_velocity = rng.randi_range(0, 100) < 25
		SPAWN_TYPE.ASTEROID:
			spawn_instance = asteroid_scene.instance();
			spawn_instance.scale = Vector2(spawnargs.scale, spawnargs.scale);
			spawn_instance.spawn_rotation = spawnargs.rotation;
	# Common shared by all (both) enemy entities/nodes
	spawn_instance.set_name(str(enemies_count)); # For netcode in case we want to sync things in runtime with the enemies
	if Game.is_network_master_or_sp(self):
		spawn_instance.position = spawnargs.pos;
	else:
		spawn_instance.position = spawnargs.pos - spawnargs.speed*clamp(Game.PingUtil.get_latency(), 0.0, Game.PingUtil.MAX_CLIENT_LATENCY); 	
	spawn_instance.move_speed = spawnargs.speed;
	spawn_instance.health = spawnargs.health;
	spawn_instance.base_speed = Vector2(level_speed, 0)
	connect("level_speed_changed", spawn_instance, "on_level_speed_changed" )
	spawn_instance.connect("destroyed", self, "_on_player_score");
	
	return spawn_instance;

func spawn_enemies(to_spawn: Array):
	for spawnargs in to_spawn:
		var spawn_instance: Node2D = get_enemy_from_spawnargs(spawnargs);
		enemies_count+=1;
		get_node("Enemies").add_child(spawn_instance);

func update_level_speed(new_speed: float):
	level_speed = new_speed
	emit_signal("level_speed_changed", Vector2(new_speed, 0.0)) #FIXME: I keep using speed with vectors aaaaaa
	$background.scroll_speed = new_speed

sync func update_score(new_score):
	score = new_score;
	get_node("ui/score").text = "Score: " + str(score);
	if score >= SCORE_LIMIT:
		game_was_finished()
	if score % POINT_PER_LIFE == 0:
		update_lives(lives+1)
	#if score % POINT_INCREMENT_SPEED == 0:
	update_level_speed(calculate_level_speed(score, SCORE_LIMIT, START_LEVEL_SPEED, max_level_speed))

#####################
# Signal's events
######################

func _on_player_score():
	score += 1;
	get_tree().call_group("players", "on_score_changed", score)
	if Game.is_network_master_or_sp(self):
		Game.rpc_sp(self, "update_score", [score]);

func _on_player_revived():
	players_alive+=1;

func _on_player_destroyed():
	players_alive-=1;
	if players_alive <= 0:
		if Game.is_network_master_or_sp(self) and !game_finished: #Let the server handle this to avoid desync player lives between clients
			Game.rpc_sp(self, "update_lives", [lives-1]);


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
func get_difficulty_scale(score: float, end_score: float) -> float:
	return half_sigmoid_curve(score/end_score, difficulty_curve) # Returns a value between 0 and 1

func calculate_difficulty(score: float, end_score: float, end_difficulty: float) -> float:
	return (end_difficulty-1.0)*get_difficulty_scale(score, end_score)+1.0

func calculate_level_speed(score: float, end_score:float, start_speed, end_speed: float) -> float:
	return (end_speed-start_speed)*get_difficulty_scale(score, end_score)+start_speed;

func sigmoid_curve(x: float, grow: float) -> float:
	x = clamp(x, 0.0, 1.0)
	grow = clamp(grow, 0.0, 1.0)
	if (1.0-x) == 0:
		return 1.0
	return 1.0/(1.0+pow((x/(1.0-x)), -grow))

func half_sigmoid_curve(x: float, grow: float) -> float:
	return clamp(2.0*sigmoid_curve(0.5*x, grow), 0.0, 1.0)
