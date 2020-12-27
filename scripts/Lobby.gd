extends Control

var clients_joined: int = 1;

func _ready():
	$HostServer.connect("pressed", self, "host_server");
	$Connect.connect("pressed", self, "join_server");
	
	#Network signals
	Game.connect("game_ended", self, "_reset_lobby");
	Game.connect("waiting_for_players", self, "_show_wait_players");
	Game.connect("game_started", self, "_hide_lobby");
	Game.connect("player_list_updated", self, "_update_player_list");

func host_server():
	Game.host_game($Name.text);
	$HostServer.disabled = true;
	var max_players: int = int($MaxClients.text);
	if max_players == 1:
		Game.rpc("start_game");

func _update_player_list(players):
	var max_players: int = int($MaxClients.text);
	if players.size() >= max_players:
		Game.rpc("start_game");

func join_server():
	var IPAddress: String = $IP.text;
	IPAddress = IPAddress.replace(" ", "");
	Game.join_game(IPAddress, $Name.text);
	$Connect.disabled = true;

func _show_wait_players():
	$HostServer.text = "Waiting for players....";

func _hide_lobby():
	hide();

func _reset_lobby():
	show();
