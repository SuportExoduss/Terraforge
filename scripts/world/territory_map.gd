class_name TerritoryMap
extends Node
## A verdade sobre a posse do planeta: uma grade de células distribuídas uniformemente na esfera
## (espiral de Fibonacci), cada uma com o id da civilização dona. Conquistar = marcar células;
## cercar território inimigo o converte; fragmentos sem conexão com a base do dono são amputados
## (DD-102); dominar a base herda o império (DD-100). Porte fiel do TerritoryMap.cs do Unity.
## Tudo em arrays "empacotados" e filas pré-alocadas: nenhuma alocação por flood-fill.

const NO_OWNER := 0
const MAX_OWNERS := 16

@export var cell_count: int = 20000
@export var boundary_thickness: float = 2.4   # espessura da cerca do rastro durante a inundação

var cell_spacing: float = 0.0
var build_msec: float = 0.0

var _built := false
var _radius := 100.0
var _dirs := PackedVector3Array()
var _owners := PackedByteArray()
var _counts := PackedInt32Array()          # células por dono
var _dispossessed := PackedByteArray()     # donos que perderam célula na conquista em curso
var _claim_buffer := PackedVector3Array()  # posições das células conquistadas na operação em curso
var _taken := 0                            # destas, quantas eram de outro dono (conversão)

# Vizinhança fixa da grade em formato CSR: vizinhos da célula c = _nb_data[_nb_start[c] .. _nb_start[c+1]).
var _nb_start := PackedInt32Array()
var _nb_data := PackedInt32Array()

# Baldes espaciais (grade cúbica sobre o cubo [-1,1]^3), também em CSR.
var _grid := 1
var _bucket_width := 1.0
var _bucket_start := PackedInt32Array()
var _bucket_data := PackedInt32Array()

# Fila e marcação reaproveitadas por todos os flood-fills (cada célula entra na fila no máximo uma vez).
var _queue := PackedInt32Array()
var _mark := PackedByteArray()

var _center_cache := Vector3.ZERO   # o planeta não se move; a thread de trabalho não toca na árvore de cenas

# Circuitos fechados são resolvidos numa thread de trabalho (~45 ms em GDScript = 3 frames de pausa).
# Um por vez, em ordem. A thread só ESCREVE a grade e empilha anúncios em _outbox; os sinais saem
# no _process da thread principal. Leituras (is_owned_by) seguem livres: bytes, sem redimensionar.
var _jobs: Array = []
var _task_id := -1
var _outbox: Array = []


func _ready() -> void:
	Services.territory = self
	EventBus.territory_loop_closed.connect(_on_loop_closed)
	if Services.planet != null:
		_ensure_built()   # paga o custo da grade antes do GO, não no primeiro circuito


func _exit_tree() -> void:
	_wait_idle()
	if Services.territory == self:
		Services.territory = null


func _process(_delta: float) -> void:
	if _task_id != -1 and WorkerThreadPool.is_task_completed(_task_id):
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1
		_flush_outbox()
		_pump()


## Quando a thread de trabalho está ocupada ou há circuitos na fila, termina tudo (na ordem) antes de
## uma operação síncrona. Raras e baratas (calota, herança de base), então bloquear é aceitável.
func _wait_idle() -> void:
	if _task_id != -1:
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1
	while not _jobs.is_empty():
		var job: Dictionary = _jobs.pop_front()
		_loop_work(job["owner"], job["points"], job["bases"])
	_flush_outbox()


func _pump() -> void:
	if _task_id == -1 and not _jobs.is_empty():
		var job: Dictionary = _jobs.pop_front()
		_task_id = WorkerThreadPool.add_task(_loop_work.bind(job["owner"], job["points"], job["bases"]), false, "territory")


# ---------------------------------------------------------------------------------------------
# Consultas
# ---------------------------------------------------------------------------------------------

## Cópia do dono de cada célula (o cliente que reconecta recebe o mapa inteiro).
func owners_snapshot() -> PackedByteArray:
	return _owners.duplicate()


