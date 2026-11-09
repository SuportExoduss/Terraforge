class_name MenuMusic
extends Node
## Passo 49: a trilha do menu (Cap.03 P01 MÚSICA, DD-006). Começa suave e misteriosa (só a base do MusicDirector, baixinho);
## quando o jogador abre uma tela entra a camada de pulso, e ela fica; ao clicar JOGAR a música some junto com o mergulho.
## ponytail: reaproveita os loops da partida em volume menor; trilha própria = trocar as duas chamadas de `music_stream`.

const QUIET_DB := -40.0
const BASE_DB := -20.0
const LAYER_DB := -24.0
const FADE_SECONDS := 2.0

var deep := false      # já entrou a camada de pulso
var leaving := false   # o jogador clicou JOGAR

var _base: AudioStreamPlayer
var _layer: AudioStreamPlayer


func _ready() -> void:
	AudioDirector.ensure_buses()
	_base = _player(MusicDirector.music_stream(false))
	_layer = _player(MusicDirector.music_stream(true))
	_base.play()   # as duas nascem juntas: o mesmo tamanho de loop as mantém em compasso
	_layer.play()
	_fade(_base, BASE_DB)


## Uma tela do menu abriu: entra um instrumento novo (uma vez só).
func deepen() -> void:
	if deep or leaving:
		return
	deep = true
	_fade(_layer, LAYER_DB)


func fade_out(seconds: float) -> void:
	leaving = true
	_fade(_base, QUIET_DB, seconds)
	_fade(_layer, QUIET_DB, seconds)


func _player(stream: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = AudioDirector.MUSIC_BUS
	player.stream = stream
	player.volume_db = QUIET_DB
	add_child(player)
	return player


func _fade(player: AudioStreamPlayer, db: float, seconds := FADE_SECONDS) -> void:
	create_tween().tween_property(player, "volume_db", db, seconds)
