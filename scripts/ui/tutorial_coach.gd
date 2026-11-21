class_name TutorialCoach
extends Control
## Passo 106 (DD-146): o treino da PRIMEIRA partida. Dicas de UMA frase, cada uma só uma vez, na hora em que o jogador precisa
## dela (um evento do jogo, ou um tempo sem ter feito a coisa). A HUD o cria no treino (`PlanetDef.tutorial`).
## Passo 130 (DD-169): também nas primeiras partidas normais (`remember`): cada dica sai UMA VEZ NA VIDA (o perfil guarda as vistas em
## `tips_seen`) e só as de contexto (as de largada e de lembrete são do treino). Passadas MEMORY_MATCHES partidas, a HUD nem o cria.
## Passo 148 (DD-187): o treino também ensina o SPRINT (aos SPRINT_TIP_AT s) e a HABILIDADE (quando a 1ª carga fica pronta); cada uma some
## se o jogador já usou o botão, e nenhuma corta a dica anterior (espera SHOW_SECONDS desde a última).
## ponytail: texto fixo em português na própria cena; vira tabela de tradução quando houver mais de um idioma.

const SHOW_SECONDS := 6.0
const NUDGE_SECONDS := 14.0   # sem fechar um circuito até aqui: lembra como se faz
const MEMORY_MATCHES := 8   # a partir da 9ª partida o jogador já conhece o jogo: as dicas de contexto não saem mais
const SPRINT_TIP_AT := 7.0   # depois da dica de largada (6,9 s) e antes do lembrete do circuito (14 s)
const TRAINING_ONLY := ["steer", "loop", "sprint", "ability"]   # a largada, o lembrete do circuito e os dois botões são do treino
const TIPS := {
	"steer": "Arraste para os lados (ou use as setas) para virar. Seu corredor anda sozinho e deixa um rastro: a sua cerca.",
	"loop": "Saia da sua terra, faça uma curva e VOLTE para ela: o rastro fecha um circuito e tudo que ficou dentro vira seu.",
	"claimed": "Circuito fechado! Tudo lá dentro agora é seu. Quanto maior o laço, maior a conquista.",
	"hurt": "Cada dano tira um pedaço de coração. Rastro longo e exposto é arriscado: feche o circuito e volte para casa.",
	"event": "Um evento vai atingir o planeta. Afaste-se do ponto marcado!",
	"bonus": "Você guardou um bônus! Toque no botão ou aperte {k_bonus} para usar.",
	"cut": "Você cortou o rastro de um rival: ele perde vida! O seu rastro também pode ser cortado.",
	"lowhp": "Vida quase no fim! Feche o circuito e volte para a sua terra antes de levar outro golpe.",
	"anchor": "Tomaram a terra onde a sua cerca nasceu: o rastro evaporou, sem dano. Saia de novo de uma terra sua.",
	"fallen": "Sua base foi tomada e o inimigo herdou o seu império! A sua nave decola: recomece de lá.",
	"conquer": "Você tomou uma base e herdou o império inteiro dela!",
	"sprint": "SPRINT: toque no botão » (ou aperte {k_sprint}) para uma corrida curta. Serve para fugir de um rival ou fechar o laço. Recarrega sozinho.",
	"ability": "Sua habilidade especial está pronta: {h}! Botão ao lado do SPRINT (ou tecla {k_ability}). Use com um rival por perto ou com a vida baixa. Recarrega sozinha.",
}

var remember := false   # partida normal: as dicas que o perfil já registrou não voltam; as novas ficam registradas
var shown: Array[String] = []   # ids das dicas já mostradas (os testes leem)
var _label: Label
var _panel: PanelContainer
var _tween: Tween
var _clock := 0.0
var _started := false
var _closed_loop := false
var _last_tip := -100.0   # instante (relógio da partida) da última dica
var _ability_at := -1.0   # instante em que a 1ª carga da habilidade fica pronta (-1 = ainda não avisada)
var _ability_name := ""
var _used := {}   # "sprint"/"ability": o jogador já apertou o botão, a dica não precisa mais sair


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
	EventBus.trail_cut.connect(func(_victim: int, attacker: int): if attacker == Civilization.PLAYER_ID: tip("cut"))
	EventBus.health_changed.connect(func(owner: int, points: int, _max: int): if owner == Civilization.PLAYER_ID and points == 1: tip("lowhp"))
	EventBus.trail_anchor_lost.connect(func(owner: int): if owner == Civilization.PLAYER_ID: tip("anchor"))
	EventBus.base_fallen.connect(_on_base_fallen)
	EventBus.sprint_used.connect(func(owner: int, _s: float): if owner == Civilization.PLAYER_ID: _used["sprint"] = true)
	EventBus.ability_used.connect(func(owner: int, _a: String): if owner == Civilization.PLAYER_ID: _used["ability"] = true)
	EventBus.ability_charging.connect(_on_ability_charging)


func _process(delta: float) -> void:
	if not _started:
		return
	_clock += delta
	if not _used.has("sprint") and _clock >= SPRINT_TIP_AT and _clock - _last_tip >= SHOW_SECONDS:
		tip("sprint")
	if not _used.has("ability") and _ability_at >= 0.0 and _clock >= _ability_at and _clock - _last_tip >= SHOW_SECONDS:
		tip("ability")
	if not _closed_loop and _clock >= NUDGE_SECONDS:
		tip("loop")


func _on_ability_charging(owner: int, cooldown: float, ability_id: String) -> void:
	if owner != Civilization.PLAYER_ID or _ability_at >= 0.0:   # só a carga da largada marca a hora da dica
		return
	_ability_at = _clock + cooldown
	_ability_name = CivilizationCatalog.ability_named(ability_id).get("name", "")


func _on_base_fallen(owner: int, conqueror: int) -> void:
	if owner == Civilization.PLAYER_ID:
		tip("fallen")
	elif conqueror == Civilization.PLAYER_ID:
		tip("conquer")


func _on_claimed(owner: int, new_cells: int) -> void:
	if owner == Civilization.PLAYER_ID and new_cells > 0:
		_closed_loop = true
		tip("claimed")


## Mostra a dica `id` se ainda não saiu. Uma nova troca a anterior na hora (o que acabou de acontecer vale mais).
func tip(id: String) -> void:
	if shown.has(id) or not TIPS.has(id) or (remember and TRAINING_ONLY.has(id)):
		return
	var seen: Array = Profile.data.get("tips_seen", [])
	if remember and seen.has(id):
		return
	if not seen.has(id):   # o treino também registra: quem já viu na largada não revê na partida normal
		seen.append(id)
		Profile.data["tips_seen"] = seen
	shown.append(id)
	_last_tip = _clock
	_label.text = TIPS[id].replace("{h}", _ability_name).replace("{k_bonus}", Settings.key_label("bonus")).replace("{k_sprint}", Settings.key_label("sprint")).replace("{k_ability}", Settings.key_label("ability"))
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_panel, "modulate:a", 1.0, 0.25)
	_tween.tween_interval(SHOW_SECONDS)
	_tween.tween_property(_panel, "modulate:a", 0.0, 0.6)


func current_text() -> String:
	return _label.text