## Recuperação do servidor (cap. 04 parte 05): cada célula com dono volta ao dono salvo, pelo mesmo caminho das
## conquistas (placares e pintura se atualizam). ponytail: só reatribui células COM dono; um servidor recém-reiniciado
## não tem o que limpar. Quem chama valida o conteúdo (tamanho e donos < MAX_OWNERS).
func restore_owners(saved: PackedByteArray) -> bool:
	if not _ensure_built() or saved.size() != cell_count:
		return false
	_wait_idle()
	for owner_id in range(1, MAX_OWNERS):
		_begin_claim()
		for cell in cell_count:
			if saved[cell] == owner_id:
				_claim_cell(owner_id, cell)
		_publish_claims(owner_id)
	_flush_outbox()
	return true


func is_owned_by(civilization_id: int, world_position: Vector3) -> bool:
	if not _ensure_built():
		return false
	var cell := _nearest_cell(_direction_of(world_position), cell_spacing * 2.0)
	return cell >= 0 and _owners[cell] == civilization_id


## Quem é o dono do chão neste ponto (0 = ninguém).
func get_owner_at(world_position: Vector3) -> int:
	if not _ensure_built():
		return NO_OWNER
	var cell := _nearest_cell(_direction_of(world_position), cell_spacing * 2.0)
	return _owners[cell] if cell >= 0 else NO_OWNER


func owned_fraction(civilization_id: int) -> float:
	return float(_counts[civilization_id]) / cell_count if _built else 0.0


func get_random_unowned_position() -> Vector3:
	if not _ensure_built():
		return Vector3.ZERO
	# Sorteia até achar célula livre; num planeta quase todo dominado devolve qualquer uma.
	for attempt in 128:
		var cell := randi_range(0, cell_count - 1)
		if _owners[cell] == NO_OWNER:
			return _cell_position(cell)
	return _cell_position(randi_range(0, cell_count - 1))


# ---------------------------------------------------------------------------------------------
# Conquistas
# ---------------------------------------------------------------------------------------------

## Entrega uma calota à civilização (a base inicial de cada uma). Ângulo em radianos.
func claim_cap(owner_id: int, cap_direction: Vector3, cap_angle: float) -> void:
	if not _ensure_built():
		return
	_wait_idle()
	_begin_claim()
	var near := PackedInt32Array()
	_collect_within(cap_direction, cap_angle * _radius, near)
	for cell in near:
		_claim_cell(owner_id, cell)
	_publish_claims(owner_id)
	_flush_outbox()


## DD-100: dominar a base = herdar o império. Converte TODAS as células da vítima.
func convert_all_cells_of(victim_id: int, conqueror_id: int) -> void:
	if not _ensure_built() or victim_id == conqueror_id or conqueror_id == NO_OWNER:
		return
	_wait_idle()
	_begin_claim()
	for cell in cell_count:
		if _owners[cell] == victim_id:
			_claim_cell(conqueror_id, cell)
	_publish_claims(conqueror_id)
	# A herança pode ter emendado territórios ao redor de vãos livres.
	_seal_enclosed_free_pockets()
	_flush_outbox()


func _on_loop_closed(owner_id: int, trail_points: PackedVector3Array) -> void:
	if trail_points.size() < 3 or not _ensure_built():
		return
	# Fotografia das bases: a thread de trabalho não pode ler o dicionário vivo dos Services.
	_jobs.append({"owner": owner_id, "points": trail_points, "bases": Services.home_bases.duplicate(true)})
	_pump()


## Versão síncrona (testes, ferramentas): resolve o circuito agora e anuncia na hora.
func claim_loop_interior(owner_id: int, trail_points: PackedVector3Array) -> void:
	if not _ensure_built():
		return
	_wait_idle()
	_loop_work(owner_id, trail_points, Services.home_bases)
	_flush_outbox()


