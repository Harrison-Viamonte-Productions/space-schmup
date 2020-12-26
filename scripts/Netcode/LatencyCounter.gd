class_name LatencyCounter
extends Object

# Private members (underscore used for private members and virtual functions)
var _signal: String;
var _father: Node;
const MAX_CLIENT_LATENCY: float = 0.4; #350ms
const MAX_MESSAGE_PING_BUFFER: int = 8; #Average from ammount
var _pings: Array; 
var _client_latency: float = 0.0;
var _ping_counter = 0.0;
var _tool_id: int = -1;

func _init(father: Node, signal_to_fire: String, tool_id: int):
	assert(father.has_method('process_rpc'));
	self._father = father;
	self._signal = signal_to_fire;
	self._tool_id = tool_id; # Dirty code for more flexibility of objects with netcode
	

func update(delta):
	if _father.get_tree().has_network_peer() && !_father.is_network_master():
		if _ping_counter <=  0.0 || _ping_counter > 2.0:
			_client_send_ping(); #resend, just in case.
		_ping_counter+=delta;

func _client_send_ping():
	_ping_counter = 0.0;
	_father.callv("rpc_unreliable_id", [1, "process_rpc", self._tool_id, "server_receive_ping", [_father.get_tree().get_network_unique_id()]]);

func server_receive_ping(id_client):
	if _father.get_tree().has_network_peer():
		_father.callv("rpc_unreliable_id", [id_client, "process_rpc", self._tool_id, "client_receive_ping", []]);

func get_latency() -> float:
	return _client_latency;

func client_receive_ping():
	_pings.append(_ping_counter);
	if _pings.size() >= MAX_MESSAGE_PING_BUFFER:
		_pings.pop_front();
	_ping_counter = 0.0;
	var sum_pings: float = 0.0;
	for ping in _pings:
		sum_pings+=ping;
	_client_latency = sum_pings / float(_pings.size());
	_father.emit_signal(_signal, _client_latency);
