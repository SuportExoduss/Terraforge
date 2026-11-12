class_name EventsScreen
extends MenuScreen
## Tela EVENTOS (Passo 84, SYS-004 ACEITAÇÃO "facilmente compreendidos"): uma entrada por evento global com o que o
## jogador vê ANTES (aviso), o que acontece DURANTE (efeito) e o que fica DEPOIS (cicatriz). Texto fixo, na ordem do GDMD.
## ponytail: o texto não lê os números dos scripts dos eventos — se um dano mudar, atualize aqui.

const EVENTS := [
	["METEORO", "sombra crescente no ponto de impacto", "3 anéis: 4 / 2 / 1 pts; o centro devolve à base", "cratera que encolhe"],
	["TERREMOTO", "rachaduras finas no chão", "rachadura aberta 1 pt, pedra 1 pt, preso 2 pts", "rachaduras, pedras e cristais"],
	["VERME GIGANTE", "só a contagem; o chão incha no alvo", "em cima 4 pts e volta à base; perto 2; borda 1", "montes com o buraco do túnel e cristais"],
	["FURACÃO", "alvo de 4 anéis no chão", "centro 4 pts e volta à base; as bordas puxam e dão 1 pt/s", "poeira, destroços e bônus raro"],
	["TSUNAMI", "espuma baixa no ponto de partida", "a onda cruza meia volta: espuma 1, meio 2, centro 3 pts", "poça que seca e bônus"],
	["VULCÃO", "o chão escurece e o cone desponta", "bola de lava 1 pt; 4 juntas = 4 pts e volta à base", "solo escuro, lava sólida e cristais"],
	["CHUVA ÁCIDA", "nuvens verdes sobre a área", "1 pt/s (metade no próprio território)", "plantas queimadas e flores raras"],
	["MANADA", "faixa acesa no chão", "5 touros em V: 3 pts e volta à base", "pegadas e cristais"],
]


func _init() -> void:
	title_text = "EVENTOS"


func build(parent: VBoxContainer) -> void:
	var scroll := ScrollContainer.new()   # o ajuste TEXTO pode alongar a lista
	scroll.custom_minimum_size = Vector2(0.0, 360.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	for i in EVENTS.size():
		var e: Array = EVENTS[i]
		var entry := VBoxContainer.new()
		entry.name = "Event%d" % i
		entry.add_child(make_label(e[0], 20, "Name"))
		var text := make_label("AVISO: %s  ·  EFEITO: %s  ·  DEPOIS: %s" % [e[1], e[2], e[3]], 14, "Text")
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.modulate = Color(1.0, 1.0, 1.0, 0.8)
		entry.add_child(text)
		list.add_child(entry)
