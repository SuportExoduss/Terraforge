class_name Profile
extends RefCounted
## Perfil salvo do jogador (cap. 03 parte 11: XP, moedas, estatísticas pessoais, conquistas) em JSON no user://.
## Só estatísticas e cosméticos: nada aqui compra vantagem na partida (sem pay-to-win).
## Em execução headless (testes) usa outro arquivo, para não sujar o perfil de verdade.
## ponytail: arquivo local sem criptografia nem nuvem; o servidor assume isso no multiplayer.

const XP_PER_LEVEL_STEP := 100   # nível N começa em 100 * (N-1)^2 XP

static var path := "user://profile_headless.json" if DisplayServer.get_name() == "headless" else "user://profile.json"
const RATING_START := 1000
const RATING_DELTA := [25, 10, 0]   # 1º, 2º e 3º lugar; do 4º para baixo (ou sem pontuar) perde RATING_LOSS
const RATING_LOSS := 15

static var data := {}


static func defaults() -> Dictionary:
	return {"xp": 0, "coins": 0, "matches": 0, "wins": 0, "best_percent": 0.0,
			"loops": 0, "cuts": 0, "kills": 0, "achievements": {}, "rating": RATING_START, "planet": "medio"}


## Habilidade (cap. 03 parte 02, matchmaking): sobe ou desce conforme a colocação final (1 = primeiro, 0 = nunca pontuou).
## ponytail: passos fixos por colocação, sem pesar a força dos rivais; Elo de verdade se um dia houver ranking online.
static func rating_after(rating: int, place: int) -> int:
	var change: int = RATING_DELTA[place - 1] if place >= 1 and place <= RATING_DELTA.size() else -RATING_LOSS
	return maxi(rating + change, 0)


## Lê o arquivo (campos que faltam voltam ao padrão; arquivo ausente ou corrompido = perfil novo).
static func load_data() -> void:
	data = defaults()
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		data.merge(parsed, true)


static func save() -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))


static func level(xp: int = -1) -> int:
	var total: int = data.get("xp", 0) if xp < 0 else xp
	return 1 + int(sqrt(total / float(XP_PER_LEVEL_STEP)))
