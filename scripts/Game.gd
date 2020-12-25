extends Node

const PORT: int = 27666;
const MAX_PLAYERS: int = 4;
const SERVER_NETID: int = 1;
const SNAPSHOT_DELAY = 1.0/30.0; #Msec to Sec

onready var player_scene = preload("res://scenes/player.tscn");

signal game_started();
signal game_ended(msg);
signal waiting_for_players();
signal player_list_updated(players);
signal player_killed(killed_id);

var game_started: bool = false;
var player_nickname: String = "Player";
var players = {};
var score: int = 0;

var colors_to_pick: Array = [
	"e37712",
	"6e79db",
	"bf2832"
];

const MAX_CLIENT_LATENCY: float = 0.4; #350ms
const MAX_MESSAGE_PING_BUFFER: int = 8; #Average from ammount
var pings: Array; 
var client_latency: float = 0.0;
var ping_counter = 0.0;

func _ready():
	get_tree().connect("network_peer_connected", self, "_player_connected");
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected");
	get_tree().connect("connected_to_server", self, "_connected_ok");
	get_tree().connect("connection_failed", self, "_connected_fail");
	get_tree().connect("server_disconnected", self, "_server_disconnected");

func _process(delta):
	if get_tree().has_network_peer() && !is_network_master():
		if ping_counter <=  0.0 || ping_counter > 2.0:
			client_send_ping(); #resend, just in case.
		ping_counter+=delta;

func _player_connected(id):
	pass

func _player_disconnected(id):
	# Each player get this notification when a peer dissapears,
	# so we remove the corresponding player data
	var player_node = get_node_or_null("/root/stage/%s" % id);
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
	# As server, we notify here if the new client is allowed to join the game.
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
	# We are the server
	var host: NetworkedMultiplayerENet = NetworkedMultiplayerENet.new();
	host.create_server(PORT);
	get_tree().set_network_peer(host);
	player_nickname = name;
	
	# First player is ourself
	# Note we don't call register_player as rpc given no client
	# are connected for the moment
	
	register_player(SERVER_NETID, name);
	emit_signal("waiting_for_players");

func join_game(ip, nickname):
	# We are a client, thus we should wait for connection with the
	# server before starting new game
	player_nickname = nickname;
	var host: NetworkedMultiplayerENet = NetworkedMultiplayerENet.new();
	host.create_client(ip, PORT);
	get_tree().set_network_peer(host);
	#Note we wait for server to respond before sending
	# waiting_for_players signal

sync func start_game():
	#Load the main game scene
	var arena = load("res://scenes/stage.tscn").instance();
	get_tree().get_root().add_child(arena);
	#Populate each player
	var i = 0;
	for p_id in players:
		var player_node: Node2D = player_scene.instance();
		#player_node.id = p_id;
		#player_node.nickname = players[p_id];
		#Configure player color and initial position according to it
		#order in the list
		player_node.position = Vector2(50.0, 50.0+25.0*i);
		player_node.modulate = colors_to_pick[i];
		player_node.set_network_master(p_id);
		arena.add_child(player_node);
		i+=1;
	
	game_started = true;
	emit_signal("game_started");

func _stop_game(msg):
	# Destroy networking system
	get_tree().set_network_peer(null);
	#Remove the arena scene and forget about the players
	players.clear();
	if game_started:
		get_node("/root/stage").queue_free();
	game_started = false;
	emit_signal("game_ended");

func client_send_ping():
	ping_counter = 0.0;
	rpc_unreliable_id(SERVER_NETID, "server_receive_ping", get_tree().get_network_unique_id());

remote func server_receive_ping(id_client):
	self.rpc_unreliable_id(id_client, "client_receive_ping");

remote func client_receive_ping():
	pings.append(ping_counter);
	if pings.size() >= MAX_MESSAGE_PING_BUFFER:
		pings.pop_front();
	ping_counter = 0.0;
	var sum_pings: float = 0.0;
	for ping in pings:
		sum_pings+=ping;
	client_latency = sum_pings / float(pings.size());
	var level_node: Node = get_node_or_null("/root/stage");
	if level_node:
		level_node.update_latency();
