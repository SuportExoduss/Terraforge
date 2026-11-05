extends SceneTree
## Confere se a CERCA fecha (DD-125, poste + elo): no corredor de verdade, as duas pontas de cada elo
## caem dentro dos postes que ele liga? Mede em retas e em curvas, e tira fotos (exige janela).
## Uso: godot_console --path . -s res://tools/check_fence.gd -- <pasta de saída> [altura do elo]
## Sai com código 1 se faltar poste/elo ou se alguma ponta ficar a mais de TOLERANCE do poste.

const ROUTE := [[1.5, false], [0.5, true], [1.5, false], [0.5, true], [1.5, false], [0.5, true], [4.0, false]]
const SNAPSHOT_AT := 4.3       # depois das duas primeiras curvas, antes de voltar ao território
const TOLERANCE := 0.05        # folga aceitável entre a ponta do elo e o poste (unidades)

var _main: Node
var _runner: Node3D
var _trail: Node
var _map: Node
var _time := 0.0
var _started := false
var _out := ""
var _height := 0.0   # 2º argumento opcional: altura do elo para testar (0 = a do projeto)
var _shots: Array = []
var _shot_frame := 0
var _failed := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://"
	_height = float(args[1]) if args.size() > 1 else 0.0
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _process(delta: float) -> bool:
	if _map == null:
		_map = _main.get_node("Territory")
		_runner = _main.get_node("Runner")
		_trail = _runner.get_node("Trail")
		if _height > 0.0:
			_trail.link_height = _height
	if _shots.is_empty():
		if not _started:
			if _map._counts[1] == 0:
				return false
			_started = true
			return false
		_time += delta
		_steer(_time)
		if _time >= SNAPSHOT_AT:
			Input.action_release("ui_right")
			_runner.set_process(false)
			_runner.set_physics_process(false)
			_main.get_node("Camera").set_process(false)
			_shots = _analyze()
		return false
	# fotos: posiciona a câmera num quadro e fotografa 3 quadros depois
	_shot_frame += 1
	var i := _shot_frame / 6
	if _shot_frame % 6 == 0 and i > 0 and i <= _shots.size():
		var img := root.get_texture().get_image()
		img.save_png("%s/%s.png" % [_out, _shots[i - 1][0]])
	if _shot_frame % 6 == 3 and i < _shots.size():
		var s: Array = _shots[i]
		var cam: Camera3D = _main.get_node("Camera")
		cam.global_position = s[1]
		cam.look_at(s[2], s[3])
	if i > _shots.size():
		quit(1 if _failed else 0)
	return false


func _steer(t: float) -> void:
	var at := 0.0
	for leg in ROUTE:
		at += leg[0]
		if t < at:
			if leg[1]:
				Input.action_press("ui_right")
			else:
				Input.action_release("ui_right")
			return
	Input.action_release("ui_right")


