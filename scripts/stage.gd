extends Node2D

# #############################
# IMPORTANT KNOWLEDGE: For Netcode using RPC to work fine only
# Entities must have the EXACT same NodePath (that means all parents and the node itself need to have the very same name)
# So we cant to manually make sure and sync the node names to be the same in the client and server ALWAYS
# This is using original Godot way of doing netcode. (using Clockout's netcode, that's not necessary since
# the Game.Network singleton it's the only node dealing with rpc and it has an array with the only entities needed to be synced
# So, therefore, Clockout's way of doing netcode it's better for big projects.
# ############################

var is_game_over = false;
var asteroid = preload("res://scenes/Asteroid.tscn");
var enemies_count: int = 0; #Important for netcode
var score: int = 0;
var players_alive: int = 0;

#Procedural generation stuff
var map_grid: CuteGrid = CuteGrid.new(16, Vector2(Game.SCREEN_WIDTH, Game.SCREEN_HEIGHT));
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
	enemies_count = 0;
	rng.randomize();

func _on_snapshot():
	get_tree().call_group("network_nodes","_on_snapshot");

func _input(event):
	var is_just_presssed: bool = event.is_pressed() && !event.is_echo();
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
	clear_stage();

func _on_player_revived():
	players_alive+=1;

func _on_player_destroyed():
	players_alive-=1;
	if players_alive <= 0:
		Game.clear_players(self);
		is_game_over = true;
		if !is_network_master():
			$ui/retry.text = "Waiting for server to restart...";
		$ui/retry.show();

func _on_spawn_timer_timeout():
	if !is_network_master():
		return;
	rpc("generate_enemies", score, rng.get_seed()); #With the randomg seed it's enough to spawn the exact same asteroids and enemies in the client pc

sync func generate_enemies(current_score: int, new_seed: int):
	rng.set_seed(new_seed); # GOLD <3
	var difficulty = round(log_2(float(current_score+1))+0.51);
	var scaleMax = 1.0+log_4(float(current_score+1))/6.0;
	var enemies: Array = [];
	for i in range(int(rng.randf_range(1.0, float(difficulty)))):
		var random_cell_pos: Vector2 = map_grid.get_world_pos_from_cell_centered(map_grid.get_random_cell(new_seed));
		var enemy_spawnargs: Dictionary = {
			scale = rng.randf_range(1.0, scaleMax),
			pos =  Vector2(Game.SCREEN_WIDTH + 32, random_cell_pos.y+rng.randi_range(-8, 8)), # add that little change to make it feel more natural
			speed = Vector2(rng.randf_range(50.0, 50.0+30.0*difficulty), rng.randi_range(-15.0, 15.0)),
			health = 0,
			rotation = rng.randi_range(-25, 25)
		};
		enemy_spawnargs.health = round((enemy_spawnargs.scale-1.0)*6.0+2.0);
		enemies.append(enemy_spawnargs);

	#We can do some post-proccess here if we want before spawning the enemies!
	#post_process()....	
	spawn_enemies(enemies);

func spawn_enemies(to_spawn: Array):
	for enemy in to_spawn:
		var asteroid_instance: Node2D = asteroid.instance();
		asteroid_instance.set_name(str(enemies_count)); # For netcode in case we want to sync things in runtime with the asteroids
		enemies_count+=1;
		if is_network_master():
			asteroid_instance.position = enemy.pos;
		else:
			asteroid_instance.position = enemy.pos - enemy.speed*clamp(Game.PingUtil.get_latency(), 0.0, Game.PingUtil.MAX_CLIENT_LATENCY); 
		asteroid_instance.move_speed = enemy.speed;
		asteroid_instance.health = enemy.health;
		asteroid_instance.scale = Vector2(enemy.scale, enemy.scale);
		asteroid_instance.connect("destroyed", self, "_on_player_score");
		asteroid_instance.spawn_rotation = enemy.rotation;
		get_node("Enemies").add_child(asteroid_instance);

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
