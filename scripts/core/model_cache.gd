class_name ModelCache
extends RefCounted
## Segura na memória os .glb que a partida instancia várias vezes. Sem referência viva, `load()` relê o arquivo a cada uso
## (MEDIDO: touro 35 ms a cada sentinela, com referência 0,03 ms; a gema fazia o mesmo a cada bônus).
## O menu chama prefetch() (segundo plano); quem usa chama scene(): pronto = instantâneo, em curso = espera só o resto.
## ponytail: lista fixa; modelo novo que a partida instancie em laço entra em PATHS.

const BULL := "res://art/models/cowboy/CowboyTouro.glb"
const GEM := "res://art/models/cowboy/CowboyGema.glb"
const PATHS := [BULL, GEM]

static var _held: Dictionary = {}   # caminho -> PackedScene (preload de .glb quebraria a carga em thread da partida; por isso load em tempo de execução)


static func prefetch() -> void:
	for path in PATHS:
		if not _held.has(path):
			ResourceLoader.load_threaded_request(path)


static func scene(path: String) -> PackedScene:
	if not _held.has(path):
		_held[path] = load(path)   # com pedido em thread em curso, o load() espera por ele em vez de reler
	return _held[path]
