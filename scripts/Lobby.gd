extends Control

onready var HostServerBtn = $Multiplayer/HostServer
onready var ConnectServerBtn = $Multiplayer/Connect
onready var MaxClientTextEdit = $Multiplayer/MaxClientsContainer/MaxClients
onready var PlayerNameTextEdit = $Multiplayer/PlayerContainer/Name
onready var IPTextEdit = $Multiplayer/IPContainer/IP
onready var ExitGameBtn = $MenuButtons/VBoxContainer/Exit
onready var MultiplayerBtn = $MenuButtons/VBoxContainer/Multiplayer
onready var BackToMenuBtn = $Back
onready var PlayOfflineBtn = $MenuButtons/VBoxContainer/PlayOffline
onready var StartGameBtn = $Lobby/panel/MarginContainer/vbox/StartGame

func _ready():
	
	HostServerBtn.connect("pressed", self, "host_server");
	ConnectServerBtn.connect("pressed", self, "join_server");
	ExitGameBtn.connect("pressed", self, "exit_game")
	MultiplayerBtn.connect("pressed", self, "show_multiplayer_menu")
	BackToMenuBtn.connect("pressed", self, "go_back")
	PlayOfflineBtn.connect("pressed", self, "start_offline_game")
	StartGameBtn.connect("pressed",self, "start_mp_game")
	$Multiplayer.hide()
	$MenuButtons.show()
	$Lobby.hide()
	BackToMenuBtn.hide()
	#Network signals
	Game.connect("game_ended", self, "_reset_menu");
	Game.connect("waiting_for_players", self, "show_lobby");
	Game.connect("game_started", self, "_hide_menu");
	Game.connect("player_list_updated", self, "_update_player_list");

func show_lobby():
	$Lobby.show()
	$MenuButtons.hide()
	$Multiplayer.hide()
	BackToMenuBtn.show()

func show_multiplayer_menu():
	$Multiplayer.show()
	$MenuButtons.hide()
	BackToMenuBtn.show()

func go_back():
	$Multiplayer.hide()
	$MenuButtons.show()
	$Lobby.hide()
	BackToMenuBtn.hide()
	HostServerBtn.disabled = false;
	ConnectServerBtn.disabled = false;
	Game._stop_game("Game stopped")

func exit_game():
	get_tree().quit()

func start_mp_game():
	if get_tree().is_network_server():
		Game.rpc("start_game");

func start_offline_game():
	Game.register_player(Game.SERVER_NETID, PlayerNameTextEdit.text)
	Game.start_game()

func host_server():
	Game.host_game(PlayerNameTextEdit.text);
	HostServerBtn.disabled = true;
	var max_players: int = int(MaxClientTextEdit.text);
	if max_players == 1:
		Game.rpc("start_game");

func _update_player_list(players):
	#var max_players: int = int(MaxClientTextEdit.text);
	var PlayersStr: String = ""
	for p_id in players:
		PlayersStr += players[p_id] + str("\n")
	$Lobby/panel/MarginContainer/vbox/Players.text = PlayersStr		
	#if players.size() >= max_players:
	#	Game.rpc("start_game");

func join_server():
	var IPAddress: String = IPTextEdit.text;
	IPAddress = IPAddress.replace(" ", "");
	Game.join_game(IPAddress, PlayerNameTextEdit.text);
	ConnectServerBtn.disabled = true;

func _hide_menu():
	hide();

func _reset_menu():
	$Multiplayer.hide()
	$MenuButtons.show()
	$Lobby.hide()
	BackToMenuBtn.hide()
	HostServerBtn.disabled = false;
	ConnectServerBtn.disabled = false;
	show();
