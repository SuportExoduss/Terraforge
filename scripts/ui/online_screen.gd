class_name OnlineScreen
extends MenuScreen
## Tela ONLINE (Passo 46; cap. 04 lobby, DD-134): entra na sala de um servidor dedicado (`godot -- --server --port=N`) e mostra
## o estado dela — jogadores/capacidade e o tempo que falta para a partida abrir. Mesmo cliente do NetSession dos testes.
## CRIAR SALA (Passo 52) sobe um servidor dedicado neste PC, em processo à parte e sem tela, e entra nele.
## ponytail: a partida é só o quadro 2D do OnlineBoard. O endereço e a porta da última tentativa ficam no perfil (Passo 50);
## só uma sala lembrada, sem lista. A sala criada tem 2 vagas e fecha quando eu saio (o processo é encerrado).

var net: NetSession = null   # só existe enquanto estou conectado ou conectando
var host_button: Button
var _server_pid := 0   # servidor local aberto por CRIAR SALA (0 = nenhum)
var _tries := 0        # tentativas de entrar nele enquanto ainda está subindo
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
	var saved: Dictionary = Profile.data.get("online", {})
	address = _field(row, "Address", str(saved.get("address", "127.0.0.1")))
	address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	port = _field(row, "Port", str(int(saved.get("port", DedicatedServer.DEFAULT_PORT))))   # o JSON devolve número como float
	port.custom_minimum_size.x = 110.0
	join = Button.new()
	join.name = "Join"
	join.text = "ENTRAR NA SALA"
	join.custom_minimum_size = Vector2(300.0, 52.0)
	join.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	join.add_theme_font_size_override("font_size", 22)
	join.pressed.connect(_toggle)
	parent.add_child(join)
	address.focus_neighbor_bottom = address.get_path_to(port)   # Passo 158: ← → são do cursor do campo; ↓ ↑ andam em fila (endereço, porta, ENTRAR, CRIAR)
	port.focus_neighbor_top = port.get_path_to(address)
	port.focus_neighbor_bottom = port.get_path_to(join)
	join.focus_neighbor_top = join.get_path_to(port)
	address.text_submitted.connect(func(_text: String): port.grab_focus())   # ENTER no campo avança
	port.text_submitted.connect(func(_text: String): join.grab_focus())
	host_button = Button.new()
	host_button.name = "Host"
	host_button.text = "CRIAR SALA (2 VAGAS)"
	host_button.custom_minimum_size = Vector2(300.0, 48.0)
	host_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	host_button.add_theme_font_size_override("font_size", 18)
	host_button.pressed.connect(_host)
	parent.add_child(host_button)
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
	edit.gui_input.connect(func(event: InputEvent):   # Passo 158: o campo "come" ↑ ↓ e ESC; aqui ↑ ↓ passam para o vizinho e ESC volta (← → seguem sendo do cursor)
		if event.is_action_pressed("ui_cancel"):
			edit.accept_event()
			close()
			return
		var up := event.is_action_pressed("ui_up")
		if up or event.is_action_pressed("ui_down"):
			var next := edit.find_valid_focus_neighbor(SIDE_TOP if up else SIDE_BOTTOM)
			if next != null:
				next.grab_focus()
			edit.accept_event())
	row.add_child(edit)
	return edit


func _toggle() -> void:
	if net != null or _server_pid != 0:   # conectado, ou esperando a minha sala subir: o botão vira SAIR/CANCELAR
		_leave()
		status.text = "Você saiu da sala."
		return
	_connect()


