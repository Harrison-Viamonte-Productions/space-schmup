extends Node

const PORT: int = 27666;
const MAX_PLAYERS: int = 4;
const SERVER_NETID: int = 1;
const SNAPSHOT_DELAY: float = 1.0/30.0; #Msec to Sec
const LevelScene: String = "/root/stage";
const SCREEN_WIDTH: int = 320;
const SCREEN_HEIGHT: int = 180;

enum TOOLS{
	PING_UTIL,
	MAX
}

onready var player_scene: PackedScene = preload("res://scenes/player.tscn");

signal game_started();
signal game_ended(msg);
signal waiting_for_players();
signal player_list_updated(players);
signal player_killed(killed_id);
signal update_latency(new_latency);
signal mute();
signal unmute();

var game_started: bool = false;
var player_nickname: String = "Player";
var players = {};
var PingUtil: LatencyCounter = LatencyCounter.new(self, "update_latency", TOOLS.PING_UTIL); # Tool.

#CVARS
var sv_shared_lives: bool = false

var skills_names: Array = [
	'Easy',
	'Medium',
	'Hard',
	'Not cool'
]

enum SKILL {
	EASY,
	MEDIUM,
	HARD,
	IMPOSSIBLE
}

var colors_to_pick: Array = [
	"e37712",
	"6e79db",
	"bf2832"
];

func _ready():
	get_tree().connect("network_peer_connected", self, "_player_connected");
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected");
	get_tree().connect("connected_to_server", self, "_connected_ok");
	get_tree().connect("connection_failed", self, "_connected_fail");
	get_tree().connect("server_disconnected", self, "_server_disconnected");

func _process(delta):
	PingUtil.update(delta);

func _player_connected(id):
	pass

func _player_disconnected(id):
	# Each player get this notification when a peer dissapears,
	# so we remove the corresponding player data
	var player_node = get_node_or_null(LevelScene + "/Players/%s" % id);
	if player_node:
		# If we have started the game yet, the player node won't be present.
		player_node.queue_free();
	players.erase(id);
	emit_signal("player_list_updated", players);

func _connected_ok():
	# This method is only called from the newly connected
	# client. Hence we register ourself to the server
	
	var player_id = get_tree().get_network_unique_id();
	# Note given this call
	rpc("register_player_to_server", player_id, player_nickname);
	# Nowe we just wait for the server to start the game
	emit_signal("waiting_for_players");

func _connected_fail():
	_stop_game("Cannot connect to server");
	
func _server_disconnected():
	_stop_game("Server connection lost");

slave func _kicked_by_server(reason):
	_stop_game(reason);

master func register_player_to_server(id, name):
	if game_started:
		rpc_id(id, "_kicked_by_server", "Game already started");
	elif len(players) >= MAX_PLAYERS:
		rpc_id(id, "_kicked_by_server", "Server is full");
	
	# Send to the newcomer the already present players
	for p_id in players:
		rpc_id(id, "register_player", p_id, players[p_id]);
	
	#Now we register the newcomer everywhere, note the newcomer's peer will
	# also be called.
	
	rpc("register_player", id, name);
	
	#Register player is puppet, so rpc won't call it in our peer
	# (of course we could have set it sync to avoid this)
	
	register_player(id, name);

func is_singleplayer_game():
	return !get_tree().has_network_peer()

puppet func register_player(id, name):
	players[id] = name;
	emit_signal("player_list_updated", players);

func host_game(name):
	var host: NetworkedMultiplayerENet = NetworkedMultiplayerENet.new();
	host.create_server(PORT);
	get_tree().set_network_peer(host);
	player_nickname = name;
	register_player(SERVER_NETID, name);
	emit_signal("waiting_for_players");

func join_game(ip, nickname):
	player_nickname = nickname;
	var host: NetworkedMultiplayerENet = NetworkedMultiplayerENet.new();
	host.create_client(ip, PORT);
	get_tree().set_network_peer(host);