## Conquista pelo método do "lado de fora": marca a cerca do rastro, inunda o exterior do
## domínio e converte TUDO que ficou cercado (livre ou inimigo). Pode rodar fora da thread principal.
func _loop_work(owner_id: int, trail_points: PackedVector3Array, bases: Dictionary) -> void:
	_begin_claim()
	var center := _center()
	var sample_step := cell_spacing * 0.5
	# A cerca precisa ser mais grossa que o vão entre células, senão a inundação vaza.
	var fence_thickness := maxf(boundary_thickness, cell_spacing * 1.3)

	# 1. A cerca: células próximas de cada trecho do rastro viram do conquistador
	#    (amostrado ponto a ponto para não deixar frestas). O circuito fecha último -> primeiro.
	var near := PackedInt32Array()
	var centroid_sum := Vector3.ZERO
	var point_count := trail_points.size()
	for i in point_count:
		var from := trail_points[i]
		var to := trail_points[(i + 1) % point_count]
		var samples := maxi(1, ceili(from.distance_to(to) / sample_step))
		for s in samples + 1:
			near.clear()
			_collect_within((from.lerp(to, float(s) / samples) - center).normalized(), fence_thickness, near)
			for cell in near:
				_claim_cell(owner_id, cell)
		centroid_sum += (from - center).normalized()

	# 2. Semente do lado de fora: a célula mais distante do circuito que NÃO é do conquistador.
	# ponytail: varre as 20k células; trocar por busca a partir do antípoda se aparecer no profiler.
	var centroid := centroid_sum.normalized()
	var ocean_seed := -1
	var lowest_dot := 2.0
	for cell in cell_count:
		if _owners[cell] == owner_id:
			continue
		var d := _dirs[cell].dot(centroid)
		if d < lowest_dot:
			lowest_dot = d
			ocean_seed = cell

	# 3. Inunda o exterior: tudo que não é do conquistador e alcançável da semente respira o "oceano".
	if ocean_seed >= 0:
		_flood(ocean_seed, owner_id, true)
	else:
		_mark.fill(0)

	# 4. O veredito: quem não é do conquistador e não respira o oceano está cercado.
	for cell in cell_count:
		if _owners[cell] != owner_id and _mark[cell] == 0:
			_claim_cell(owner_id, cell)

	# DD-102: fragmentos inimigos que perderam a conexão com a própria base são amputados.
	_convert_disconnected_enemy_regions(owner_id, bases)

	var claimed := _claim_buffer.size()
	var took_enemy := _dispossessed.count(1) > 0
	_publish_claims(owner_id)
	print("[World] Civilização %d anexou %d células%s" % [
			owner_id, claimed, " (convertendo território inimigo!)." if took_enemy else "."])

	# Nenhum vão preso: bolsões livres cercados são selados.
	_seal_enclosed_free_pockets()


# DD-102: para cada inimigo que acabou de perder terreno, inunda o território dele a partir da
# base; o que o "sangue" da base não alcançar está amputado e vira do conquistador.
func _convert_disconnected_enemy_regions(conqueror_id: int, bases: Dictionary) -> void:
	for enemy in range(1, MAX_OWNERS):
		if _dispossessed[enemy] == 0 or enemy == conqueror_id or _counts[enemy] <= 0:
			continue
		if not bases.has(enemy):
			continue
		var base: Dictionary = bases[enemy]
		var base_cell := _nearest_cell(_direction_of(base["position"]), cell_spacing * 3.0)
		if base_cell < 0 or _owners[base_cell] != enemy:
			continue   # a própria base já não é do dono: cenário do DD-100 (realocação da nave)
		if _flood(base_cell, enemy, false) >= _counts[enemy]:
			continue   # território inteiro conectado — nada a amputar
		for cell in cell_count:
			if _owners[cell] == enemy and _mark[cell] == 0:
				_claim_cell(conqueror_id, cell)
		print("[World] Território amputado da civilização %d (DD-102)." % enemy)


# Nenhum buraco fica para trás: regiões LIVRES desconectadas da maior região livre (o "oceano")
# estão cercadas e são entregues a quem mais as cerca. Uma única varredura rotula todas as
# regiões livres; a fila guarda as regiões umas após as outras, então cada região é uma fatia dela.
func _seal_enclosed_free_pockets() -> void:
	_mark.fill(0)
	var starts := PackedInt32Array()
	var tail := 0
	for seed_cell in cell_count:
		if _owners[seed_cell] != NO_OWNER or _mark[seed_cell] != 0:
			continue
		starts.append(tail)
		var head := tail
		_mark[seed_cell] = 1
		_queue[tail] = seed_cell
		tail += 1
		while head < tail:
			var cell := _queue[head]
			head += 1
			for k in range(_nb_start[cell], _nb_start[cell + 1]):
				var neighbor := _nb_data[k]
				if _mark[neighbor] == 0 and _owners[neighbor] == NO_OWNER:
					_mark[neighbor] = 1
					_queue[tail] = neighbor
					tail += 1
	starts.append(tail)

	var region_count := starts.size() - 1
	if region_count <= 1:
		return   # sem terra livre, ou só o oceano

	var ocean := 0
	for r in range(1, region_count):
		if starts[r + 1] - starts[r] > starts[ocean + 1] - starts[ocean]:
			ocean = r

	var border := PackedInt32Array()
	border.resize(MAX_OWNERS)
	for r in region_count:
		if r == ocean:
			continue
		border.fill(0)
		for q in range(starts[r], starts[r + 1]):
			var cell := _queue[q]
			for k in range(_nb_start[cell], _nb_start[cell + 1]):
				var owner := _owners[_nb_data[k]]
				if owner != NO_OWNER:
					border[owner] += 1
		var best_owner := NO_OWNER
		var best_count := 0
		for owner in range(1, MAX_OWNERS):
			if border[owner] > best_count:
				best_count = border[owner]
				best_owner = owner
		if best_owner == NO_OWNER:
			continue
		_begin_claim()
		for q in range(starts[r], starts[r + 1]):
			_claim_cell(best_owner, _queue[q])
		var sealed := _claim_buffer.size()
		_publish_claims(best_owner)
		print("[World] Bolsão cercado de %d células selado para a civilização %d." % [sealed, best_owner])


