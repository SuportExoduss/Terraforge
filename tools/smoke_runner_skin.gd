extends SceneTree
## Teste de fumaça do Passo 138 (DD-177): O PERSONAGEM DA CIVILIZAÇÃO. (1) a Floresta (civ 3) corre com o Guardião Élfico:
## esqueleto de 12 ossos, animação "Correr" tocando, textura pintada, 2,0 de altura e pés no chão; (2) o Velho Oeste e o Alien
## continuam com o Pistoleiro (osso L_ToeBase); (3) sem fichas de tema (Services.themes vazio) nada quebra: Pistoleiro;
## (4) o mesmo vale para o bot da Floresta (id 3 em qualquer vaga).
## Uso: godot_console --headless --path . -s res://tools/smoke_runner_skin.gd

var _services: Node


func _fail(msg: String) -> void:
	print("FALHOU: ", msg)
	quit(1)


func _runner(civ_id: int) -> Node3D:
	var r: Node3D = load("res://scenes/runner.tscn").instantiate()
	r.get_node("Civilization").id = civ_id
	root.add_child(r)
	return r


func _skel(r: Node3D) -> Skeleton3D:
	var list := r.get_node("Model").find_children("*", "Skeleton3D", true, false)
	return list[0] if not list.is_empty() else null


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_services = root.get_node("Services")
	var registry = load("res://scripts/world/planet_theme_registry.gd").new()   # fora da árvore: só a lista de fichas (sem mexer no perfil)
	for id in range(1, 7):
		registry.civilization_themes.append(load("res://art/themes/theme_civ%d.tres" % id))
	_services.themes = registry

	# 1. Floresta: o elfo
	var elf := _runner(3)
	await process_frame
	var skel := _skel(elf)
	if skel == null or skel.get_bone_count() != 12 or skel.find_bone("ForeArmA") < 0:
		_fail("a Floresta corre com o esqueleto do Guardião (12 ossos)")
		return
	if skel.find_bone("L_ToeBase") >= 0:
		_fail("o Pistoleiro sobrou dentro do modelo da Floresta")
		return
	var player: AnimationPlayer = elf.get_node("Model").find_children("*", "AnimationPlayer", true, false)[0]
	if player.get_animation_list() != PackedStringArray(["Correr"]) or not player.is_playing() or player.get_animation("Correr").loop_mode != Animation.LOOP_LINEAR:
		_fail("o Guardião corre em laço (Correr tocando; lista %s)" % [player.get_animation_list()])
		return
	var box: AABB = load("res://scripts/core/model_utils.gd").local_aabb(elf)
	var offset: float = elf.height_offset
	print("elfo: altura=%.2f base=%.2f centro=(%.2f, %.2f)" % [box.size.y, box.position.y, box.get_center().x, box.get_center().z])
	if absf(box.size.y - elf.model_height) > 0.02 or absf(box.position.y + offset) > 0.02 or absf(box.get_center().x) > 0.15 or absf(box.get_center().z) > 0.15:
		_fail("o elfo tem a altura do corredor, os pés no chão e fica centrado")
		return
	var painted := false
	for mi in elf.get_node("Model").find_children("*", "MeshInstance3D", true, false):
		var mat := (mi as MeshInstance3D).get_active_material(0) as BaseMaterial3D
		painted = painted or (mat != null and mat.albedo_texture != null)
	if not painted:
		_fail("o Guardião tem textura pintada")
		return
	elf.free()

	# 2. Velho Oeste e Alien: o Pistoleiro
	for id in [1, 2]:
		var cow := _runner(id)
		await process_frame
		var cs := _skel(cow)
		if cs == null or cs.find_bone("L_ToeBase") < 0:
			_fail("a civilização %d continua com o Pistoleiro" % id)
			return
		cow.free()

	# 3. Sem fichas de tema: nada quebra
	_services.themes = null
	var plain := _runner(3)
	await process_frame
	var ps := _skel(plain)
	if ps == null or ps.find_bone("L_ToeBase") < 0:
		_fail("sem fichas de tema o corredor fica com o Pistoleiro")
		return
	plain.free()

	# 4. Fichas trocadas (jogador escolheu a Floresta: ela vira a civ 1 e o Velho Oeste a civ 3)
	registry.apply_choice(3)
	_services.themes = registry
	var mine := _runner(1)
	var bot := _runner(3)
	await process_frame
	if _skel(mine) == null or _skel(mine).get_bone_count() != 12 or _skel(bot) == null or _skel(bot).find_bone("L_ToeBase") < 0:
		_fail("com a Floresta escolhida (civ 1) o jogador é o elfo e o Velho Oeste (civ 3) o Pistoleiro")
		return
	mine.free()
	bot.free()

	_services.themes = null
	registry.free()
	print("OK smoke_runner_skin")
	quit(0)
