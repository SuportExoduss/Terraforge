class_name NetLog
extends RefCounted
## Registro auditável da rede (DD-050/052): horário, jogador, partida, tipo, severidade e ação tomada.

var entries: Array[Dictionary] = []
var match_id := "local"


func add(player: int, type: String, severity: String, action: String) -> void:
	var entry := {"time": Time.get_datetime_string_from_system(), "player": player, "match": match_id,
			"type": type, "severity": severity, "action": action}
	entries.append(entry)
	print("[Net] %s jogador=%d partida=%s %s/%s -> %s" % [entry.time, player, match_id, type, severity, action])


func count(type: String) -> int:
	return entries.filter(func(e: Dictionary) -> bool: return e.type == type).size()