# Inunda a partir de start_cell por células cujo dono é (ou, com invert, NÃO é) match_owner.
# Deixa _mark = 1 nas células alcançadas e devolve quantas são.
func _flood(start_cell: int, match_owner: int, invert: bool) -> int:
	_mark.fill(0)
	_mark[start_cell] = 1
	_queue[0] = start_cell
	var head := 0
	var tail := 1
	while head < tail:
		var cell := _queue[head]
		head += 1
		for k in range(_nb_start[cell], _nb_start[cell + 1]):
			var neighbor := _nb_data[k]
			if _mark[neighbor] == 0 and (_owners[neighbor] == match_owner) != invert:
				_mark[neighbor] = 1
				_queue[tail] = neighbor
				tail += 1
	return tail


func _begin_claim() -> void:
	_claim_buffer = PackedVector3Array()
	_taken = 0
	_dispossessed.fill(0)


func _claim_cell(owner_id: int, cell: int) -> void:
	var previous: int = _owners[cell]
	if previous == owner_id:
		return
	if previous != NO_OWNER:
		_counts[previous] -= 1
		_dispossessed[previous] = 1
		_taken += 1
	_owners[cell] = owner_id
	_counts[owner_id] += 1
	_claim_buffer.append(_cell_position(cell))


# Empilha o anúncio (posições + placares de quem ganhou e de quem perdeu) para a thread principal.
func _publish_claims(owner_id: int) -> void:
	if _claim_buffer.is_empty():
		return
	var scores: Array = [[owner_id, float(_counts[owner_id]) / cell_count]]
	for loser in range(1, MAX_OWNERS):
		if _dispossessed[loser] != 0:
			scores.append([loser, float(_counts[loser]) / cell_count])
	_outbox.append([owner_id, _claim_buffer, scores, _taken])


func _flush_outbox() -> void:
	for note in _outbox:
		EventBus.territory_cells_claimed.emit(note[0], note[1], cell_spacing)
		if note[3] > 0:
			EventBus.territory_cells_converted.emit(note[0], float(note[3]) / cell_count)
		for score in note[2]:
			EventBus.territory_score_changed.emit(score[0], score[1])
	_outbox.clear()


# ---------------------------------------------------------------------------------------------
# Geometria da grade
# ---------------------------------------------------------------------------------------------

func _center() -> Vector3:
	return _center_cache


func _direction_of(world_position: Vector3) -> Vector3:
	return (world_position - _center()).normalized()


func _cell_position(cell: int) -> Vector3:
	return _center() + _dirs[cell] * _radius


func _axis(v: float) -> int:
	return clampi(int((v + 1.0) / _bucket_width), 0, _grid - 1)


# Anexa a `out` as células a no máximo `surface_distance` (arco) de `dir`, exceto `exclude`.
func _collect_within(dir: Vector3, surface_distance: float, out: PackedInt32Array, exclude: int = -1) -> void:
	var min_dot := cos(surface_distance / _radius)
	var reach := ceili(surface_distance / _radius / _bucket_width)   # corda <= arco: conservador
	var cx := _axis(dir.x)
	var cy := _axis(dir.y)
	var cz := _axis(dir.z)
	for z in range(maxi(cz - reach, 0), mini(cz + reach, _grid - 1) + 1):
		for y in range(maxi(cy - reach, 0), mini(cy + reach, _grid - 1) + 1):
			var row := _grid * (y + _grid * z)
			for x in range(maxi(cx - reach, 0), mini(cx + reach, _grid - 1) + 1):
				var bucket := row + x
				for k in range(_bucket_start[bucket], _bucket_start[bucket + 1]):
					var cell := _bucket_data[k]
					if cell != exclude and _dirs[cell].dot(dir) >= min_dot:
						out.append(cell)


