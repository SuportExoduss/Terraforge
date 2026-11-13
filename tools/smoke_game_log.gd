extends SceneTree
## Passo 93: o diário de jogo fica calado por padrão (print() custa 10–30 ms/linha no console do Windows) e nenhum script do jogo
## volta a usar print() solto (só o servidor dedicado e o NetLog, que são auditoria/console do servidor).
## Uso: godot_console --headless --path . -s res://tools/smoke_game_log.gd

const ALLOWED := ["res://scripts/core/game_log.gd", "res://scripts/network/dedicated_server.gd", "res://scripts/network/net_log.gd"]


func _initialize() -> void:
	var ok := true
	ok = _check(not GameLog.enabled, "calado por padrão (sem TERRAFORGE_LOG)") and ok
	var t := Time.get_ticks_usec()
	for i in 1000:
		GameLog.say("[World] teste %d" % i)
	var ms := (Time.get_ticks_usec() - t) / 1000.0
	ok = _check(ms < 30.0, "1000 chamadas desligadas em %.1f ms" % ms) and ok
	var offenders: Array[String] = []
	_scan("res://scripts", offenders)
	ok = _check(offenders.is_empty(), "print() solto em: %s" % str(offenders)) and ok
	print("OK (1000 linhas desligadas: %.1f ms)" % ms if ok else "FALHOU")
	quit(0 if ok else 1)


func _scan(dir: String, out: Array[String]) -> void:
	for name in DirAccess.get_files_at(dir):
		var path := dir + "/" + name
		if name.ends_with(".gd") and not ALLOWED.has(path) and FileAccess.get_file_as_string(path).contains("\tprint("):
			out.append(path)
	for sub in DirAccess.get_directories_at(dir):
		_scan(dir + "/" + sub, out)


func _check(cond: bool, what: String) -> bool:
	if not cond:
		print("  FALHA: ", what)
	return cond
