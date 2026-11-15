class_name TutorialCoach
extends Control
## Passo 106 (DD-146): o treino da PRIMEIRA partida. Dicas de UMA frase, cada uma só uma vez, na hora em que o jogador precisa
## dela (um evento do jogo, ou um tempo sem ter feito a coisa). Só existe na partida do treino (`PlanetDef.tutorial`); a HUD o cria.
## ponytail: texto fixo em português na própria cena; vira tabela de tradução quando houver mais de um idioma.

const SHOW_SECONDS := 6.0
const NUDGE_SECONDS := 14.0   # sem fechar um circuito até aqui: lembra como se faz
const TIPS := {
	"steer": "Arraste para os lados (ou use as setas) para virar. Seu corredor anda sozinho e deixa um rastro: a sua cerca.",
	"loop": "Saia da sua terra, faça uma curva e VOLTE para ela: o rastro fecha um circuito e tudo que ficou dentro vira seu.",
	"claimed": "Circuito fechado! Tudo lá dentro agora é seu. Quanto maior o laço, maior a conquista.",
	"hurt": "Cada dano tira um pedaço de coração. Rastro longo e exposto é arriscado: feche o circuito e volte para casa.",
	"event": "Um evento vai atingir o planeta. Afaste-se do ponto marcado!",
	"bonus": "Você guardou um bônus! Toque no botão ou aperte ESPAÇO para usar.",
}

var shown: Array[String] = []   # ids das dicas já mostradas (os testes leem)
var _label: Label
var _panel: PanelContainer
var _tween: Tween
var _clock := 0.0
var _started := false
var _closed_loop := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.name = "Tip"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.13, 0.82)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 0)
	_panel.custom_minimum_size = Vector2(560.0, 0.0)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.position.y -= 150.0
	_panel.modulate.a = 0.0
	add_child(_panel)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", roundi(20 * Settings.text_scale()))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_label)
	EventBus.match_started.connect(func(): _started = true; tip("steer"))
	EventBus.territory_loop_claimed.connect(_on_claimed)
	EventBus.damage_taken.connect(func(victim: int, _points: int, _cause: String): if victim == Civilization.PLAYER_ID: tip("hurt"))
	EventBus.global_event_warning.connect(func(_name: String, seconds: int): if seconds > 0: tip("event"))
	EventBus.bonus_stock_changed.connect(func(owner: int, kinds: Array): if owner == Civilization.PLAYER_ID and not kinds.is_empty(): tip("bonus"))


func _process(delta: float) -> void:
	if not _started:
		return
	_clock += delta
	if not _closed_loop and _clock >= NUDGE_SECONDS:
		tip("loop")


func _on_claimed(owner: int, new_cells: int) -> void:
	if owner == Civilization.PLAYER_ID and new_cells > 0:
		_closed_loop = true
		tip("claimed")


## Mostra a dica `id` se ainda não saiu. Uma nova troca a anterior na hora (o que acabou de acontecer vale mais).
func tip(id: String) -> void:
	if shown.has(id) or not TIPS.has(id):
		return
	shown.append(id)
	_label.text = TIPS[id]
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_panel, "modulate:a", 1.0, 0.25)
	_tween.tween_interval(SHOW_SECONDS)
	_tween.tween_property(_panel, "modulate:a", 0.0, 0.6)


func current_text() -> String:
	return _label.text
