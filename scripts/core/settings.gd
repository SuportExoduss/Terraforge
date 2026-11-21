class_name Settings
extends RefCounted
## Configurações do jogador (UI-006, DD-132): volume de efeitos, volume de música e qualidade gráfica. Ficam no Profile
## (sobrevivem ao fechar o jogo) e são aplicadas na hora: volumes nos barramentos do AudioDirector, qualidade na
## resolução 3D e no antisserrilhado da janela principal.
## ponytail: só o que já existe para ajustar; controles, idioma e acessibilidade entram quando houver o que escolher.

const DEFAULTS := {"sfx": 1.0, "music": 0.8, "quality": 2, "turn": 0.5, "reduce_motion": 0.0, "text": 0.0, "tips": 1.0, "haptics": 1.0, "btn_size": 0.5, "key_sprint": KEY_SHIFT, "key_ability": KEY_E, "key_bonus": KEY_SPACE}   # turn: 0..1 no controle = giro de 50% a 150% (0.5 = 100%); reduce_motion: 0 = desligado, 1 = ligado; text: 0..1 = texto da HUD de 100% a 150%; btn_size: 0..1 = botões de toque de 60% a 140% (0.5 = 100%); key_*: código da tecla de cada ação (inteiro, Passo 156)
const KEY_ACTIONS := ["sprint", "ability", "bonus"]   # ações com tecla própria; o ajuste de cada uma é "key_<ação>"
const KEY_BLOCKED := [KEY_NONE, KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_TAB, KEY_BACK, KEY_F3, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]   # já têm outro uso (menus, direção, medidor)
const QUALITY_NAMES := ["BAIXA", "MÉDIA", "ALTA"]
const QUALITY_SCALE := [0.7, 0.85, 1.0]                                                       # resolução 3D relativa
const QUALITY_MSAA := [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X]


static func get_value(key: String) -> Variant:
	var saved: Dictionary = Profile.data.get("settings", {})
	return saved.get(key, default_quality() if key == "quality" else DEFAULTS[key])


## Celular começa em MÉDIA (resolução 85%, MSAA 2X): ALTA (4X, 100%) pesa demais na GPU de um aparelho comum.
static func default_quality() -> int:
	return 1 if OS.has_feature("mobile") else DEFAULTS["quality"]


## Passo 55 (UI-006): multiplicador da direção do jogador, de 0,5 a 1,5.
static func turn_gain() -> float:
	return 0.5 + float(get_value("turn"))


## Passo 66 (UI-006, "boa acessibilidade"): multiplicador do tamanho dos textos da HUD, de 1,0 a 1,5 (lido quando a HUD é montada).
static func text_scale() -> float:
	return 1.0 + 0.5 * float(get_value("text"))


## Passo 156 (DD-195): multiplicador dos botões de toque da partida, de 0,6 a 1,4 (lido quando a HUD é montada e ao voltar da pausa).
static func button_scale() -> float:
	return 0.6 + 0.8 * float(get_value("btn_size"))


## Passo 156: tecla (código) de uma ação: "sprint", "ability" ou "bonus".
static func key_for(action: String) -> int:
	return int(get_value("key_" + action))


## Nome da tecla para os textos da tela (ESPAÇO, SHIFT, E...).
static func key_label(action: String) -> String:
	var code := key_for(action)
	return "ESPAÇO" if code == KEY_SPACE else OS.get_keycode_string(code).to_upper()


## Passo 156: troca a tecla de uma ação. Se outra ação já usava essa tecla, ela fica com a antiga (nunca duas ações na mesma tecla).
## false = tecla proibida (nada muda).
static func set_key(action: String, keycode: int) -> bool:
	if keycode in KEY_BLOCKED or not KEY_ACTIONS.has(action):
		return false
	var old := key_for(action)
	for other: String in KEY_ACTIONS:
		if other != action and key_for(other) == keycode:
			set_value("key_" + other, old, false)
	set_value("key_" + action, keycode)
	return true


## Passo 156: tamanho dos botões e teclas voltam ao padrão.
static func reset_controls() -> void:
	for key: String in ["btn_size", "key_sprint", "key_ability", "key_bonus"]:
		set_value(key, DEFAULTS[key], false)
	Profile.save()


## Passo 56 (UI-006, acessibilidade): com "reduzir movimento" ligado não há meteoros/auroras no fundo do menu nem clarão de relâmpago.
static func reduced_motion() -> bool:
	return float(get_value("reduce_motion")) >= 0.5


## Passo 131: dicas de contexto das primeiras partidas ligadas (padrão) ou desligadas; o treino ensina sempre.
static func tips_on() -> bool:
	return float(get_value("tips")) >= 0.5


## Passo 133: vibração do celular ligada (padrão) ou desligada.
static func haptics_on() -> bool:
	return float(get_value("haptics")) >= 0.5


## Muda um ajuste e aplica na hora; `save = false` enquanto o jogador arrasta um controle (salva ao soltar).
static func set_value(key: String, value: Variant, save := true) -> void:
	if not DEFAULTS.has(key):
		return
	var saved: Dictionary = Profile.data.get("settings", {})
	if key == "quality":
		saved[key] = clampi(int(value), 0, QUALITY_NAMES.size() - 1)
	elif key.begins_with("key_"):
		saved[key] = int(value)
	else:
		saved[key] = clampf(value, 0.0, 1.0)
	Profile.data["settings"] = saved
	apply_all()
	if save:
		Profile.save()


static func apply_all() -> void:
	AudioDirector.ensure_buses()
	AudioDirector.set_volume(AudioDirector.SFX_BUS, get_value("sfx"))
	AudioDirector.set_volume(AudioDirector.MUSIC_BUS, get_value("music"))
	var window := (Engine.get_main_loop() as SceneTree).root
	var level := clampi(int(get_value("quality")), 0, QUALITY_NAMES.size() - 1)
	window.scaling_3d_scale = QUALITY_SCALE[level]
	window.msaa_3d = QUALITY_MSAA[level]
