extends SceneTree
## Teste de fumaça dos slots ambientais (DD-110/DD-117/DD-122): dá ao Velho Oeste uma calota grande e confere
## (1) revelados = exatamente os slots de vegetação dentro da calota que passam na densidade do tema
##     (o resto do tema é vazio; fora da calota nada); (2) a vaga do multimesh cresce até a escala cheia
##     e fica NO terreno; (3) eliminada a civilização, os mesmos slots viram a versão morta escurecida.
## Uso: godot_console --headless --path . -s res://tools/smoke_slots.gd

var _slots: Node
var _frame := 0
var _time := 0.0
var _phase := 0
var _expected := 0
var _wait_from := 0


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	main_scene.get_node("HomeBase").skip_ceremony()   # sem a descida de abertura (7 s)
	root.add_child(main_scene)
	_slots = root.get_node("Main/Slots")


func _fail(msg: String) -> bool:
	print("FALHOU: ", msg)
	quit(1)
	return true


func _process(delta: float) -> bool:
	_frame += 1
	_time += delta
	var planet: Node = root.get_node("Services").planet
	var map: Node = root.get_node("Main/Territory")
	match _phase:
		0:  # espera o planeta ficar sólido, então entrega a calota (1,2 rad ≈ 32 % do planeta)
			if planet != null and planet.surface_ready:
				map.claim_cap(1, Vector3.UP, 1.2)
				_expected = _count_expected(planet, map)
				print("slots=%d esperados(vegetação do Velho Oeste na calota)=%d" % [_slots._dirs.size(), _expected])
				if _expected < 10:
					return _fail("poucos slots esperados (%d): sorteio ou calota estranhos" % _expected)
				_wait_from = _frame
				_time = 0.0
				_phase = 1
		1:  # >= 2 voltas completas de conferência (60 quadros cada) e o crescimento (0,9 s) acabado
			if _frame - _wait_from > 130 and _time > 1.5:
				var live: int = _slots.revealed_count(1, false)
				var any_revealed := 0
				for k in _slots._key:
					if k >= 0:
						any_revealed += 1
				print("fase1: revelados=%d (qualquer dono=%d) esperados=%d" % [live, any_revealed, _expected])
				if live != _expected or any_revealed != _expected:
					return _fail("revelados diferem do esperado")
				var i := _first_revealed()
				var g: Object = _slots._groups[_slots._key[i]]
				if DisplayServer.get_name() == "headless":
					print("fase1: (headless não guarda transformações de multimesh: confira escala/raio com janela)")
				else:
					var xf: Transform3D = g.parts[0].multimesh.get_instance_transform(_slots._ordinal[i])
					var s := xf.basis.get_scale().x
					var r: float = (xf.origin - planet.center).length()
					print("fase1: slot %d escala=%.2f raio=%.2f (base=%.2f)" % [i, s, r, _slots._base_radius[i]])
					if s < 0.5 or absf(r - _slots._base_radius[i]) > 6.0:   # origem do modelo a < 1 altura de planta do chão
						return _fail("instância sem escala cheia ou fora do terreno")
				root.get_node("EventBus").civilization_eliminated.emit(1)
				_wait_from = _frame
				_phase = 2
		2:
			if _frame - _wait_from > 130:
				var dead: int = _slots.revealed_count(1, true)
				var live_left: int = _slots.revealed_count(1, false)
				print("fase2: mortos=%d vivos=%d" % [dead, live_left])
				if dead != _expected or live_left != 0:
					return _fail("eliminada: os slots não viraram a versão morta")
				var i := _first_revealed()
				var g: Object = _slots._groups[_slots._key[i]]
				var mesh: Mesh = g.parts[0].multimesh.mesh
				var tint: Color = (mesh.surface_get_material(0) as BaseMaterial3D).albedo_color
				print("fase2: albedo do morto=%s" % tint)
				if tint.r > 0.5:
					return _fail("versão morta não foi escurecida")
				print("OK")
				quit(0)
	return false


# Conta, sem usar o sistema, quantos slots de vegetação E01/E02 estão no chão do jogador 1 e passam no dado.
func _count_expected(planet: Node, map: Node) -> int:
	var theme: Resource = root.get_node("Services").themes.theme_of(1)
	var n := 0
	for i in _slots._dirs.size():
		var cat: int = _slots._category[i]
		if map.get_owner_at(planet.center + _slots._dirs[i] * planet.radius) == 1 \
				and theme.slot_model(cat, false) != null and _slots._roll[i] <= theme.density_of(cat):
			n += 1
	return n


func _first_revealed() -> int:
	for i in _slots._key.size():
		if _slots._key[i] >= 0:
			return i
	return -1
