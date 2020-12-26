extends Node

const PORT: int = 27666;
const MAX_PLAYERS: int = 4;
const SERVER_NETID: int = 1;
const SNAPSHOT_DELAY = 1.0/30.0; #Msec to Sec
const LevelScene: String = "/root/stage";
const SCREEN_WIDTH = 320;
const SCREEN_HEIGHT = 180;

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

var game_started: bool = false;
var restarting: bool = false;
var player_nickname: String = "Player";
var players = {};
var score: int = 0;
var PingUtil: LatencyCounter = LatencyCounter.new(self, "update_latency", TOOLS.PING_UTIL); # Tool.

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

func spawn_players(level: Node):
	#Populate each player
	var i = 0;
	for p_id in players:
		var player_node: Player = player_scene.instance();
		player_node.set_name(str(p_id));
		player_node.position = Vector2(50.0, 50.0+25.0*i);
		player_node.modulate = colors_to_pick[i];
		player_node.set_network_master(p_id);
		level.get_node("Players").add_child(player_node);
		player_node.connect("destroyed", level, "_on_player_destroyed");
		i+=1;
	level.players_alive = i;

sync func start_game():
	if game_started: 
		return; #FIXME: This should never happen

	restarting = false;
	#Load the main game scene
	var arena: Node = load("res://scenes/stage.tscn").instance();
	#arena.connect("tree_exited", self, "stage_removed");
	connect("update_latency", arena, "update_latency");
	get_tree().get_root().add_child(arena);
	spawn_players(arena);
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