# A célula mais próxima de `dir` dentro de `max_surface_distance`, ou -1. Caminho quente: roda a
# cada frame por corredor, então não aloca nada.
func _nearest_cell(dir: Vector3, max_surface_distance: float) -> int:
	var min_dot := cos(max_surface_distance / _radius)
	var reach := ceili(max_surface_distance / _radius / _bucket_width)
	var cx := _axis(dir.x)
	var cy := _axis(dir.y)
	var cz := _axis(dir.z)
	var best := -1
	var best_dot := -2.0
	for z in range(maxi(cz - reach, 0), mini(cz + reach, _grid - 1) + 1):
		for y in range(maxi(cy - reach, 0), mini(cy + reach, _grid - 1) + 1):
			var row := _grid * (y + _grid * z)
			for x in range(maxi(cx - reach, 0), mini(cx + reach, _grid - 1) + 1):
				var bucket := row + x
				for k in range(_bucket_start[bucket], _bucket_start[bucket + 1]):
					var cell := _bucket_data[k]
					var d := _dirs[cell].dot(dir)
					if d >= min_dot and d > best_dot:
						best_dot = d
						best = cell
	return best


# ---------------------------------------------------------------------------------------------
# Construção da grade (acontece uma vez, antes do GO)
# ---------------------------------------------------------------------------------------------

func _ensure_built() -> bool:
	if _built:
		return true
	if Services.planet == null:
		return false
	var t0 := Time.get_ticks_usec()
	_radius = Services.planet.radius
	_center_cache = Services.planet.center
	cell_spacing = sqrt(4.0 * PI * _radius * _radius / cell_count)

	_dirs.resize(cell_count)
	_owners.resize(cell_count)
	_mark.resize(cell_count)
	_queue.resize(cell_count)
	_counts.resize(MAX_OWNERS)
	_dispossessed.resize(MAX_OWNERS)

	# Espiral de Fibonacci: N pontos quase perfeitamente uniformes — o "papel quadriculado" do planeta.
	var golden_angle := PI * (3.0 - sqrt(5.0))
	for i in cell_count:
		var y := 1.0 - (i + 0.5) * 2.0 / cell_count
		var ring := sqrt(1.0 - y * y)
		var angle := golden_angle * i
		_dirs[i] = Vector3(cos(angle) * ring, y, sin(angle) * ring)

	_build_buckets()

	# Vizinhança: células a até 1,6 espaçamentos. Nunca muda — calculada uma vez.
	var neighbor_distance := cell_spacing * 1.6
	var near := PackedInt32Array()
	_nb_start.resize(cell_count + 1)
	for cell in cell_count:
		near.clear()
		_collect_within(_dirs[cell], neighbor_distance, near, cell)
		_nb_data.append_array(near)
		_nb_start[cell + 1] = _nb_data.size()

	_built = true
	build_msec = (Time.get_ticks_usec() - t0) / 1000.0
	print("[World] Grade territorial criada: %d células, espaçamento ~%.2f unidades, %.0f ms." % [
			cell_count, cell_spacing, build_msec])
	return true


# Balde com largura >= 2 espaçamentos (maior consulta usual), então 3x3x3 baldes bastam.
func _build_buckets() -> void:
	_grid = maxi(1, int(sqrt(cell_count / (4.0 * PI))))
	_bucket_width = 2.0 / _grid
	var bucket_total := _grid * _grid * _grid
	var keys := PackedInt32Array()
	keys.resize(cell_count)
	_bucket_start.resize(bucket_total + 1)
	for i in cell_count:
		var d := _dirs[i]
		var key := _axis(d.x) + _grid * (_axis(d.y) + _grid * _axis(d.z))
		keys[i] = key
		_bucket_start[key + 1] += 1
	for b in bucket_total:
		_bucket_start[b + 1] += _bucket_start[b]
	var cursor := _bucket_start.duplicate()
	_bucket_data.resize(cell_count)
	for i in cell_count:
		var key := keys[i]
		_bucket_data[cursor[key]] = i
		cursor[key] += 1
