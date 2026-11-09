class_name MatchCheckpoint
extends RefCounted
## Foto da partida em disco (cap. 04 parte 05, queda do servidor). Arquivo = SHA-256 (32 bytes) + estado.
## Checksum que não confere = arquivo corrompido ou cortado no meio: nunca é usado. (Protege de corrupção, não de
## quem tem acesso ao disco: o checksum é recalculável.)

const SUM_BYTES := 32


## Grava sem estragar o checkpoint anterior: escreve num arquivo temporário e só então troca.
static func write(state: Dictionary, path: String) -> Error:
	var body := var_to_bytes(state)
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(_sum(body))
	file.store_buffer(body)
	file.close()
	return DirAccess.rename_absolute(path + ".tmp", path)


## O estado salvo, ou {} se o arquivo não existe, está truncado ou o checksum não confere.
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() <= SUM_BYTES or _sum(bytes.slice(SUM_BYTES)) != bytes.slice(0, SUM_BYTES):
		return {}
	var state: Variant = bytes_to_var(bytes.slice(SUM_BYTES))   # sem objetos: só dados
	return state if typeof(state) == TYPE_DICTIONARY else {}


static func _sum(body: PackedByteArray) -> PackedByteArray:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(body)
	return ctx.finish()