## Abre um servidor dedicado neste PC (processo à parte, sem tela, 2 vagas) e entra nele; outro PC entra pelo endereço.
func _host() -> void:
	var number := port.text.strip_edges()
	if not number.is_valid_int() or int(number) not in range(1024, 65536):
		status.text = "Porta inválida (use de 1024 a 65535)."
		return
	var args := PackedStringArray(["--headless"])
	if not OS.has_feature("template"):   # rodando do projeto (não exportado): o processo novo precisa saber onde ele está
		args.append_array(["--path", ProjectSettings.globalize_path("res://")])
	args.append_array(["--", "--server", "--port=" + number, "--players=2"])
	_server_pid = OS.create_process(OS.get_executable_path(), args)
	if _server_pid < 0:
		_server_pid = 0
		status.text = "Não foi possível abrir o servidor neste computador."
		return
	address.text = "127.0.0.1"
	host_button.visible = false
	join.grab_focus()   # o foco estava em CRIAR SALA, que acabou de sumir
	join.text = "CANCELAR"
	_tries = 0
	status.text = "Abrindo a sala…"
	get_tree().create_timer(2.0).timeout.connect(_try_connect)   # o processo leva um instante para subir


func _try_connect() -> void:
	if _server_pid != 0 and net == null:   # o jogador não cancelou nesse meio tempo
		_connect()


func _connect() -> void:
	var number := port.text.strip_edges()
	if not number.is_valid_int() or int(number) not in range(1024, 65536):
		status.text = "Porta inválida (use de 1024 a 65535)."
		return
	var host := address.text.strip_edges()
	if host == "":
		status.text = "Digite o endereço do servidor."
		return
	Profile.data["online"] = {"address": host, "port": int(number)}   # lembra a sala (entradas já validadas)
	Profile.save()
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
		if _civ != 0:   # já na partida: o NetSession tenta voltar sozinho com o token da sessão (cap. 04 parte 04)
			status.text = "Conexão perdida: tentando voltar à partida…"
			return
		if _server_pid != 0:   # a minha sala ainda está subindo: tenta de novo (até 6 vezes), a menos que o processo tenha morrido
			if OS.is_process_running(_server_pid) and _tries < 6:
				_tries += 1
				status.text = "Abrindo a sala… (%d)" % _tries
				_leave.bind(false).call_deferred()
				get_tree().create_timer(1.0).timeout.connect(_try_connect)
				return
			status.text = "A sala não abriu (a porta já está em uso?)."
			_leave.call_deferred()
			return
		status.text = "Sem conexão com a sala (servidor fora do ar, sala cheia ou já fechada)."
		_leave.call_deferred())   # fora do sinal: quem o emitiu ainda está usando a conexão
	net.reconnected.connect(func(_state: Dictionary) -> void:
		status.text = "De volta à partida: você é a civilização %d. Vire com ← →." % _civ)
	net.reconnect_failed.connect(func(reason: String) -> void:
		status.text = ("Não foi possível voltar à partida (%s)." if _civ != 0 else "A sala recusou a entrada (%s).") % reason
		_leave.call_deferred())
	_civ = 0
	if net.connect_to(host, int(number)) != OK:
		_leave()
		status.text = "Endereço inválido."
		return
	join.text = "SAIR DA SALA"
	host_button.visible = false   # já estou numa sala
	status.text = "Conectando a %s:%s…" % [host, number]


func _exit_tree() -> void:
	if _server_pid != 0:
		OS.kill(_server_pid)   # não deixa servidor órfão se a tela sumir de repente


## `stop_server` false = só larga a conexão (a minha sala segue subindo e eu tento entrar de novo).
func _leave(stop_server := true) -> void:
	if stop_server and _server_pid != 0:
		OS.kill(_server_pid)   # a sala que eu criei fecha comigo
		_server_pid = 0
		host_button.visible = true
		join.text = "ENTRAR NA SALA"
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
	join.text = "CANCELAR" if _server_pid != 0 else "ENTRAR NA SALA"
	host_button.visible = _server_pid == 0


func _process(_delta: float) -> void:
	if _info.is_empty() or _civ != 0:
		return
	if _info.phase == MatchLobby.Phase.CLOSED:
		status.text = "Sala fechada: a partida está começando…"
		return
	var left := maxf(float(_info.seconds_left) - (Time.get_ticks_msec() - _info_at) / 1000.0, 0.0)
	status.text = "Na sala: %d de %d jogadores · a partida abre em %d s · ping %d ms\nAs vagas que sobrarem serão completadas por bots." % [_info.humans, _info.capacity, ceili(left), net.ping_ms()]
