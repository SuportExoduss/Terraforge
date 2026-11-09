class_name NetProtocol
extends RefCounted
## O que o cliente pode PEDIR ao servidor (DD-041/042). Só existe pedido de direção: nada que crie
## território, tire vida ou decida vencedor está na lista branca — isso só o servidor faz.

const COMMANDS := ["steer"]


## Valida um comando vindo da rede (nunca confie nele). Retorna {ok, reason, type, seq, steer}.
## Direção fora de -1..1 é limitada (cliente com joystick folgado); NaN, texto ou tipo desconhecido é recusado.
static func parse(msg: Variant) -> Dictionary:
	var bad := func(reason: String) -> Dictionary: return {"ok": false, "reason": reason}
	if typeof(msg) != TYPE_DICTIONARY:
		return bad.call("mensagem_invalida")
	var type: Variant = msg.get("type")
	if typeof(type) != TYPE_STRING or not COMMANDS.has(type):
		return bad.call("comando_desconhecido")
	var seq: Variant = msg.get("seq")
	if typeof(seq) != TYPE_INT:
		return bad.call("seq_invalido")
	var steer: Variant = msg.get("steer")
	if typeof(steer) != TYPE_FLOAT and typeof(steer) != TYPE_INT:
		return bad.call("direcao_invalida")
	if is_nan(float(steer)) or is_inf(float(steer)):
		return bad.call("direcao_invalida")
	return {"ok": true, "type": type, "seq": seq, "steer": clampf(float(steer), -1.0, 1.0)}
