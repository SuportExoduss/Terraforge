extends SceneTree
## Teste de fumaça do Passo 124 (DD-164, planetas temáticos): (1) o catálogo tem 4 planetas de tamanhos diferentes (Médio, Pequeno,
## Gelo, Vulcão) com ids únicos; o bioma só muda a aparência (todos têm bots, relógio e células proporcionais à área);
## (2) `apply_look` liga/desliga o shader (deserto = a 0); (3) uma partida no VULCÃO entrega ao material do planeta as cores do bioma
## e a atmosfera do menu muda de cor por bioma. Headless não valida o shader: a olho, `tools/shot_match.gd`.
## Uso: godot_console --headless --path . -s res://tools/smoke_biome.gd

var _match: Node
var _services: Node
var _time := 0.0
var _checked := false


func _fail(msg: String) -> bool:
	print("FALHOU: ", msg)
	quit(1)
	return true


func _initialize() -> void:
	var def_script: GDScript = load("res://scripts/core/planet_def.gd")
	var all: Array = def_script.catalog()
	var ids := {}
	var radii := {}
	for def in all:
		ids[def.id] = true
		radii[def.radius] = true
		if def.bots < 1 or def.duration_seconds < 120.0 or def.cell_count() != roundi(20000 * def.area_scale()):
			_fail("planeta %s com regra fora do padrão (bots %d, %d s, %d células)" % [def.id, def.bots, int(def.duration_seconds), def.cell_count()])
			return
	if all.size() != 4 or ids.size() != 4 or radii.size() < 3:
		_fail("o catálogo deveria ter 4 planetas únicos e pelo menos 3 tamanhos (tem %d, %d ids, %d raios)" % [all.size(), ids.size(), radii.size()])
		return
	var percents := []
	for def in all:   # Passo 125: a tela de escolha precisa de frase, tamanho em % e 3 cores por planeta
		percents.append(def.size_percent())
		if def.blurb == "" or def_script.swatch(def.biome).size() != 3:
			_fail("planeta %s sem frase ou sem as 3 cores da tela de escolha" % def.id)
			return
	if percents != [100, 36, 64, 100] or def_script.swatch("gelo") == def_script.swatch("vulcao") or def_script.swatch("gelo") == def_script.swatch("deserto"):
		_fail("tamanhos em %% ou cores de bioma errados: %s" % [percents])
		return
	var gelo: Resource = def_script.by_id("gelo")
	var vulcao: Resource = def_script.by_id("vulcao")
	if gelo.biome != "gelo" or gelo.radius != 80.0 or vulcao.biome != "vulcao" or vulcao.radius != 100.0 or def_script.by_id("medio").biome != "deserto" or def_script.by_id("pequeno").biome != "deserto":
		_fail("biomas/raios errados: Gelo %s r%.0f, Vulcão %s r%.0f" % [gelo.biome, gelo.radius, vulcao.biome, vulcao.radius])
		return
	if def_script.training().biome != "deserto":
		_fail("o treino não tem bioma (fica o visual de sempre)")
		return
	# apply_look liga o shader nos temáticos e desliga no deserto
	var shader := Shader.new()
	var material := ShaderMaterial.new()
	material.shader = shader
	def_script.apply_look(material, vulcao)
	var dark: Color = material.get_shader_parameter("look_dark")
	var water: Color = material.get_shader_parameter("look_water")
	if dark.a < 0.99 or dark.r > 0.2 or water.a < 0.99 or water.r < 0.8:
		_fail("Vulcão: terra deveria ser escura e a água, lava (%s / %s)" % [dark, water])
		return
	def_script.apply_look(material, gelo)
	var light: Color = material.get_shader_parameter("look_light")
	if material.get_shader_parameter("look_dark").a < 0.99 or light.b < 0.9 or material.get_shader_parameter("look_water").b < 0.4:
		_fail("Gelo: terra deveria ser clara e a água, azul gelada")
		return
	def_script.apply_look(material, def_script.by_id("medio"))
	if material.get_shader_parameter("look_dark").a > 0.01 or material.get_shader_parameter("look_water").a > 0.01:
		_fail("deserto deveria desligar o visual temático")
		return
	def_script.apply_look(material, null)
	if material.get_shader_parameter("look_dark").a > 0.01:
		_fail("sem planeta escolhido (null) deveria ser o deserto")
		return
	# cores da atmosfera diferentes por bioma
	if def_script.air_color("gelo") == def_script.air_color("vulcao") or def_script.air_color("deserto") != def_script.DEFAULT_AIR or def_script.air_color("gelo") == def_script.DEFAULT_AIR:
		_fail("cada bioma deveria ter a sua atmosfera")
		return
	_services = root.get_node("Services")
	_services.match_def = vulcao
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	root.add_child(_match)


func _process(delta: float) -> bool:
	_time += delta
	if _checked:
		return false
	if _time > 20.0:
		return _fail("tempo esgotado esperando o planeta")
	var planet: Node = _services.planet
	if planet == null:
		return false
	var painter: Node = planet.get_node_or_null("Painter")
	if painter == null or painter.get("_materials").is_empty():
		return false
	_checked = true
	if not is_equal_approx(planet.radius, 100.0):
		return _fail("o Vulcão deveria ter raio 100 (tem %f)" % planet.radius)
	for m in painter.get("_materials"):
		var dark: Color = (m as ShaderMaterial).get_shader_parameter("look_dark")
		if dark.a < 0.99 or dark.r > 0.2:
			return _fail("o material do planeta deveria ter a terra escura do Vulcão (%s)" % dark)
	print("vulcão: %d material(is) com o visual temático" % painter.get("_materials").size())
	_services.match_def = null
	print("OK")
	quit(0)
	return true
