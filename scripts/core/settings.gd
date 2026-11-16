class_name Settings
extends RefCounted
## Configurações do jogador (UI-006, DD-132): volume de efeitos, volume de música e qualidade gráfica. Ficam no Profile
## (sobrevivem ao fechar o jogo) e são aplicadas na hora: volumes nos barramentos do AudioDirector, qualidade na
## resolução 3D e no antisserrilhado da janela principal.
## ponytail: só o que já existe para ajustar; controles, idioma e acessibilidade entram quando houver o que escolher.

const DEFAULTS := {"sfx": 1.0, "music": 0.8, "quality": 2, "turn": 0.5, "reduce_motion": 0.0, "text": 0.0, "tips": 1.0, "haptics": 1.0}   # turn: 0..1 no controle = giro de 50% a 150% (0.5 = 100%); reduce_motion: 0 = desligado, 1 = ligado; text: 0..1 = texto da HUD de 100% a 150%
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
	saved[key] = clampf(value, 0.0, 1.0) if key != "quality" else clampi(int(value), 0, QUALITY_NAMES.size() - 1)
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
