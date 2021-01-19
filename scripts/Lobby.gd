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
onready var DifficultyOption: OptionButton = $Lobby/panel/MarginContainer/vbox/HBoxContainer/Difficulty
onready var DifficultyOptionSP: OptionButton = $SPGame/VBoxContainer/HBoxContainer/DifficultySP
onready var StartGameSPBtn = $SPGame/VBoxContainer/StartSP
onready var SharedLivesCheckBox: CheckBox = $Lobby/panel/MarginContainer/vbox/HBoxContainer/SharedLives
onready var CreditsBtn: TextureButton = $CenterContainer/AboutUs

func _ready():
	
	HostServerBtn.connect("pressed", self, "host_server");
	ConnectServerBtn.connect("pressed", self, "join_server");
	ExitGameBtn.connect("pressed", self, "exit_game")
	MultiplayerBtn.connect("pressed", self, "show_multiplayer_menu")
	BackToMenuBtn.connect("pressed", self, "go_back")
	PlayOfflineBtn.connect("pressed", self, "sp_game_tab")
	StartGameBtn.connect("pressed",self, "start_mp_game")
	StartGameSPBtn.connect("pressed", self, "start_offline_game")
	DifficultyOption.connect("item_selected", self, "on_difficulty_selected")
	SharedLivesCheckBox.connect("pressed", self, "on_shared_lives_changed")
	CreditsBtn.connect("pressed", self, "show_credits")

	#Network signals
	Game.connect("game_ended", self, "_reset_menu");
	Game.connect("waiting_for_players", self, "show_lobby");
	Game.connect("game_started", self, "_hide_menu");
	Game.connect("player_list_updated", self, "_update_player_list");
	DifficultyOption.clear()
	DifficultyOptionSP.clear()
	for skill in Game.skills_names:
		DifficultyOption.add_item(skill)
		DifficultyOptionSP.add_item(skill)
	DifficultyOption.select(0)
	DifficultyOptionSP.select(0)
	if OS.has_feature("HTML5"): # No coop for html5 by now
		MultiplayerBtn.hide()
		ExitGameBtn.hide()
		
	init_main_menu()

func init_main_menu():
	$Multiplayer.hide()
	$MenuButtons.show()
	$Lobby.hide()
	$SPGame.hide()
	BackToMenuBtn.hide()
	$LogoSmall.hide()
	$LogoBig.show()

func show_lobby():
	$LogoSmall.show()
	$LogoBig.hide();
	$Lobby.show()
	$MenuButtons.hide()
	$Multiplayer.hide()
	$SPGame.hide()
	BackToMenuBtn.show()
	SharedLivesCheckBox.set_pressed(Game.sv_shared_lives)
	if Game.is_client():
		SharedLivesCheckBox.set_disabled(true)
		DifficultyOption.set_disabled(true)
		StartGameBtn.set_disabled(true)
		rpc_id(Game.SERVER_NETID, "client_joined_lobby", get_tree().get_network_unique_id())
	else:
		DifficultyOption.set_disabled(false)
		StartGameBtn.set_disabled(false)
		SharedLivesCheckBox.set_disabled(false)

master func client_joined_lobby(client_id: int):
	rpc_id(client_id, "receive_lobby_info", {difficulty = DifficultyOption.get_selected_id(), shared_lives = SharedLivesCheckBox.is_pressed()})

puppet func receive_lobby_info(info: Dictionary):
	DifficultyOption.select(info.difficulty)
	SharedLivesCheckBox.set_pressed(info.shared_lives)
	Game.sv_shared_lives = info.shared_lives

func on_difficulty_selected(index: int):
	Game.rpc_sp(self, "difficulty_set", [index])

func on_shared_lives_changed():
	Game.rpc_sp(self, "shared_lives_set", [SharedLivesCheckBox.is_pressed()])

sync func difficulty_set(index: int):
	DifficultyOption.select(index)

sync func shared_lives_set(new_val: bool):
	Game.sv_shared_lives = new_val
	SharedLivesCheckBox.set_pressed(new_val)

func show_multiplayer_menu():
	$Multiplayer.show()
	$MenuButtons.hide()
	$LogoSmall.show()
	$LogoBig.hide();
	BackToMenuBtn.show()

func go_back():
	$Multiplayer.hide()
	$MenuButtons.show()
	$Lobby.hide()
	$Credits.hide()
	$SPGame.hide()
	$LogoSmall.hide()
	$LogoBig.show()
	BackToMenuBtn.hide()
	HostServerBtn.disabled = false;
	ConnectServerBtn.disabled = false;
	Game._stop_game("Game stopped")

func show_credits():
	$Credits.show()
	$Multiplayer.hide()
	$SPGame.hide()
	$Lobby.hide()
	$MenuButtons.hide()
	$LogoSmall.show()
	$LogoBig.hide()
	BackToMenuBtn.show()
	
func exit_game():
	get_tree().quit()

func start_mp_game():
	if get_tree().is_network_server():
		var netgame_difficulty: int = clamp(DifficultyOption.get_selected(), 0, Game.skills_names.size()-1)
		Game.rpc("start_game", netgame_difficulty);

func sp_game_tab():
	BackToMenuBtn.show()
	$SPGame.show()
	$MenuButtons.hide()
	$Multiplayer.hide()
	$Lobby.hide()
	$LogoSmall.hide()
	$LogoBig.show()

func start_offline_game():
	var game_difficulty: int = clamp(DifficultyOptionSP.get_selected(), 0, Game.skills_names.size()-1)
	Game.register_player(Game.SERVER_NETID, PlayerNameTextEdit.text)
	Game.start_game(game_difficulty)

func host_server():
	Game.host_game(PlayerNameTextEdit.text)
	HostServerBtn.disabled = true
	var max_players: int = int(MaxClientTextEdit.text)
	if max_players == 1:
		Game.rpc("start_game")

func _update_player_list(players):
	var PlayersStr: String = ""
	for p_id in players:
		PlayersStr += players[p_id] + str("\n")
	$Lobby/panel/MarginContainer/vbox/Players.text = PlayersStr

func join_server():
	var IPAddress: String = IPTextEdit.text
	IPAddress = IPAddress.replace(" ", "")
	Game.join_game(IPAddress, PlayerNameTextEdit.text)
	ConnectServerBtn.disabled = true

func _hide_menu():
	hide()

func _reset_menu():
	$Multiplayer.hide()
	$MenuButtons.show()
	$Lobby.hide()
	$SPGame.hide()
	$LogoSmall.hide()
	$LogoBig.show()
	BackToMenuBtn.hide()
	HostServerBtn.disabled = false
	ConnectServerBtn.disabled = false
	show()