## Mede as folgas e devolve a lista de fotos [nome, posição da câmera, alvo, "up"].
func _analyze() -> Array:
	var posts: Array = _trail._posts.slice(0, _trail._active_posts)
	var links: Array = _trail._links.slice(0, _trail._active_links)
	var points: Array = _trail.points
	print("pontos=%d  postes=%d  elos=%d  point_spacing=%.2f  post_scale=%.2f  link_height=%.2f" % [
			points.size(), posts.size(), links.size(), _trail.point_spacing, _trail.post_scale, _trail.link_height])
	if posts.size() != points.size() or links.size() != posts.size() - 1 or links.size() < 4:
		print("FALHOU: esperado 1 poste por ponto e 1 elo por par (>= 4 elos); veio %d postes, %d elos, %d pontos" % [posts.size(), links.size(), points.size()])
		_failed = true
		return []

	var stake := _mesh_of(posts[0]).mesh.get_aabb()
	var rope := ModelUtils.local_aabb(links[0])
	print("poste: %.3f x %.3f x %.3f  | elo: comprimento do modelo=%.3f  | elo preso a %.0f%% da altura do poste" % [
			stake.size.x, stake.size.y, stake.size.z, rope.size.z, 100.0 * _trail.link_height / stake.size.y])

	var straight: Array[float] = []
	var corners: Array[float] = []
	var worst_corner := 1
	var worst_turn := 0.0
	for i in links.size():
		var link: Node3D = links[i]
		# as pontas do elo no mundo: o modelo é medido de verdade (não se assume o comprimento 1)
		var tail: Vector3 = link.global_transform * Vector3(0.0, 0.0, rope.position.z)
		var head: Vector3 = link.global_transform * Vector3(0.0, 0.0, rope.end.z)
		var gap := minf(maxf(_gap(posts[i], tail), _gap(posts[i + 1], head)),
				maxf(_gap(posts[i], head), _gap(posts[i + 1], tail)))   # tolera o elo "de costas"
		var turn := 0.0
		if i > 0:
			turn = rad_to_deg(_dir_of(links[i - 1]).angle_to(_dir_of(link)))
		if turn < 10.0:
			straight.append(gap)
		else:
			corners.append(gap)
			if turn > worst_turn:
				worst_turn = turn
				worst_corner = i
	var worst := maxf(_max(straight), _max(corners))
	print("RETAS  (%d elos): folga média=%.3f  máx=%.3f" % [straight.size(), _avg(straight), _max(straight)])
	print("CURVAS (%d elos): folga média=%.3f  máx=%.3f   (pior curva: %.0f graus no elo %d)" % [corners.size(), _avg(corners), _max(corners), worst_turn, worst_corner])
	if worst > TOLERANCE:
		print("FALHOU: há ponta de elo a %.3f de um poste (tolerância %.2f)" % [worst, TOLERANCE])
		_failed = true
	else:
		print("OK")

	# fotos: de cima (rota inteira), reta e curva de perto, e rasante (para ver a altura do elo)
	var mid: Node3D = links[links.size() / 2]
	var up_dir := _up(mid)
	return [
		["cerca_topo", mid.global_position + up_dir * 30.0, mid.global_position, _dir_of(mid)],
		["cerca_reta", _near(links[2], 2.2, 0.7), links[2].global_position, _up(links[2])],
		["cerca_curva", _near(links[worst_corner], 3.0, 0.7), links[worst_corner].global_position, _up(links[worst_corner])],
		["cerca_rasante", _near(links[2], 1.8, 0.12), links[2].global_position + _up(links[2]) * 0.2, _up(links[2])],
	]


## Distância da ponta ao poste (0 = dentro da caixa da malha do poste).
func _gap(post: Node3D, p: Vector3) -> float:
	var mi := _mesh_of(post)
	var l := mi.global_transform.affine_inverse() * p
	var b := mi.mesh.get_aabb()
	var d := Vector3(maxf(maxf(b.position.x - l.x, l.x - b.end.x), 0.0),
			maxf(maxf(b.position.y - l.y, l.y - b.end.y), 0.0),
			maxf(maxf(b.position.z - l.z, l.z - b.end.z), 0.0))
	return d.length() * mi.global_transform.basis.get_scale().x


func _mesh_of(node: Node3D) -> MeshInstance3D:
	for c in node.find_children("*", "MeshInstance3D", true, false):
		if c.name != "Sombra":
			return c
	return null


func _up(node: Node3D) -> Vector3:
	return (node.global_position - _main.get_node("Planet").center).normalized()


func _dir_of(link: Node3D) -> Vector3:
	return link.global_transform.basis.z.normalized()


# câmera ao lado do elo: `dist` de afastamento, `lift` (fração de dist) de altura
func _near(link: Node3D, dist: float, lift: float) -> Vector3:
	var up := _up(link)
	return link.global_position + up * dist * lift - _dir_of(link).cross(up).normalized() * dist


func _avg(a: Array[float]) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for x in a:
		s += x
	return s / a.size()


func _max(a: Array[float]) -> float:
	return a.max() if not a.is_empty() else 0.0
