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

var game_over = false;
var game_finished = false;
var asteroid_scene = preload("res://scenes/Asteroid.tscn");
var enemy_spaceship_scene = preload("res://scenes/Enemy.tscn");
var enemies_count: int = 0; #Important for netcode
var score: int = 0;
var players_alive: int = 0;
var level_speed: float = START_LEVEL_SPEED; #The speed the background moves (or our base player speed illusion)
var lives = START_LIVES;
var game_difficulty: int = Game.SKILL.EASY

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
	SPACESHIP
};

var wave_count_left: int = 0
var current_wave_type_count: int = 0
var current_wave_type: int = 0

enum WAVE_TYPE {
	NORMAL,
	SPACESHIPS,
	ASTEROIDS,
	SPAM, #50% extra ammount spawn
	RELAX, #A wave that actually is easy to slow down the game from time to time... for suspense I guess?
	MAX_TYPES
}
const wave_chances: Array = [
	WAVE_TYPE.NORMAL, WAVE_TYPE.NORMAL, WAVE_TYPE.NORMAL, WAVE_TYPE.NORMAL, WAVE_TYPE.NORMAL, WAVE_TYPE.NORMAL,
	WAVE_TYPE.SPACESHIPS, WAVE_TYPE.ASTEROIDS, WAVE_TYPE.SPAM, WAVE_TYPE.RELAX
];
const wave_limits: Dictionary = {
	WAVE_TYPE.NORMAL: 15,
	WAVE_TYPE.ASTEROIDS: 6,
	WAVE_TYPE.SPACESHIPS: 6,
	WAVE_TYPE.SPAM: 3,
	WAVE_TYPE.RELAX: 2
}

signal level_speed_changed(new_speed)
signal extra_life

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
	$Background.scroll_speed = level_speed
	connect("level_speed_changed", $Background, "_on_level_speed_changed")
	update_lives(START_LIVES);
	init_level_hud()
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func _input(event):
	var is_just_presssed: bool = event.is_pressed() && !event.is_echo();
	if Input.is_key_pressed(KEY_ESCAPE):
		Game._stop_game("Game stopped")

	if (game_over or game_finished) && Input.is_key_pressed(KEY_ENTER) &&  Game.is_network_master_or_sp(self):
		Game.rpc_sp(self, "restart_map");

func init_level_hud():
	$ui/retry.hide();
	$ui/win_label.hide();
	$ui/DifficultyProgress/Easy.hide()
	$ui/DifficultyProgress/Hard.hide()
	$ui/DifficultyProgress/Medium.hide()
	$ui/DifficultyProgress/Impossible.hide()
	match game_difficulty:
		Game.SKILL.EASY:
			$ui/DifficultyProgress/Easy.show()
		Game.SKILL.MEDIUM:
			$ui/DifficultyProgress/Easy.show()
			$ui/DifficultyProgress/Medium.show()
		Game.SKILL.HARD:
			$ui/DifficultyProgress/Easy.show()
			$ui/DifficultyProgress/Medium.show()
			$ui/DifficultyProgress/Hard.show()
		Game.SKILL.IMPOSSIBLE:
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
	wave_count_left = 0
	current_wave_type_count = 0
	current_wave_type = 0
	rng.randomize();

func _on_snapshot():
	get_tree().call_group("network_nodes","_on_snapshot");

sync func update_lives(new_lives: int):
	lives = new_lives;
	$ui/lives.text = "Lives: " + str(lives)
	if lives <= 0 and (Game.sv_shared_lives or Game.is_singleplayer_game()):
		process_game_over()

sync func process_game_over():
	Game.clear_players(self)
	game_over = true
	if !Game.is_network_master_or_sp(self):
		$ui/retry.text = "Waiting for server to restart..."
	$ui/retry.show()

func game_was_finished():
	game_finished = true
	$ui/win_label.show()
	
sync func restart_map():
	get_tree().call_group("enemies", "call_deferred", "queue_free") #I think it is redundant to use call_deferred
	get_tree().call_group("projectiles", "call_deferred", "queue_free")
	score = 0;
	game_over = false
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

	wave_count_left-=1
	update_wave_data()
	#We keep sending the seed always to not put in risk the fact that maybe a missing packet (even while using rpc!) 
	#made the client not receive the new sync and then BOOM, desync everywhere!
	Game.rpc_sp(self, "process_spawn_timer", [score, current_wave_type, rng.get_seed(), players_alive]) #send the players_alive just in case I don't want to be TOTALLY SURE the client shares the sale value

func update_wave_data():
	if wave_count_left <= 0:
		wave_count_left = rng.randi_range(15, 35)
		var old_wave_type: int = current_wave_type
		current_wave_type = wave_chances[rng.randi()%wave_chances.size()]
		if old_wave_type == current_wave_type:
			current_wave_type_count +=1
			if current_wave_type_count > wave_limits[current_wave_type]:
				current_wave_type_count = 0
				current_wave_type+=1
				if current_wave_type == WAVE_TYPE.MAX_TYPES:
					current_wave_type = WAVE_TYPE.NORMAL
		else:
			current_wave_type_count = 0

