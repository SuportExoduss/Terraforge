class_name OnlineScreen
extends MenuScreen
## Tela ONLINE (Passo 46; cap. 04 lobby, DD-134): entra na sala de um servidor dedicado (`godot -- --server --port=N`) e mostra
## o estado dela — jogadores/capacidade e o tempo que falta para a partida abrir. Mesmo cliente do NetSession dos testes.
## ponytail: só ENTRAR (quem hospeda é o servidor dedicado); a partida é só o quadro 2D do OnlineBoard; endereço e porta
## não ficam salvos.

var net: NetSession = null   # só existe enquanto estou conectado ou conectando
var board: OnlineBoard = null   # a partida (Passo 47), depois que a sala fecha e recebo a civilização
var _box: VBoxContainer
var address: LineEdit
var port: LineEdit
var join: Button
var status: Label
var _info := {}    # último estado da sala (lobby_updated)
var _info_at := 0  # Time.get_ticks_msec() em que chegou: a contagem desce sozinha entre dois avisos
var _civ := 0      # civilização entregue quando a sala fecha


func _init() -> void:
	title_text = "ONLINE"


func build(parent: VBoxContainer) -> void:
	_box = parent
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	row.add_child(make_label("Servidor", 20))
	address = _field(row, "Address", "127.0.0.1")
	address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	port = _field(row, "Port", str(DedicatedServer.DEFAULT_PORT))
	port.custom_minimum_size.x = 110.0
	join = Button.new()
	join.name = "Join"
	join.text = "ENTRAR NA SALA"
	join.custom_minimum_size = Vector2(300.0, 52.0)
	join.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	join.add_theme_font_size_override("font_size", 22)
	join.pressed.connect(_toggle)
	parent.add_child(join)
	status = make_label("", 20, "Status")
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(0.0, 100.0)
	parent.add_child(status)
	status.text = "Digite o endereço do servidor e entre na sala."


func close() -> void:
	_leave()
	super.close()


func _field(row: HBoxContainer, field_name: String, text: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.name = field_name
	edit.text = text
	edit.add_theme_font_size_override("font_size", 20)
	row.add_child(edit)
	return edit


func _toggle() -> void:
	if net != null:
		_leave()
		status.text = "Você saiu da sala."
		return
	var number := port.text.strip_edges()
	if not number.is_valid_int() or int(number) not in range(1024, 65536):
		status.text = "Porta inválida (use de 1024 a 65535)."
		return
	var host := address.text.strip_edges()
	if host == "":
		status.text = "Digite o endereço do servidor."
		return
	# O RPC acha o nó pelo caminho a partir da raiz do multiplayer: a tela é a raiz e o NetSession se chama "Net", como no servidor.
	get_tree().set_multiplayer(SceneMultiplayer.new(), get_path())
	net = NetSession.new()
	net.name = "Net"
	add_child(net)
	net.lobby_updated.connect(func(info: Dictionary) -> void:
		_info = info
		_info_at = Time.get_ticks_msec())
	net.welcome_received.connect(func(civ: int) -> void:
		_civ = civ
		status.text = "Partida online: você é a civilização %d. Vire com ← →." % civ
		address.get_parent().visible = false   # sobra altura para o quadro
		status.custom_minimum_size.y = 32.0
		board = OnlineBoard.new()
		board.net = net
		board.custom_minimum_size = Vector2(0.0, 250.0)
		_box.add_child(board))
	net.disconnected.connect(func() -> void:
		status.text = "Sem conexão com a sala (servidor fora do ar, sala cheia ou já fechada)."
		_leave.call_deferred())   # fora do sinal: quem o emitiu ainda está usando a conexão
	_civ = 0
	if net.connect_to(host, int(number)) != OK:
		_leave()
		status.text = "Endereço inválido."
		return
	join.text = "SAIR DA SALA"
	status.text = "Conectando a %s:%s…" % [host, number]


func _leave() -> void:
	if net == null:
		return
	net.close()
	net.queue_free()
	net = null
	if board != null:
		board.queue_free()
		board = null
		address.get_parent().visible = true
		status.custom_minimum_size.y = 100.0
	_info = {}
	join.text = "ENTRAR NA SALA"


func _process(_delta: float) -> void:
	if _info.is_empty() or _civ != 0:
		return
	if _info.phase == MatchLobby.Phase.CLOSED:
		status.text = "Sala fechada: a partida está começando…"
		return
	var left := maxf(float(_info.seconds_left) - (Time.get_ticks_msec() - _info_at) / 1000.0, 0.0)
	status.text = "Na sala: %d de %d jogadores · a partida abre em %d s\nAs vagas que sobrarem serão completadas por bots." % [_info.humans, _info.capacity, ceili(left)]
