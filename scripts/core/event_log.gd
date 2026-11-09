class_name EventLog
extends Node
## Registro de eventos para depuração (Cap.05 P07, DD-071: "eventos devem ser registrados para depuração").
## Escuta TODOS os sinais do EventBus — inclusive os que forem criados depois — sem que nenhum módulo precise chamá-lo,
## e guarda os últimos CAPACITY em anel: quem emitiu o quê, em que quadro. Os argumentos ficam de fora de propósito
## (há sinais que carregam listas grandes de células); para investigar um evento específico, o nome e o quadro bastam.
## ponytail: só nome + quadro; guardar argumentos simples vira uma linha a mais quando um bug pedir.

const CAPACITY := 256

var _names := PackedStringArray()
var _frames := PackedInt32Array()
var _next := 0
var _total := 0


func _ready() -> void:
	_names.resize(CAPACITY)
	_frames.resize(CAPACITY)
	var bus: Node = get_node("/root/EventBus")
	for info in bus.get_script().get_script_signal_list():   # só os sinais do próprio EventBus, não os herdados de Node
		var signal_name: String = info["name"]
		# unbind descarta os argumentos do sinal (qualquer quantidade, mas aceita só 1 ou mais); o nome entra por bind.
		var recorder := _record.bind(signal_name)
		var arg_count: int = (info["args"] as Array).size()
		bus.connect(signal_name, recorder.unbind(arg_count) if arg_count > 0 else recorder)


func _record(signal_name: String) -> void:
	_names[_next] = signal_name
	_frames[_next] = Engine.get_process_frames()
	_next = (_next + 1) % CAPACITY
	_total += 1


## Quantos eventos já passaram (inclusive os que o anel já esqueceu).
func total() -> int:
	return _total


## Os últimos `count` eventos, do mais antigo para o mais novo: [{"name", "frame"}].
func last(count: int) -> Array[Dictionary]:
	var shown := mini(count, mini(_total, CAPACITY))
	var result: Array[Dictionary] = []
	for i in shown:
		var slot := posmod(_next - shown + i, CAPACITY)
		result.append({"name": _names[slot], "frame": _frames[slot]})
	return result


## Quantas vezes `signal_name` aparece entre os eventos que o anel ainda guarda.
func count_of(signal_name: String) -> int:
	var found := 0
	for i in mini(_total, CAPACITY):
		if _names[i] == signal_name:
			found += 1
	return found


## Texto para colar num relatório de bug: um evento por linha ("quadro  nome").
func dump(count: int = 40) -> String:
	var lines := PackedStringArray()
	for entry in last(count):
		lines.append("%7d  %s" % [entry["frame"], entry["name"]])
	return "\n".join(lines)