sync func process_spawn_timer(current_score: int, used_wave_type: int, new_seed: int, players_alive_in_game: int):
	update_random_seed(new_seed) #sync random seed
	adjust_level_difficulty()
	var enemies_data: Array = get_enemies_to_spawn(current_score, used_wave_type, players_alive_in_game)
	spawn_enemies(enemies_data);

func update_random_seed(new_seed: int):
	rng.set_seed(new_seed);
	enemies_grid.set_random_seed(new_seed)
	asteroids_grid.set_random_seed(new_seed)

func adjust_level_difficulty():
	if !pcg_data_configured:
		match game_difficulty:
			Game.SKILL.EASY:
				max_difficulty = rng.randi_range(4.0, 6.0)
				max_level_speed = rng.randi_range(START_LEVEL_SPEED*1, START_LEVEL_SPEED*2)
			Game.SKILL.MEDIUM:
				max_difficulty = rng.randi_range(6.0, 8.0)
				max_level_speed = rng.randi_range(START_LEVEL_SPEED*2, START_LEVEL_SPEED*4)
			Game.SKILL.HARD:
				max_difficulty = rng.randi_range(8.0, 11.0)
				max_level_speed = rng.randi_range(START_LEVEL_SPEED*3, START_LEVEL_SPEED*5)
			Game.SKILL.IMPOSSIBLE: #Not even fair,but that's the point
				max_difficulty = rng.randi_range(11.0, 14.0)
				max_level_speed = rng.randi_range(START_LEVEL_SPEED*5, START_LEVEL_SPEED*7)
		difficulty_curve = rng.randf_range(0.4, 0.95)
		pcg_data_configured = true

func get_enemies_to_spawn(current_score: int, used_wave_type: int, players_alive_in_game: int) -> Array: 
	var difficulty = round(calculate_difficulty(float(current_score), SCORE_LIMIT, max_difficulty))
	var scaleMax = (ASTEROID_MAX_SCALE-1.0)*get_difficulty_scale(float(current_score), SCORE_LIMIT)+1.0
	var enemies_data: Array = [];
	enemies_grid.clear_grid(0); #0 being not used
	var enemies_to_spawn_count: int = get_enemies_to_spawn_count(difficulty, used_wave_type, players_alive_in_game)
	for i in range(int(enemies_to_spawn_count)):
		if (rng.randi_range(0, 100) < 25 or used_wave_type == WAVE_TYPE.SPACESHIPS) and used_wave_type != WAVE_TYPE.ASTEROIDS: # spawn enemies
			enemies_data.append(generate_enemy_spaceship_spawnargs(difficulty));
		else:
			enemies_data.append(generate_asteroid_spawnargs(scaleMax, difficulty));
	return enemies_data

func get_enemies_to_spawn_count(difficulty: int, used_wave_type: int, players_alive_in_game: int) -> int:
	var enemies_to_spawn_count: float = rng.randf_range(1.0, float(difficulty))
	if used_wave_type == WAVE_TYPE.SPAM:
		enemies_to_spawn_count *= 1.5
	elif used_wave_type == WAVE_TYPE.RELAX:
		enemies_to_spawn_count *= 0.25 #to give some time to breath from time to time
	elif used_wave_type == WAVE_TYPE.SPACESHIPS:
		enemies_to_spawn_count *= 0.75 #otherwise it is a bit unfair
	#The more players the harder
	if players_alive_in_game <= 1:
		enemies_to_spawn_count*=0.8
	elif players_alive_in_game >= 3:
		enemies_to_spawn_count*=1.2
		difficulty += 2
	if enemies_to_spawn_count < 1.0:
		enemies_to_spawn_count = 1.0 # to ensure at least 1 enemy always

	return int(enemies_to_spawn_count)

func generate_asteroid_spawnargs(max_scale: float, difficulty: float) -> Dictionary:
	var random_cell_pos = asteroids_grid.get_world_pos_from_cell_centered(asteroids_grid.get_random_cell());
	var spawnargs: Dictionary = {
		idspawn = SPAWN_TYPE.ASTEROID,
		scale = rng.randf_range(1.0, max_scale),
		pos =  Vector2(Game.SCREEN_WIDTH + rng.randi_range(64, 128), random_cell_pos.y+rng.randi_range(-8, 8)), # add that little change to make it feel more natural
		speed = Vector2(rng.randf_range(0.0, 16.0*difficulty)+rng.randf_range(0.0, 16.0), rng.randi_range(-15.0, 15.0)),
		health = 0,
		rotation = rng.randi_range(-25, 25)
	};
	spawnargs.health = round((spawnargs.scale-1.0)*6.0+2.1);
	return spawnargs

