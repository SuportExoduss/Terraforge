extends SceneTree
## Teste de fumaça do Passo 87 (desempenho): toda textura de art/models está em VRAM comprimida e com no máximo 2048 px.
## (4096 px em WebP sem perdas = 85 MB cada na memória: a partida chegava a 7,7 GB e levava 88 s para carregar.)
## Se falhar depois de um modelo novo: python -X utf8 tools/optimize_textures.py  e  godot_console --headless --path . --import
## Uso: godot_console --headless --path . -s res://tools/smoke_textures.gd

const LIMIT := 2048


func _initialize() -> void:
	var bad: Array[String] = []
	var count := 0
	for path in _imports("res://art/models"):
		var text := FileAccess.get_file_as_string(path)
		if not text.contains('importer="texture"'):
			continue
		count += 1
		if not text.contains("compress/mode=2"):
			bad.append(path.get_file() + ": sem VRAM comprimida")
		var limit := text.get_slice("process/size_limit=", 1).get_slice("\n", 0).to_int()
		if limit < 1 or limit > LIMIT:
			bad.append(path.get_file() + ": limite de tamanho %d" % limit)
	if count < 60:
		bad.append("achou só %d texturas (esperava 60+)" % count)
	for b in bad.slice(0, 8):
		print("FALHOU: ", b)
	print("OK" if bad.is_empty() else "FALHOU", " (%d texturas)" % count)
	quit(0 if bad.is_empty() else 1)


func _imports(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".import"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_imports(dir.path_join(d)))
	return out
