class_name DedicatedServer
extends Node
## Servidor dedicado (DD-134, Adendo 06: ENet + API de alto nível, sem tela): `godot --headless --path . -- --server --port=24680
## --players=4 --wait=20`. Sobe o transporte (STATE-001), abre a sala (STATE-002, MatchLobby) e, quando o lobby fecha
## (STATE-003), monta a partida com `players` civilizações — os humanos da sala assumem as primeiras, o resto fica com os
## bots — e entrega a cada humano o seu corredor (NetSession.admit). O menu entrega o processo a este nó (`requested`).
## ponytail: uma partida por processo e sem encerramento sozinho: o orquestrador sobe outro processo para a próxima sala.

const MATCH_SCENE := "res://scenes/match.tscn"
const DEFAULT_PORT := 24680

var port := DEFAULT_PORT
var capacity := 4        # civilizações na partida (humanos + bots), 1…6
var max_wait := 20.0     # s de matchmaking contados do primeiro jogador
var skip_ceremony := false   # testes: pula a abertura de 7 s
var net: NetSession
var lobby: MatchLobby
var game: Node = null    # a partida, depois que a sala fecha


static func requested(args: PackedStringArray) -> bool:
	return args.has("--server")


## Lê `--port=N --players=N --wait=S`; o que faltar ou vier inválido fica com o padrão.
func configure(args: PackedStringArray) -> void:
	for arg in args:
		var parts := arg.split("=", true, 1)
		if parts.size() < 2:
			continue
		match parts[0]:
			"--port":
				if parts[1].is_valid_int() and int(parts[1]) in range(1024, 65536):
					port = int(parts[1])
			"--players":
				if parts[1].is_valid_int() and int(parts[1]) in range(1, MatchLobby.MAX_CAPACITY + 1):
					capacity = int(parts[1])
			"--wait":
				if parts[1].is_valid_float() and float(parts[1]) > 0.0:
					max_wait = float(parts[1])


func _ready() -> void:
	# O RPC identifica o nó pelo caminho a partir da raiz do multiplayer: com a raiz aqui o NetSession é "Net" para o
	# servidor e para o cliente, onde quer que cada um more na árvore.
	get_tree().set_multiplayer(SceneMultiplayer.new(), get_path())
	net = NetSession.new()
	net.name = "Net"
	add_child(net)
	lobby = MatchLobby.new()
	lobby.name = "Lobby"
	lobby.capacity = capacity
	lobby.max_wait = max_wait
	add_child(lobby)
	var err := net.host(port, capacity)
	if err != OK:
		push_error("[Servidor] porta %d indisponível (erro %d)" % [port, err])
		get_tree().quit(1)
		return
	net.use_lobby(lobby)
	lobby.closed.connect(_on_lobby_closed)
	lobby.open()
	print("[Servidor] sala aberta na porta %d: %d vagas, espera máxima %.0f s" % [port, capacity, max_wait])


func _on_lobby_closed(peers: Array, bots: int) -> void:
	print("[Servidor] lobby fechado: %d jogador(es) + %d bot(s)" % [peers.size(), bots])
	game = (load(MATCH_SCENE) as PackedScene).instantiate()
	var setup := game.get_node("MatchSetup") as MatchSetup
	setup.bot_count = capacity - 1   # a civilização 1 também é da sala: os humanos tomam as primeiras
	setup.skip_ceremony = skip_ceremony
	add_child(game)
	for peer_id: int in peers:
		net.admit(peer_id)