func generate_enemy_spaceship_spawnargs(difficulty: float) -> Dictionary:
	var random_cell: Vector2 = enemies_grid.get_random_cell_filter(0);
	var random_cell_pos = enemies_grid.get_world_pos_from_cell_centered(random_cell);
	enemies_grid.set_cellv(random_cell, 1); #To avoid spawning two enemies in the very same position
	var enemy_tier: float = 1.0+rng.randf_range(0.0, 1.0)*float(difficulty-1.0)
	var spawnargs: Dictionary = {
		idspawn = SPAWN_TYPE.SPACESHIP,
		pos =  Vector2(Game.SCREEN_WIDTH + 64 + random_cell_pos.x, random_cell_pos.y),
		fire_rate = clamp(rng.randf_range(3.0, 4.0)/enemy_tier, 0.2, 4.0),
		speed = Vector2(40.0, 0.0), # Not random yet
		health = int(enemy_tier*0.75+0.5)
	};
	if rng.randi_range(0, 100) % 100 < 25:
		spawnargs.speed = Vector2(40.0, rng.randi_range(-10.0, 10.0));
		
	return spawnargs

func get_enemy_instance_from_spawnargs(spawnargs: Dictionary, enemy_id: int) -> Node2D:
	var spawn_instance: Node2D;
	match spawnargs.idspawn:
		SPAWN_TYPE.SPACESHIP:
			spawn_instance = enemy_spaceship_scene.instance();
			spawn_instance.fire_rate = rng.randf_range(0.5, 3.0);
			#-1 being no path at all, just static movement
			spawn_instance.current_path_to_follow = rng.randi_range(-1, spawn_instance.get_paths_count())
			if spawn_instance.current_path_to_follow >= 0:
				spawn_instance.ignore_base_velocity = rng.randi_range(0, 100) < 25
			spawn_instance.rng.set_seed(rng.get_seed())
		SPAWN_TYPE.ASTEROID:
			spawn_instance = asteroid_scene.instance();
			spawn_instance.scale = Vector2(spawnargs.scale, spawnargs.scale);
			spawn_instance.spawn_rotation = spawnargs.rotation;
	# Common shared by all (both) enemy entities/nodes
	spawn_instance.set_name(str(enemy_id)); # For netcode in case we want to sync things in runtime with the enemies
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

func spawn_enemies(enemies_spawnargs: Array):
	for spawnargs in enemies_spawnargs:
		var spawn_instance: Node2D = get_enemy_instance_from_spawnargs(spawnargs, enemies_count);
		enemies_count+=1;
		get_node("Enemies").call_deferred("add_child", spawn_instance)

func update_level_speed(new_speed: float):
	level_speed = new_speed
	emit_signal("level_speed_changed", Vector2(new_speed, 0.0)) #FIXME: I keep using speed with vectors aaaaaa

sync func update_score(new_score):
	score = new_score;
	get_node("ui/score").text = "Score: " + str(score);
	if score >= SCORE_LIMIT:
		game_was_finished()
	if score % POINT_PER_LIFE == 0:
		update_lives(lives+1)
		emit_signal("extra_life")
	update_level_speed(calculate_level_speed(score, SCORE_LIMIT, START_LEVEL_SPEED, max_level_speed))

#####################
# Signal's events
######################

func _on_player_score():
	score += 1;
	get_tree().call_group("players", "on_score_changed", score)
	if Game.is_network_master_or_sp(self):
		Game.rpc_sp(self, "update_score", [score]);

func _on_player_revived(player):
	if !is_instance_valid(player):
		print("[FATAL ERROR] invalid instance at stage::_on_player_revived")
	players_alive+=1;

func _on_player_destroyed(player, player_lives):
	if !is_instance_valid(player):
		print("[FATAL ERROR] invalid instance at stage::_on_player_destroyed")
	if Game.sv_shared_lives or Game.is_singleplayer_game():
		players_alive-=1;
		if players_alive <= 0:
			if Game.is_network_master_or_sp(self) and !game_finished: #Let the server handle this to avoid desync player lives between clients
				Game.rpc_sp(self, "update_lives", [lives-1]);
	elif Game.is_network_master_or_sp(player):
		update_lives(player_lives) #without rpc this is not net-sync, and that's the idea

func _on_player_out_of_lives(player):
	if !is_instance_valid(player):
		print("[FATAL ERROR] invalid instance at stage::_on_player_out_of_lives")
	players_alive-=1;
	if players_alive <= 0:
		if Game.is_network_master_or_sp(self) and !game_finished:
			Game.rpc_sp(self, "process_game_over");

func _exit_tree():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

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

func sigmoid_curve(x: float, grow: float) -> float: #Gold function
	x = clamp(x, 0.0, 1.0)
	grow = clamp(grow, 0.0, 1.0)
	if (1.0-x) == 0:
		return 1.0
	return 1.0/(1.0+pow((x/(1.0-x)), -grow))

func half_sigmoid_curve(x: float, grow: float) -> float:
	return clamp(2.0*sigmoid_curve(0.5*x, grow), 0.0, 1.0)