func clear_players(level: Node):
	for player in level.get_node("Players").get_children():
		player.call_deferred("queue_free")

func spawn_players_in_level(level: Node):
	clear_players(level)
	var i = 0;
	for playerId in players:
		var player_instance: Player = create_player(playerId, Vector2(50.0, 50.0+25.0*i))
		add_player_to_level(player_instance, level)
		i+=1
	level.players_alive = i

func create_player(playerId: int, position: Vector2) -> Player:
	var player_instance: Player = player_scene.instance()
	player_instance.set_name(str(playerId))
	player_instance.nickname = players[playerId]
	player_instance.position = position
	player_instance.set_network_master(playerId)
	#player_instance.modulate = color
	return player_instance

func add_player_to_level(playerInstance, levelInstance):
	levelInstance.get_node("Players").add_child(playerInstance)
	playerInstance.connect("destroyed", levelInstance, "_on_player_destroyed")
	playerInstance.connect("revived", levelInstance, "_on_player_revived")
	playerInstance.connect("out_of_lives", levelInstance, "_on_player_out_of_lives")
	levelInstance.connect("extra_life", playerInstance, "_on_extra_life")

sync func start_game(difficulty: int = SKILL.EASY):
	if game_started: 
		return; #FIXME: This should never happen

	#Load the main game scene
	var arena: Node = load("res://scenes/stage.tscn").instance();
	arena.game_difficulty = difficulty
	#arena.connect("tree_exited", self, "stage_removed");
	connect("update_latency", arena, "update_latency");
	connect("mute", arena, "muted");
	connect("unmute", arena, "unmuted");
	get_tree().get_root().add_child(arena);
	spawn_players_in_level(arena);
	game_started = true;
	emit_signal("game_started");

func clear_arena():
	if game_started && get_node_or_null(LevelScene):
		get_node(LevelScene).queue_free();

func _stop_game(msg):
	# Destroy networking system
	get_tree().set_network_peer(null);
	#Remove the arena scene and forget about the players
	players.clear();
	clear_arena();
	game_started = false;
	emit_signal("game_ended");

# Netcode specific (From 'Clockout', really useful)
remote func process_rpc(tool_id: int, method_name: String, data: Array):
	match tool_id:
		TOOLS.PING_UTIL:
			PingUtil.callv(method_name, data);

# Adjust some netcode functions to work smoothly in SP and Multiplayer
func rpc_sp(caller: Node, method: String, args: Array = []):
	if !is_instance_valid(caller):
		print("[WARNING] Invalid instance at rpc_sp!")
		return;
	if is_singleplayer_game():
		caller.callv(method, args)
	else:
		caller.callv("rpc", [method] + args)

func rpc_unreliable_sp(caller: Node, method: String, args: Array = []):
	if !is_instance_valid(caller):
		print("[WARNING] Invalid instance at rpc_unreliable_sp!")
		return;
	if is_singleplayer_game():
		caller.callv(method, args)
	else:
		caller.callv("rpc_unreliable", [method] + args)

func is_network_master_or_sp(caller: Node):
	return is_singleplayer_game() or caller.is_network_master()

func is_client() -> bool:
	return get_tree().has_network_peer() and !get_tree().is_network_server()

func is_client_connected() -> bool:
	if !get_tree().has_network_peer() or get_tree().is_network_server():
		return false;
	return get_tree().get_network_peer().get_connection_status() == get_tree().get_network_peer().CONNECTION_CONNECTED

# Global input
func _input(event):

	var is_just_pressed: bool = event.is_pressed() && !event.is_echo();
	if Input.is_key_pressed(KEY_M) && is_just_pressed:
		var audio_master_id: int = AudioServer.get_bus_index("Master");
		var audio_master_muted: bool = !AudioServer.is_bus_mute(audio_master_id);
		if audio_master_muted:
			emit_signal("mute");
		else:
			emit_signal("unmute");
		AudioServer.set_bus_mute(audio_master_id, audio_master_muted);
